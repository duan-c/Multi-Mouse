#pragma once

#ifdef __linux__

#include "multi_mouse_backend.h"
#include "multi_mouse_server.h"

#include <godot_cpp/variant/vector2.hpp>

#include <array>
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

namespace godot {

struct MultiMouseDeviceInfo;

class MultiMouseBackendLinux : public MultiMouseBackend {
public:
    explicit MultiMouseBackendLinux(MultiMouseServer *server);
    ~MultiMouseBackendLinux() override;

    void start() override;
    void stop() override;
    void poll() override;

private:
    struct PendingEvent {
        enum class Type { DeviceConnected, DeviceDisconnected, Motion, Button } type;
        std::string guid;
        MultiMouseDeviceInfo info;
        Vector2 relative;
        int device_index = -1;
        int32_t button_index = 0;
        bool pressed = false;
        uint32_t button_mask = 0;
        uint64_t timestamp_us = 0;
    };

    void thread_main();
    void enqueue_event(const PendingEvent &event);
    std::string guid_for_index(int device_index) const;
    uint64_t now_microseconds() const;
    uint32_t update_button_mask(const std::string &guid, int32_t button_index, bool pressed);

    std::thread _thread;
    std::atomic<bool> _running{false};
    bool _initialized = false;

    std::mutex _queue_mutex;
    std::vector<PendingEvent> _queue;

    std::unordered_map<std::string, int32_t> _guid_to_id;
    std::unordered_map<std::string, uint32_t> _guid_to_button_mask;
    std::unordered_map<std::string, std::array<int, 2>> _last_abs_position;
    std::unordered_map<std::string, std::array<bool, 2>> _has_abs_position;
};

} // namespace godot

#endif // __linux__
