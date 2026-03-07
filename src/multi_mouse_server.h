#ifndef MULTI_MOUSE_SERVER_H
#define MULTI_MOUSE_SERVER_H

#include "input_events.h"

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

    TypedArray<Dictionary> get_connected_devices() const;
    void poll();

    int32_t register_device(const MultiMouseDeviceInfo &info);
    void unregister_device(int32_t device_id);

    Ref<InputEventMultiMouseMotion> make_motion_event(int32_t device_id,
                                                      const Vector2 &relative,
                                                      uint64_t timestamp_us,
                                                      const String &device_guid);

    Ref<InputEventMultiMouseButton> make_button_event(int32_t device_id,
                                                      int32_t button_index,
                                                      bool pressed,
                                                      uint32_t mask,
                                                      uint64_t timestamp_us,
                                                      const String &device_guid);

    void emit_motion(const Ref<InputEventMultiMouseMotion> &event);
    void emit_button(const Ref<InputEventMultiMouseButton> &event);

protected:
    static void _bind_methods();

private:
    Dictionary _device_info_to_dict(int32_t id, const MultiMouseDeviceInfo &info) const;

    int32_t _next_device_id = 1;
    std::unordered_map<int32_t, Dictionary> _devices;
    std::unordered_map<int32_t, Vector2> _device_positions;
    std::unique_ptr<MultiMouseBackend> _backend;
};

} // namespace godot

#endif // MULTI_MOUSE_SERVER_H
