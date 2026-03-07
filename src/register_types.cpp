#include "register_types.h"

#include "multi_mouse_server.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <gdextension_interface.h>

using namespace godot;

static MultiMouseServer *multi_mouse_server_singleton = nullptr;

void initialize_multi_mouse_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<MultiMouseServer>();

    multi_mouse_server_singleton = memnew(MultiMouseServer);
    Engine::get_singleton()->register_singleton("MultiMouseServer", multi_mouse_server_singleton);
}

void uninitialize_multi_mouse_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    if (multi_mouse_server_singleton) {
        Engine::get_singleton()->unregister_singleton("MultiMouseServer");
        memdelete(multi_mouse_server_singleton);
        multi_mouse_server_singleton = nullptr;
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT multi_mouse_library_init(const GDExtensionInterface *p_interface,
                                                    GDExtensionClassLibraryPtr p_library,
                                                    GDExtensionInitialization *r_initialization) {
    GDExtensionBinding::InitObject init_obj(p_interface, p_library, r_initialization);
    init_obj.register_initializer(initialize_multi_mouse_module);
    init_obj.register_terminator(uninitialize_multi_mouse_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}
}
