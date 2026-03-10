#ifdef __linux__

#include "platform/linux/multi_mouse_backend_linux.h"

#include "multi_mouse_server.h"
#include "manymouse.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include <chrono>
#include <thread>

namespace godot {

namespace {
constexpr int32_t BUTTON_LEFT = 1;
constexpr int32_t BUTTON_RIGHT = 2;
constexpr int32_t BUTTON_MIDDLE = 3;
constexpr int32_t BUTTON_WHEEL_UP = 4;
constexpr int32_t BUTTON_WHEEL_DOWN = 5;
constexpr int32_t BUTTON_WHEEL_LEFT = 6;
constexpr int32_t BUTTON_WHEEL_RIGHT = 7;
}

MultiMouseBackendLinux::MultiMouseBackendLinux(MultiMouseServer *server) : MultiMouseBackend(server) {}

MultiMouseBackendLinux::~MultiMouseBackendLinux() {
    stop();
}

void MultiMouseBackendLinux::start() {
    if (_running.load()) {
        return;
    }

    int mice = ManyMouse_Init();
    if (mice < 0) {
        UtilityFunctions::printerr("Multi-Mouse: ManyMouse init failed on Linux");
        return;
    }

    _initialized = true;
    _running.store(true);

    for (int i = 0; i < mice; ++i) {
        PendingEvent event;
        event.type = PendingEvent::Type::DeviceConnected;
        event.guid = guid_for_index(i);
        event.device_index = i;
        const char *name = ManyMouse_DeviceName(i);
        event.info.name = name ? String(name) : String("Mouse");
        event.info.system_id = String(event.guid.c_str());
        const char *driver_name = ManyMouse_DriverName();
        event.info.transport = driver_name ? String(driver_name) : String("manymouse");
        enqueue_event(event);
    }

    _thread = std::thread([this]() { thread_main(); });
}

void MultiMouseBackendLinux::stop() {
    if (!_running.load()) {
        return;
    }
    _running.store(false);
    if (_thread.joinable()) {
        _thread.join();
    }
    if (_initialized) {
        ManyMouse_Quit();
        _initialized = false;
    }
    _guid_to_id.clear();
    _guid_to_button_mask.clear();
    _last_abs_position.clear();
    _has_abs_position.clear();
}

void MultiMouseBackendLinux::poll() {
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
                _last_abs_position.erase(event.guid);
                _has_abs_position.erase(event.guid);
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

void MultiMouseBackendLinux::thread_main() {
    while (_running.load()) {
        ManyMouseEvent ev;
        int rc = ManyMouse_PollEvent(&ev);
        if (rc == 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            continue;
        }
        if (rc < 0) {
            UtilityFunctions::printerr("Multi-Mouse: ManyMouse_PollEvent returned error");
            break;
        }

        PendingEvent event;
        event.guid = guid_for_index(static_cast<int>(ev.device));
        event.device_index = static_cast<int>(ev.device);
        event.timestamp_us = now_microseconds();

        switch (ev.type) {
            case MANYMOUSE_EVENT_RELMOTION: {
                event.type = PendingEvent::Type::Motion;
                if (ev.item == 0) {
                    event.relative = Vector2((real_t)ev.value, 0.0f);
                } else if (ev.item == 1) {
                    event.relative = Vector2(0.0f, (real_t)ev.value);
                } else {
                    continue;
                }
                enqueue_event(event);
                break;
            }
            case MANYMOUSE_EVENT_ABSMOTION: {
                event.type = PendingEvent::Type::Motion;
                auto &last = _last_abs_position[event.guid];
                auto &has = _has_abs_position[event.guid];
                if (ev.item > 1) {
                    continue;
                }
                if (!has[ev.item]) {
                    last[ev.item] = ev.value;
                    has[ev.item] = true;
                    continue;
                }
                int delta = ev.value - last[ev.item];
                last[ev.item] = ev.value;
                if (delta == 0) {
                    continue;
                }
                if (ev.item == 0) {
                    event.relative = Vector2((real_t)delta, 0.0f);
                } else {
                    event.relative = Vector2(0.0f, (real_t)delta);
                }
                enqueue_event(event);
                break;
            }
            case MANYMOUSE_EVENT_BUTTON: {
                event.type = PendingEvent::Type::Button;
                event.button_index = static_cast<int32_t>(ev.item) + BUTTON_LEFT;
                event.pressed = (ev.value != 0);
                event.button_mask = update_button_mask(event.guid, event.button_index, event.pressed);
                enqueue_event(event);
                break;
            }
            case MANYMOUSE_EVENT_SCROLL: {
                event.type = PendingEvent::Type::Button;
                bool vertical = (ev.item == 0);
                bool positive = (ev.value > 0);
                event.button_index = vertical ? (positive ? BUTTON_WHEEL_UP : BUTTON_WHEEL_DOWN)
                                               : (positive ? BUTTON_WHEEL_RIGHT : BUTTON_WHEEL_LEFT);
                event.pressed = true;
                event.button_mask = update_button_mask(event.guid, event.button_index, true);
                enqueue_event(event);
                event.pressed = false;
                event.button_mask = update_button_mask(event.guid, event.button_index, false);
                enqueue_event(event);
                break;
            }
            case MANYMOUSE_EVENT_DISCONNECT: {
                event.type = PendingEvent::Type::DeviceDisconnected;
                enqueue_event(event);
                break;
            }
            default:
                break;
        }
    }
}

void MultiMouseBackendLinux::enqueue_event(const PendingEvent &event) {
    std::lock_guard<std::mutex> lock(_queue_mutex);
    _queue.push_back(event);
}

std::string MultiMouseBackendLinux::guid_for_index(int device_index) const {
    return std::string("manymouse-") + std::to_string(device_index);
}

uint64_t MultiMouseBackendLinux::now_microseconds() const {
    using namespace std::chrono;
    return duration_cast<microseconds>(steady_clock::now().time_since_epoch()).count();
}

uint32_t MultiMouseBackendLinux::update_button_mask(const std::string &guid, int32_t button_index, bool pressed) {
    if (button_index <= 0) {
        return 0;
    }
    uint32_t &mask = _guid_to_button_mask[guid];
    uint32_t bit = 1u << (button_index - 1);
    if (pressed) {
        mask |= bit;
    } else {
        mask &= ~bit;
    }
    return mask;
}

} // namespace godot

#endif // __linux__
