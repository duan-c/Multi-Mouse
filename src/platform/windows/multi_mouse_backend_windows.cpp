#ifdef _WIN32

#include "multi_mouse_backend_windows.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include <chrono>
#include <cstdint>
#include <cwchar>
#include <vector>

#include <hidusage.h>

namespace godot {

namespace {
constexpr wchar_t kWindowClassName[] = L"MultiMouseRawInputWindow";
constexpr int32_t BUTTON_LEFT = 1;
constexpr int32_t BUTTON_RIGHT = 2;
constexpr int32_t BUTTON_MIDDLE = 3;
constexpr int32_t BUTTON_WHEEL_UP = 4;
constexpr int32_t BUTTON_WHEEL_DOWN = 5;
constexpr int32_t BUTTON_WHEEL_LEFT = 6;
constexpr int32_t BUTTON_WHEEL_RIGHT = 7;
constexpr int32_t BUTTON_X1 = 8;
constexpr int32_t BUTTON_X2 = 9;
}

MultiMouseBackendWindows::MultiMouseBackendWindows(MultiMouseServer *server) : MultiMouseBackend(server) {}

MultiMouseBackendWindows::~MultiMouseBackendWindows() {
    stop();
}

void MultiMouseBackendWindows::start() {
    if (_running.load()) {
        return;
    }
    _running.store(true);
    _thread = std::thread([this]() { thread_main(); });
}

void MultiMouseBackendWindows::stop() {
    if (!_running.load()) {
        return;
    }
    _running.store(false);
    if (_hwnd) {
        PostMessageW(_hwnd, WM_CLOSE, 0, 0);
    }
    if (_thread.joinable()) {
        _thread.join();
    }
    cleanup_window();
}

void MultiMouseBackendWindows::poll() {
    std::vector<PendingEvent> events;
    {
        std::lock_guard<std::mutex> lock(_queue_mutex);
        events.swap(_queue);
    }

    for (auto &event : events) {
        switch (event.type) {
            case PendingEvent::Type::DeviceConnected: {
                if (!server) {
                    break;
                }
                int32_t id = server->register_device(event.info);
                _guid_to_id[event.guid] = id;
                break;
            }
            case PendingEvent::Type::DeviceDisconnected: {
                auto it = _guid_to_id.find(event.guid);
                if (it != _guid_to_id.end() && server) {
                    server->unregister_device(it->second);
                    _guid_to_id.erase(it);
                }
                _guid_to_button_mask.erase(event.guid);
                break;
            }
            case PendingEvent::Type::Motion: {
                auto it = _guid_to_id.find(event.guid);
                if (it == _guid_to_id.end() || !server) {
                    break;
                }
                auto motion = server->make_motion_event(it->second,
                                                        event.relative,
                                                        event.timestamp_us,
                                                        String(event.guid.c_str()));
                server->emit_motion(motion);
                break;
            }
            case PendingEvent::Type::Button: {
                auto it = _guid_to_id.find(event.guid);
                if (it == _guid_to_id.end() || !server) {
                    break;
                }
                auto button = server->make_button_event(it->second,
                                                        event.button_index,
                                                        event.pressed,
                                                        event.button_mask,
                                                        event.timestamp_us,
                                                        String(event.guid.c_str()));
                server->emit_button(button);
                break;
            }
        }
    }
}

void MultiMouseBackendWindows::thread_main() {
    if (!register_raw_input_window()) {
        UtilityFunctions::printerr("Multi-Mouse: failed to create Raw Input window");
        return;
    }

    MSG msg;
    while (_running.load()) {
        BOOL res = GetMessageW(&msg, nullptr, 0, 0);
        if (res <= 0) {
            DWORD err = GetLastError();
            UtilityFunctions::printerr("Multi-Mouse: GetMessage returned", int(res), "error", int(err));
            break;
        }
        UtilityFunctions::print("Multi-Mouse: message", int(msg.message));
        if (msg.message == WM_INPUT) {
            UtilityFunctions::print("WM_INPUT received");
        }
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
}

bool MultiMouseBackendWindows::register_raw_input_window() {
    HINSTANCE instance = GetModuleHandleW(nullptr);

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(WNDCLASSEXW);
    wc.lpfnWndProc = MultiMouseBackendWindows::WindowProc;
    wc.hInstance = instance;
    wc.lpszClassName = kWindowClassName;
    if (!RegisterClassExW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
        return false;
    }

    if (_target_hwnd) {
        return register_on_hwnd(_target_hwnd);
    }

    _hwnd = CreateWindowExW(WS_EX_NOACTIVATE,
                            kWindowClassName,
                            L"Multi-Mouse Raw Input",
                            WS_OVERLAPPED,
                            0,
                            0,
                            0,
                            0,
                            nullptr,
                            nullptr,
                            instance,
                            this);
    if (!_hwnd) {
        return false;
    }

    if (!register_raw_input_devices()) {
        return false;
    }

    ShowWindow(_hwnd, SW_HIDE);
    UtilityFunctions::print("Multi-Mouse: Raw Input window registered");
    return true;
}

LRESULT CALLBACK MultiMouseBackendWindows::WindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    auto *backend = reinterpret_cast<MultiMouseBackendWindows *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));

    switch (msg) {
        case WM_CREATE: {
            auto *create = reinterpret_cast<CREATESTRUCTW *>(lparam);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(create->lpCreateParams));
            return 0;
        }
        case WM_INPUT: {
            if (backend) {
                backend->handle_raw_input(reinterpret_cast<HRAWINPUT>(lparam));
            }
            return 0;
        }
        case WM_INPUT_DEVICE_CHANGE: {
            if (backend) {
                backend->handle_device_change(reinterpret_cast<HANDLE>(lparam), wparam == GIDC_ARRIVAL);
            }
            return 0;
        }
        case WM_DESTROY: {
            PostQuitMessage(0);
            return 0;
        }
        case WM_SETFOCUS: {
            UtilityFunctions::print("Multi-Mouse: window gained focus");
            if (backend) {
                backend->register_raw_input_devices();
            }
            return 0;
        }
        case WM_KILLFOCUS: {
            UtilityFunctions::print("Multi-Mouse: window lost focus");
            return 0;
        }
        default:
            break;
    }

    return DefWindowProcW(hwnd, msg, wparam, lparam);
}

