#include "multi_mouse_server.h"

#include "multi_mouse_backend.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2.hpp>

using namespace godot;

MultiMouseServer::MultiMouseServer() {
    _backend = create_multi_mouse_backend(this);
}

MultiMouseServer::~MultiMouseServer() {
    disable_backend();
}

void MultiMouseServer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_connected_devices"), &MultiMouseServer::get_connected_devices);
    ClassDB::bind_method(D_METHOD("poll"), &MultiMouseServer::poll);
    ClassDB::bind_method(D_METHOD("enable_backend"), &MultiMouseServer::enable_backend);
    ClassDB::bind_method(D_METHOD("disable_backend"), &MultiMouseServer::disable_backend);

    ADD_SIGNAL(MethodInfo("device_connected",
                          PropertyInfo(Variant::INT, "device_id"),
                          PropertyInfo(Variant::DICTIONARY, "info")));
    ADD_SIGNAL(MethodInfo("device_disconnected",
                          PropertyInfo(Variant::INT, "device_id")));
    ADD_SIGNAL(MethodInfo("motion",
                          PropertyInfo(Variant::OBJECT, "event", PROPERTY_HINT_RESOURCE_TYPE, "InputEventMouseMotion")));
    ADD_SIGNAL(MethodInfo("button",
                          PropertyInfo(Variant::OBJECT, "event", PROPERTY_HINT_RESOURCE_TYPE, "InputEventMouseButton")));
}

TypedArray<Dictionary> MultiMouseServer::get_connected_devices() {
    TypedArray<Dictionary> result;
    for (const auto &pair : _devices) {
        result.push_back(pair.second);
    }
    return result;
}

void MultiMouseServer::poll() {
    if (_backend && _backend_running) {
        _backend->poll();
    }
}

void MultiMouseServer::enable_backend() {
    if (_backend && !_backend_running) {
        _backend->start();
        _backend_running = true;
    }
}

void MultiMouseServer::disable_backend() {
    if (_backend && _backend_running) {
        _backend->stop();
        _backend_running = false;
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

Ref<InputEventMouseMotion> MultiMouseServer::make_motion_event(int32_t device_id,
                                                               const Vector2 &relative,
                                                               uint64_t timestamp_us,
                                                               const String &device_guid) {
    Ref<InputEventMouseMotion> event;
    event.instantiate();
    event->set_device(device_id);

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
    event->set_meta("device_guid", device_guid);
    return event;
}

Ref<InputEventMouseButton> MultiMouseServer::make_button_event(int32_t device_id,
                                                               int32_t button_index,
                                                               bool pressed,
                                                               uint32_t mask,
                                                               uint64_t timestamp_us,
                                                               const String &device_guid) {
    Ref<InputEventMouseButton> event;
    event.instantiate();
    event->set_device(device_id);
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
    event->set_meta("device_guid", device_guid);
    return event;
}

void MultiMouseServer::emit_motion(const Ref<InputEventMouseMotion> &event) {
    emit_signal("motion", event);
}

void MultiMouseServer::emit_button(const Ref<InputEventMouseButton> &event) {
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
