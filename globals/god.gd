# Coordinator for the Thing system + thin typed-media facade over
# Drive. Layer: The → God → Drive. God owns ZERO loading: every
# media call is a one-line delegate to Drive, and Drive routes
# through the right Manager (ResourceManager / Loader / etc).
extends Node

var _catalog: ThingCatalog = null

func _ready() -> void:
	_catalog = ThingCatalog.new()
	Drive.active_module_changed.connect(_on_module_changed)

# R4 — Thing types/prototypes/indices are module-scoped. Clearing on
# module switch prevents entities from leaking across modules. The
# resource cache reset is Drive's responsibility (it owns ResourceManager).
func _on_module_changed(_module_id: String) -> void:
	if _catalog != null:
		_catalog.reset()

# --- Thing System ---

func create(type_id: String) -> RefCounted:
	return _catalog.create(type_id)

func build_instance(thing_id: String, script_id: String, data: Dictionary, parts: Array[String]) -> RefCounted:
	return _catalog.build_instance(thing_id, script_id, data, parts)

func register_type(spec: Dictionary, replace: bool = true) -> ThingType:
	return _catalog.register_runtime_type(spec, replace)

func load_types(specs: Array) -> void:
	_catalog.load_runtime_types(specs)

func list_by_group(group_id: String) -> Array[String]:
	return _catalog.list_ids_by_group(group_id)

func resolve_type(type_id: String) -> ThingType:
	return _catalog.resolve_type(type_id)

# Thing-script lookup by short id. Drive.script_by_id handles base
# scripts (key == "thing"), AssetManager lookup, and lazy scan via
# the things_asset_root hint.
func thing_script(script_id: String) -> Script:
	return Drive.script_by_id(script_id, Drive.things_path())

# --- Content resolvers ---

func rules() -> Rules:
	var new_rules: Rules = Drive.rules()
	if new_rules == null:
		return Rules.new()
	return new_rules

func all_content() -> Array[Dictionary]:
	return Drive.list_all_content()

func thing_content(thing_id: String) -> Dictionary:
	return Drive.read_content(Drive.content_path(thing_id))

# Unified lookup: runtime-registered Things first, then disk JSON content.
# Use this when displaying arbitrary Thing data that may have been injected
# by a generator rather than shipped as a file.
func thing_data(thing_id: String) -> Dictionary:
	var runtime: Dictionary = _catalog.get_runtime_spec(thing_id)
	if not runtime.is_empty():
		return runtime
	return Drive.read_content(Drive.content_path(thing_id))

# --- Typed media facades — all one-line delegates to Drive --------------
#
# Game/engine code uses these and never touches Drive directly for media
# resolution. JSON references things by short ID or class_name; God ↔
# Drive ↔ ResourceManager handles the rest. See docs/D5STAR.md §8.

func script(class_name_str: String) -> Script:
	return Drive.script(class_name_str)

func texture(asset_id: String, extension: String = "png") -> Texture2D:
	return Drive.texture(asset_id, extension)

func shader(asset_id: String, extension: String = "gdshader") -> Shader:
	return Drive.shader(asset_id, extension)

func sound(asset_id: String, extension: String = "ogg") -> AudioStream:
	return Drive.sound(asset_id, extension)

func scene(scene_id: String) -> PackedScene:
	return Drive.scene(scene_id)

func json(asset_id: String) -> Dictionary:
	return Drive.json(asset_id)