void MultiMouseBackendWindows::handle_device_change(HANDLE device, bool arrival) {
    if (!device) {
        return;
    }

    if (arrival) {
        ensure_device_guid(device);
        return;
    }

    auto it = _handle_to_guid.find(device);
    if (it == _handle_to_guid.end()) {
        return;
    }

    PendingEvent event;
    event.type = PendingEvent::Type::DeviceDisconnected;
    event.guid = it->second;
    enqueue_event(event);
    _handle_to_guid.erase(it);
}

void MultiMouseBackendWindows::handle_raw_input(HRAWINPUT raw_handle) {
    UINT size = 0;
    if (GetRawInputData(raw_handle, RID_INPUT, nullptr, &size, sizeof(RAWINPUTHEADER)) != 0) {
        return;
    }

    std::vector<uint8_t> buffer(size);
    if (GetRawInputData(raw_handle, RID_INPUT, buffer.data(), &size, sizeof(RAWINPUTHEADER)) != size) {
        return;
    }

    RAWINPUT *raw = reinterpret_cast<RAWINPUT *>(buffer.data());
    if (raw->header.dwType != RIM_TYPEMOUSE) {
        return;
    }

    HANDLE device = raw->header.hDevice;
    std::string guid = ensure_device_guid(device);
    if (guid.empty()) {
        return;
    }

    const RAWMOUSE &mouse = raw->data.mouse;
    uint64_t timestamp = now_microseconds();

    if (!(mouse.usFlags & MOUSE_MOVE_ABSOLUTE)) {
        if (mouse.lLastX != 0 || mouse.lLastY != 0) {
            UtilityFunctions::print("Raw input motion", mouse.lLastX, mouse.lLastY);
            Vector2 rel((real_t)mouse.lLastX, (real_t)mouse.lLastY);
            enqueue_motion(guid, rel, timestamp);
        }
    }

    uint16_t button_flags = mouse.usButtonFlags;
    if (button_flags != 0) {
        if (button_flags & RI_MOUSE_LEFT_BUTTON_DOWN) {
            enqueue_button(guid, BUTTON_LEFT, true, update_button_mask(guid, BUTTON_LEFT, true), timestamp);
        }
        if (button_flags & RI_MOUSE_LEFT_BUTTON_UP) {
            enqueue_button(guid, BUTTON_LEFT, false, update_button_mask(guid, BUTTON_LEFT, false), timestamp);
        }
        if (button_flags & RI_MOUSE_RIGHT_BUTTON_DOWN) {
            enqueue_button(guid, BUTTON_RIGHT, true, update_button_mask(guid, BUTTON_RIGHT, true), timestamp);
        }
        if (button_flags & RI_MOUSE_RIGHT_BUTTON_UP) {
            enqueue_button(guid, BUTTON_RIGHT, false, update_button_mask(guid, BUTTON_RIGHT, false), timestamp);
        }
        if (button_flags & RI_MOUSE_MIDDLE_BUTTON_DOWN) {
            enqueue_button(guid, BUTTON_MIDDLE, true, update_button_mask(guid, BUTTON_MIDDLE, true), timestamp);
        }
        if (button_flags & RI_MOUSE_MIDDLE_BUTTON_UP) {
            enqueue_button(guid, BUTTON_MIDDLE, false, update_button_mask(guid, BUTTON_MIDDLE, false), timestamp);
        }
        if (button_flags & (RI_MOUSE_BUTTON_4_DOWN | RI_MOUSE_BUTTON_4_UP)) {
            bool pressed = (button_flags & RI_MOUSE_BUTTON_4_DOWN) != 0;
            enqueue_button(guid, BUTTON_X1, pressed, update_button_mask(guid, BUTTON_X1, pressed), timestamp);
        }
        if (button_flags & (RI_MOUSE_BUTTON_5_DOWN | RI_MOUSE_BUTTON_5_UP)) {
            bool pressed = (button_flags & RI_MOUSE_BUTTON_5_DOWN) != 0;
            enqueue_button(guid, BUTTON_X2, pressed, update_button_mask(guid, BUTTON_X2, pressed), timestamp);
        }
        if (button_flags & RI_MOUSE_WHEEL) {
            SHORT wheel = (SHORT)mouse.usButtonData;
            int32_t button = wheel > 0 ? BUTTON_WHEEL_UP : BUTTON_WHEEL_DOWN;
            enqueue_button(guid, button, true, update_button_mask(guid, button, true), timestamp);
            enqueue_button(guid, button, false, update_button_mask(guid, button, false), timestamp);
        }
        if (button_flags & RI_MOUSE_HWHEEL) {
            SHORT wheel = (SHORT)mouse.usButtonData;
            int32_t button = wheel > 0 ? BUTTON_WHEEL_RIGHT : BUTTON_WHEEL_LEFT;
            enqueue_button(guid, button, true, update_button_mask(guid, button, true), timestamp);
            enqueue_button(guid, button, false, update_button_mask(guid, button, false), timestamp);
        }
    }
}

