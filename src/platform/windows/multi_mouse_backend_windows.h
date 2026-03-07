#pragma once

#ifdef _WIN32

#include "../../multi_mouse_backend.h"
#include "../../multi_mouse_server.h"

#include <godot_cpp/variant/vector2.hpp>

#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

namespace godot {

class MultiMouseBackendWindows : public MultiMouseBackend {
public:
    explicit MultiMouseBackendWindows(MultiMouseServer *server);
    ~MultiMouseBackendWindows() override;

    void start() override;
    void stop() override;
    void poll() override;

private:
    struct PendingEvent {
        enum class Type { DeviceConnected, DeviceDisconnected, Motion, Button } type;
        std::string guid;
        MultiMouseDeviceInfo info;
        Vector2 relative;
        uint32_t button_mask = 0;
        int32_t button_index = 0;
        bool pressed = false;
        uint64_t timestamp_us = 0;
    };

    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);

    void thread_main();
    bool register_raw_input_window();
    void handle_raw_input(HRAWINPUT raw_handle);
    void handle_device_change(HANDLE device, bool arrival);
    std::string ensure_device_guid(HANDLE device);
    bool query_device_info(HANDLE device, MultiMouseDeviceInfo &out_info, std::string &out_guid) const;
    void enqueue_event(const PendingEvent &event);
    void enqueue_motion(const std::string &guid, const Vector2 &relative, uint64_t timestamp_us);
    void enqueue_button(const std::string &guid, int32_t button_index, bool pressed, uint32_t button_mask, uint64_t timestamp_us);
    uint64_t now_microseconds() const;
    uint32_t update_button_mask(const std::string &guid, int32_t button_index, bool pressed);

    void cleanup_window();

    std::thread _thread;
    std::atomic<bool> _running{false};
    HWND _hwnd = nullptr;

    std::mutex _queue_mutex;
    std::vector<PendingEvent> _queue;

    std::unordered_map<std::string, int32_t> _guid_to_id;
    std::unordered_map<std::string, uint32_t> _guid_to_button_mask;
    std::unordered_map<HANDLE, std::string> _handle_to_guid;
};

} // namespace godot

#endif // _WIN32
