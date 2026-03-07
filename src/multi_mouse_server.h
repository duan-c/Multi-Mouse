#ifndef MULTI_MOUSE_SERVER_H
#define MULTI_MOUSE_SERVER_H

#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cstdint>
#include <memory>
#include <unordered_map>

namespace godot {

struct MultiMouseDeviceInfo {
    String name;
    String system_id;
    String transport;
};

class MultiMouseBackend;

class MultiMouseServer : public Object {
    GDCLASS(MultiMouseServer, Object);

public:
    MultiMouseServer();
    ~MultiMouseServer() override;

    TypedArray<Dictionary> get_connected_devices();
    void poll();
    void enable_backend();
    void disable_backend();
    void attach_to_window(uint64_t hwnd);

    int32_t register_device(const MultiMouseDeviceInfo &info);
    void unregister_device(int32_t device_id);

    Ref<InputEventMouseMotion> make_motion_event(int32_t device_id,
                                                 const Vector2 &relative,
                                                 uint64_t timestamp_us,
                                                 const String &device_guid);

    Ref<InputEventMouseButton> make_button_event(int32_t device_id,
                                                 int32_t button_index,
                                                 bool pressed,
                                                 uint32_t mask,
                                                 uint64_t timestamp_us,
                                                 const String &device_guid);

    void emit_motion(const Ref<InputEventMouseMotion> &event);
    void emit_button(const Ref<InputEventMouseButton> &event);

protected:
    static void _bind_methods();

private:
    Dictionary _device_info_to_dict(int32_t id, const MultiMouseDeviceInfo &info) const;

    int32_t _next_device_id = 1;
    std::unordered_map<int32_t, Dictionary> _devices;
    std::unordered_map<int32_t, Vector2> _device_positions;
    std::unique_ptr<MultiMouseBackend> _backend;
    bool _backend_running = false;
};

} // namespace godot

#endif // MULTI_MOUSE_SERVER_H