std::string MultiMouseBackendWindows::ensure_device_guid(HANDLE device) {
    if (!device) {
        return std::string();
    }

    auto it = _handle_to_guid.find(device);
    if (it != _handle_to_guid.end()) {
        return it->second;
    }

    MultiMouseDeviceInfo info;
    std::string guid;
    if (!query_device_info(device, info, guid)) {
        return std::string();
    }

    _handle_to_guid[device] = guid;

    PendingEvent event;
    event.type = PendingEvent::Type::DeviceConnected;
    event.guid = guid;
    event.info = info;
    enqueue_event(event);
    return guid;
}

bool MultiMouseBackendWindows::query_device_info(HANDLE device, MultiMouseDeviceInfo &out_info, std::string &out_guid) const {
    UINT name_len = 0;
    if (GetRawInputDeviceInfoW(device, RIDI_DEVICENAME, nullptr, &name_len) != 0) {
        return false;
    }
    if (name_len == 0) {
        return false;
    }

    std::wstring name(name_len, L'\0');
    if (GetRawInputDeviceInfoW(device, RIDI_DEVICENAME, name.data(), &name_len) == (UINT)-1) {
        return false;
    }
    if (!name.empty() && name.back() == L'\0') {
        name.pop_back();
    }

    int utf8_len = WideCharToMultiByte(CP_UTF8, 0, name.c_str(), -1, nullptr, 0, nullptr, nullptr);
    if (utf8_len <= 0) {
        return false;
    }
    std::string guid_utf8(utf8_len - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, name.c_str(), -1, guid_utf8.data(), utf8_len, nullptr, nullptr);

    RID_DEVICE_INFO device_info{};
    device_info.cbSize = sizeof(device_info);
    UINT info_size = sizeof(device_info);
    if (GetRawInputDeviceInfoW(device, RIDI_DEVICEINFO, &device_info, &info_size) == (UINT)-1) {
        return false;
    }

    out_guid = guid_utf8;
    out_info.name = String("Raw Mouse ") + String::num_int64(device_info.mouse.dwId);
    out_info.system_id = String(guid_utf8.c_str());
    out_info.transport = String("rawinput");
    return true;
}

