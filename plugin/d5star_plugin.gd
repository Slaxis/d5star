# D5Star editor plugin. Its only job is registering the engine's seven
# autoloads in the right order, so a game never hand-writes them into
# project.godot. Enable the plugin once in Project Settings > Plugins and
# Godot persists the entries; headless and exported builds need nothing.
#
# It lives in a folder of its own, `plugin/`, and `plugin.cfg`, which
# Godot looks for at the root of the library, names it there.
#
# Order matters: Air (bus) and Log come first because Drive logs during
# boot; God composes its hubs over Drive; The reads God.
@tool
extends EditorPlugin

const _AUTOLOADS: Array = [
	["Air",   "globals/air.gd"],
	["Log",   "globals/log.gd"],
	["Drive", "globals/drive/drive.gd"],
	["God",   "globals/god/god.gd"],
	["The",   "globals/the.gd"],
	["I18n",  "globals/i18n.gd"],
	["Radio", "globals/radio.gd"],
]

# The root of the library, one folder above the plugin's own. Derived,
# never hardcoded — same rule Drive follows for the engine root, so the
# folder can be named anything under res://addons/. Static, so a test
# can ask it: Godot builds an EditorPlugin only inside the editor.
static func root_of(script_path: String) -> String:
	return script_path.get_base_dir().get_base_dir()

func _enable_plugin() -> void:
	var root: String = root_of((get_script() as Script).resource_path)
	for entry: Array in _AUTOLOADS:
		add_autoload_singleton(String(entry[0]), root + "/" + String(entry[1]))

func _disable_plugin() -> void:
	for entry: Array in _AUTOLOADS:
		remove_autoload_singleton(String(entry[0]))
