#ifndef MULTI_MOUSE_INPUT_EVENTS_H
#define MULTI_MOUSE_INPUT_EVENTS_H

#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class InputEventMultiMouseMotion : public InputEventMouseMotion {
    GDCLASS(InputEventMultiMouseMotion, InputEventMouseMotion);

protected:
    static void _bind_methods();

public:
    InputEventMultiMouseMotion() = default;
    ~InputEventMultiMouseMotion() override = default;

    void set_device_guid(const String &p_guid);
    String get_device_guid() const;

private:
    String device_guid;
};

class InputEventMultiMouseButton : public InputEventMouseButton {
    GDCLASS(InputEventMultiMouseButton, InputEventMouseButton);

protected:
    static void _bind_methods();

public:
    InputEventMultiMouseButton() = default;
    ~InputEventMultiMouseButton() override = default;

    void set_device_guid(const String &p_guid);
    String get_device_guid() const;

private:
    String device_guid;
};

} // namespace godot

#endif // MULTI_MOUSE_INPUT_EVENTS_H