void MultiMouseBackendWindows::enqueue_event(const PendingEvent &event) {
    std::lock_guard<std::mutex> lock(_queue_mutex);
    _queue.push_back(event);
}

void MultiMouseBackendWindows::enqueue_motion(const std::string &guid, const Vector2 &relative, uint64_t timestamp_us) {
    PendingEvent event;
    event.type = PendingEvent::Type::Motion;
    event.guid = guid;
    event.relative = relative;
    event.timestamp_us = timestamp_us;
    enqueue_event(event);
}

void MultiMouseBackendWindows::enqueue_button(const std::string &guid,
                                              int32_t button_index,
                                              bool pressed,
                                              uint32_t button_mask,
                                              uint64_t timestamp_us) {
    PendingEvent event;
    event.type = PendingEvent::Type::Button;
    event.guid = guid;
    event.button_index = button_index;
    event.pressed = pressed;
    event.button_mask = button_mask;
    event.timestamp_us = timestamp_us;
    enqueue_event(event);
}

uint64_t MultiMouseBackendWindows::now_microseconds() const {
    using namespace std::chrono;
    return duration_cast<microseconds>(steady_clock::now().time_since_epoch()).count();
}

uint32_t MultiMouseBackendWindows::update_button_mask(const std::string &guid, int32_t button_index, bool pressed) {
    uint32_t mask_bit = 0;
    if (button_index >= 1 && button_index <= 32) {
        mask_bit = 1u << (button_index - 1);
    }

    uint32_t current = _guid_to_button_mask[guid];
    if (pressed) {
        current |= mask_bit;
    } else {
        current &= ~mask_bit;
    }
    _guid_to_button_mask[guid] = current;
    return current;
}

void MultiMouseBackendWindows::cleanup_window() {
    if (_hwnd) {
        DestroyWindow(_hwnd);
        _hwnd = nullptr;
    }
    UnregisterClassW(kWindowClassName, GetModuleHandleW(nullptr));
}

} // namespace godot

#endif // _WIN32
