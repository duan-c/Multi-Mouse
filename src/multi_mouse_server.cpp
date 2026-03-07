#include "multi_mouse_server.h"

#include "multi_mouse_backend.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2.hpp>

using namespace godot;

MultiMouseServer::MultiMouseServer() {
    _backend = create_multi_mouse_backend(this);

    if (_backend) {
        _backend->start();
    } else {
        MultiMouseDeviceInfo info;
        info.name = String("Placeholder Mouse");
        info.system_id = String("placeholder");
        info.transport = String("stub");
        register_device(info);
    }
}

MultiMouseServer::~MultiMouseServer() {
    if (_backend) {
        _backend->stop();
    }
}

void MultiMouseServer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_connected_devices"), &MultiMouseServer::get_connected_devices);
    ClassDB::bind_method(D_METHOD("poll"), &MultiMouseServer::poll);

    ADD_SIGNAL(MethodInfo("device_connected",
                          PropertyInfo(Variant::INT, "device_id"),
                          PropertyInfo(Variant::DICTIONARY, "info")));
    ADD_SIGNAL(MethodInfo("device_disconnected",
                          PropertyInfo(Variant::INT, "device_id")));
    ADD_SIGNAL(MethodInfo("motion",
                          PropertyInfo(Variant::OBJECT, "event", PROPERTY_HINT_RESOURCE_TYPE, "InputEventMultiMouseMotion")));
    ADD_SIGNAL(MethodInfo("button",
                          PropertyInfo(Variant::OBJECT, "event", PROPERTY_HINT_RESOURCE_TYPE, "InputEventMultiMouseButton")));
}

TypedArray<Dictionary> MultiMouseServer::get_connected_devices() {
    TypedArray<Dictionary> result;
    for (const auto &pair : _devices) {
        result.push_back(pair.second);
    }
    return result;
}

void MultiMouseServer::poll() {
    if (_backend) {
        _backend->poll();
    }
}

int32_t MultiMouseServer::register_device(const MultiMouseDeviceInfo &info) {
    const int32_t device_id = _next_device_id++;
    Dictionary dict = _device_info_to_dict(device_id, info);
    _devices[device_id] = dict;
    _device_positions[device_id] = Vector2();
    emit_signal("device_connected", device_id, dict);
    return device_id;
}

void MultiMouseServer::unregister_device(int32_t device_id) {
    if (_devices.erase(device_id) > 0) {
        _device_positions.erase(device_id);
        emit_signal("device_disconnected", device_id);
    }
}

Ref<InputEventMultiMouseMotion> MultiMouseServer::make_motion_event(int32_t device_id,
                                                                    const Vector2 &relative,
                                                                    uint64_t timestamp_us,
                                                                    const String &device_guid) {
    Ref<InputEventMultiMouseMotion> event;
    event.instantiate();
    event->set_device(device_id);
    event->set_device_guid(device_guid);

    Vector2 position = _device_positions[device_id];
    position += relative;
    _device_positions[device_id] = position;

    event->set_position(position);
    event->set_global_position(position);
    event->set_relative(relative);
    event->set_velocity(Vector2());
    event->set_button_mask(0);
    event->set_pressure(0.0);
    event->set_tilt(Vector2());
    event->set_meta("timestamp_us", (int64_t)timestamp_us);
    return event;
}

Ref<InputEventMultiMouseButton> MultiMouseServer::make_button_event(int32_t device_id,
                                                                    int32_t button_index,
                                                                    bool pressed,
                                                                    uint32_t mask,
                                                                    uint64_t timestamp_us,
                                                                    const String &device_guid) {
    Ref<InputEventMultiMouseButton> event;
    event.instantiate();
    event->set_device(device_id);
    event->set_device_guid(device_guid);
    event->set_button_index(static_cast<MouseButton>(button_index));
    event->set_pressed(pressed);
    event->set_button_mask(mask);

    Vector2 position;
    auto it = _device_positions.find(device_id);
    if (it != _device_positions.end()) {
        position = it->second;
    }
    event->set_position(position);
    event->set_global_position(position);

    event->set_meta("timestamp_us", (int64_t)timestamp_us);
    return event;
}

void MultiMouseServer::emit_motion(const Ref<InputEventMultiMouseMotion> &event) {
    emit_signal("motion", event);
}

void MultiMouseServer::emit_button(const Ref<InputEventMultiMouseButton> &event) {
    emit_signal("button", event);
}

Dictionary MultiMouseServer::_device_info_to_dict(int32_t id, const MultiMouseDeviceInfo &info) const {
    Dictionary dict;
    dict["device_id"] = id;
    dict["name"] = info.name;
    dict["system_id"] = info.system_id;
    dict["transport"] = info.transport;
    return dict;
}
