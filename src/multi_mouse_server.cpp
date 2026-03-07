#include "multi_mouse_server.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

MultiMouseServer::MultiMouseServer() {
    // Placeholder devices until the native backend is implemented.
    Dictionary fake_device;
    fake_device["device_id"] = 0;
    fake_device["name"] = "Placeholder Mouse";
    fake_device["system_id"] = "placeholder";
    _devices_cache.push_back(fake_device);
}

MultiMouseServer::~MultiMouseServer() = default;

void MultiMouseServer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_connected_devices"), &MultiMouseServer::get_connected_devices);
    ClassDB::bind_method(D_METHOD("poll"), &MultiMouseServer::poll);

    ADD_SIGNAL(MethodInfo("device_connected", PropertyInfo(Variant::INT, "device_id"), PropertyInfo(Variant::DICTIONARY, "info")));
    ADD_SIGNAL(MethodInfo("device_disconnected", PropertyInfo(Variant::INT, "device_id")));
    ADD_SIGNAL(MethodInfo("motion", PropertyInfo(Variant::DICTIONARY, "event")));
    ADD_SIGNAL(MethodInfo("button", PropertyInfo(Variant::DICTIONARY, "event")));
}

TypedArray<Dictionary> MultiMouseServer::get_connected_devices() const {
    return _devices_cache;
}

void MultiMouseServer::poll() {
    // TODO: integrate native raw input backend.
}
