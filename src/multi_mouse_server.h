#ifndef MULTI_MOUSE_SERVER_H
#define MULTI_MOUSE_SERVER_H

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

struct MultiMouseDeviceInfo {
    int32_t device_id = -1;
    String name;
    String system_id;
};

class MultiMouseServer : public Object {
    GDCLASS(MultiMouseServer, Object);

protected:
    static void _bind_methods();

public:
    MultiMouseServer();
    ~MultiMouseServer();

    TypedArray<Dictionary> get_connected_devices() const;

    void poll();

private:
    TypedArray<Dictionary> _devices_cache;
};

} // namespace godot

#endif // MULTI_MOUSE_SERVER_H
