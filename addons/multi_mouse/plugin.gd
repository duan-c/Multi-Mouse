extends EditorPlugin

const AUTOLOAD_NAME := "MultiMouse"
const AUTOLOAD_PATH := "res://addons/multi_mouse/multi_mouse_manager.gd"

func _enter_tree() -> void:
    if not ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
        add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree() -> void:
    if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
        remove_autoload_singleton(AUTOLOAD_NAME)
