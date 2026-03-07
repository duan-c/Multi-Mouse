#include "input_events.h"

using namespace godot;

void InputEventMultiMouseMotion::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_device_guid", "guid"), &InputEventMultiMouseMotion::set_device_guid);
    ClassDB::bind_method(D_METHOD("get_device_guid"), &InputEventMultiMouseMotion::get_device_guid);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "device_guid"), "set_device_guid", "get_device_guid");
}

void InputEventMultiMouseMotion::set_device_guid(const String &p_guid) {
    device_guid = p_guid;
}

String InputEventMultiMouseMotion::get_device_guid() const {
    return device_guid;
}

void InputEventMultiMouseButton::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_device_guid", "guid"), &InputEventMultiMouseButton::set_device_guid);
    ClassDB::bind_method(D_METHOD("get_device_guid"), &InputEventMultiMouseButton::get_device_guid);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "device_guid"), "set_device_guid", "get_device_guid");
}

void InputEventMultiMouseButton::set_device_guid(const String &p_guid) {
    device_guid = p_guid;
}

String InputEventMultiMouseButton::get_device_guid() const {
    return device_guid;
}
