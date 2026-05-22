# Coordinator for the Thing system and content resolver.
# Layer: The -> God -> Drive.
extends Node

var _catalog: ThingCatalog = null
var _thing_assets: Dictionary = {}
var _thing_assets_ready: bool = false

func _ready() -> void:
	_catalog = ThingCatalog.new()
	Drive.active_module_changed.connect(_on_module_changed)

# R4 — Thing types, prototypes, and indices are module-scoped. Clearing
# them on a module switch prevents entities from leaking across modules.
func _on_module_changed(_module_id: String) -> void:
	if _catalog != null:
		_catalog.reset()
	_thing_assets.clear()
	_thing_assets_ready = false

func _key(id: String) -> String:
	return String(id).strip_edges().to_lower()

func _ensure_thing_assets() -> void:
	if _thing_assets_ready:
		return
	_thing_assets_ready = true
	_thing_assets.clear()
	var root: String = Drive.things_path()
	if root == "":
		return
	var assets: Array[Asset] = Drive.list(root)
	for asset in assets:
		if asset.kind != "gd":
			continue
		_thing_assets[_key(asset.id)] = asset

# --- Thing System ---

func create(type_id: String) -> Node:
	return _catalog.create(type_id)

func build_instance(thing_id: String, script_id: String, data: Dictionary, parts: Array[String]) -> Node:
	return _catalog.build_instance(thing_id, script_id, data, parts)

func register_type(spec: Dictionary, replace: bool = true) -> ThingType:
	return _catalog.register_runtime_type(spec, replace)

func load_types(specs: Array) -> void:
	_catalog.load_runtime_types(specs)

func list_by_group(group_id: String) -> Array[String]:
	return _catalog.list_ids_by_group(group_id)

func resolve_type(type_id: String) -> ThingType:
	return _catalog.resolve_type(type_id)

func thing_script(script_id: String) -> Script:
	var key: String = _key(script_id)
	if key == "":
		return null
	if key == "thing":
		var base_path: String = Drive.thing_base_script()
		if base_path == "" or not ResourceLoader.exists(base_path):
			return null
		return load(base_path) as Script
	_ensure_thing_assets()
	var asset: Asset = _thing_assets.get(key, null)
	if asset == null:
		return null
	return load(asset.path) as Script

# --- Content resolvers ---

func rules() -> Rules:
	var new_rules: Rules = Drive.rules()
	if new_rules == null:
		return Rules.new()
	return new_rules

func ui(ui_id: String) -> PackedScene:
	var path: String = Drive.ui(ui_id)
	if path == "":
		return null
	return load(path) as PackedScene

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
