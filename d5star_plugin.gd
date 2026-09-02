# D5Star editor plugin. Its only job is registering the engine's eight
# autoloads in the right order, so a game never hand-writes them into
# project.godot. Enable the plugin once in Project Settings > Plugins and
# Godot persists the entries; headless and exported builds need nothing.
#
# Order matters: Air (bus) and Log come first because Drive logs during
# boot; God composes its hubs over Drive; The reads God.
@tool
extends EditorPlugin

const _AUTOLOADS: Array = [
	["Air",         "globals/air.gd"],
	["Log",         "globals/log.gd"],
	["Drive",       "globals/drive/drive.gd"],
	["God",         "globals/god/god.gd"],
	["The",         "globals/the.gd"],
	["I18n",        "globals/i18n.gd"],
	["SaveManager", "globals/save_manager.gd"],
	["Audio",       "globals/audio_manager.gd"],
]

# Derived, never hardcoded — same rule Drive follows for the engine root,
# so the folder can be named anything under res://addons/.
func _root() -> String:
	return get_script().resource_path.get_base_dir()

func _enable_plugin() -> void:
	var root: String = _root()
	for entry: Array in _AUTOLOADS:
		add_autoload_singleton(String(entry[0]), root + "/" + String(entry[1]))

func _disable_plugin() -> void:
	for entry: Array in _AUTOLOADS:
		remove_autoload_singleton(String(entry[0]))
