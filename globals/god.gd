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

# --- Typed resolvers (script / texture / scene / json / shader) -----------
#
# Game and engine code consumes media via these typed facades — never a
# `res://` path. JSON data files reference scripts by `class_name` and
# assets by short ID; God resolves them via Godot's global class registry
# (scripts) or Drive.content_path (textures / shaders / json data files).
#
# See `docs/BACKLOG.md` §B-001 for the convention rationale.

var _script_class_cache: Dictionary = {}    # class_name -> Script

# Resolves a GDScript class_name to its Script resource. Reads Godot's
# project-wide class list (populated by every `class_name X` declaration
# at boot), so any subclass — engine, module, or modder-supplied — is
# discoverable without hardcoding paths.
func script(class_name_str: String) -> Script:
	var key: String = String(class_name_str).strip_edges()
	if key == "":
		return null
	if _script_class_cache.has(key):
		return _script_class_cache[key]
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == key:
			var path: String = String(entry.get("path", ""))
			if path == "":
				return null
			var loaded: Script = load(path) as Script
			_script_class_cache[key] = loaded
			return loaded
	push_warning("God.script: unknown class_name '%s'" % key)
	_script_class_cache[key] = null
	return null

# Loads a texture by short id (no `res://`). Defers to Drive.content_path
# to find the file on disk via the project's content layout conventions.
# Accepts a fallback path for caller-side defaults — falls back when the
# id can't be resolved.
func texture(texture_id: String, fallback_path: String = "") -> Texture2D:
	var key: String = String(texture_id).strip_edges()
	if key == "":
		return _load_texture(fallback_path)
	if key.begins_with("res://"):
		# Caller passed a raw path — kept as an escape hatch for migration,
		# but it should be rare. The right pattern is short ids.
		return _load_texture(key)
	var path: String = Drive.content_path(key, "png")
	if path == "" or not ResourceLoader.exists(path):
		return _load_texture(fallback_path)
	return _load_texture(path)

func _load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
