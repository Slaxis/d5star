# Service locator for parsers, loaders, assets, path resolution,
# module management, defs. Routes every typed resource lookup
# through the appropriate Manager — game/engine code never touches
# `load()`, `ResourceLoader`, `FileAccess`, or `ProjectSettings`
# directly. The only escape is `_bootstrap_json` below, used to
# read the engine config before ResourceManager exists.
extends Node

const ENGINE_CONFIG := "res://engine/d5star/engine.json"

signal active_module_changed(module_id: String)

var _managers: Dictionary = {}  # manager_id -> Manager
var _module_id: String = ""

# --- Bootstrap (only for engine config — ResourceManager isn't alive yet) ---

func _bootstrap_json(path: String) -> Dictionary:
	if path == "":
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.log(self, "error", "Drive: failed to open bootstrap JSON: " + path)
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	Log.log(self, "error", "Drive: bootstrap JSON parse failed: " + path)
	return {}

func _scan_files(root: String, ext: String, results: Array[String]) -> void:
	if root == "":
		return
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		var global_root: String = ProjectSettings.globalize_path(root)
		dir = DirAccess.open(global_root)
		if dir == null:
			return
		root = global_root
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == ".." or entry.begins_with("."):
			continue
		var entry_path: String = root + "/" + entry
		if dir.current_is_dir():
			_scan_files(entry_path, ext, results)
			continue
		if entry.get_extension().to_lower() == ext:
			results.append(entry_path)
	dir.list_dir_end()

# --- Manager registry ---

func _register(mgr: Manager) -> void:
	_managers[mgr.manager_id()] = mgr

func _m(id: String) -> Manager:
	return _managers.get(id, null)

# --- Boot ---

func _load_engine_config() -> Dictionary:
	return _bootstrap_json(ENGINE_CONFIG)

func _get_resource(resource_id: String) -> Resource:
	var pr := _m(ParserManager.ID) as ParserManager
	var pm := _m(PathManager.ID) as PathManager
	var parser := pr.get_parser(resource_id)
	var path := pm.resolve_resource_path(resource_id)
	if not parser or path == "":
		return null
	return pr.get_or_parse(resource_id, parser, path)

func _set_managers() -> void:
	if not _managers.is_empty():
		return
	var config: Dictionary = _load_engine_config()
	_register(ParserManager.new())
	_register(ResourceManager.new())
	_register(AssetManager.new())
	var pm := PathManager.new()
	pm.configure(config)
	_register(pm)
	var mm := ModuleManager.new()
	mm.configure(config)
	_register(mm)
	var dm := DefManager.new()
	dm.configure(config)
	_register(dm)
	var am: AssetManager = _m(AssetManager.ID) as AssetManager
	var pr: ParserManager = _m(ParserManager.ID) as ParserManager
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	if am == null or pm == null or pr == null or rm == null:
		return
	pr.register_from_assets(am.list(pm.parsers_root()))
	rm.register_from_assets(am.list(pm.loaders_root()))
	dm.scan()

func _ready() -> void:
	_set_managers()

# --- Module API ---

func list_modules() -> Array[ModuleInfo]:
	var mm: ModuleManager = _m(ModuleManager.ID) as ModuleManager
	if mm == null:
		return []
	return mm.list_all()

func set_module(id: String) -> bool:
	var key: String = id.strip_edges().to_lower()
	if key == "":
		Log.log(self, "error", "Drive: set_module called with empty id.")
		return false
	var mm: ModuleManager = _m(ModuleManager.ID) as ModuleManager
	if mm == null:
		Log.log(self, "error", "Drive: ModuleManager not initialized.")
		return false
	# Resolve the module and its dependency closure (R3 — module.requires).
	var load_order: Array[String] = mm.resolve_load_order(key)
	if load_order.is_empty():
		Log.log(self, "error", "Drive: cannot activate module '" + key + "' — missing or cyclic dependencies.")
		return false
	# Content roots, highest priority first: the active module, then the
	# modules it requires (so the active module overrides its dependencies).
	var content_roots: Array[String] = []
	for i: int in range(load_order.size() - 1, -1, -1):
		content_roots.append_array(mm.get_content_roots(load_order[i]))
	if content_roots.is_empty():
		Log.log(self, "error", "Drive: no content roots found for module: " + key)
		return false
	var module_root: String = mm.get_module_root(key)
	var pm: PathManager = _m(PathManager.ID) as PathManager
	if pm == null:
		Log.log(self, "error", "Drive: PathManager not initialized.")
		return false
	pm.set_module_roots(content_roots, module_root)
	var dm: DefManager = _m(DefManager.ID) as DefManager
	if dm != null:
		dm.apply_module_overrides(content_roots)
	# Resource cache is module-scoped — paths shift on switch, stale
	# entries would silently return the wrong module's assets.
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	if rm != null:
		rm.reset()
	_module_id = key
	active_module_changed.emit(key)
	return true

func active_module() -> String:
	return _module_id

# --- Asset API ---

func list(asset_path: String) -> Array[Asset]:
	var am: AssetManager = _m(AssetManager.ID) as AssetManager
	if am == null:
		Log.log(self, "error", "Drive: assets not initialized.")
		return []
	return am.list(asset_path)

func lookup(asset_id: String) -> Asset:
	var am: AssetManager = _m(AssetManager.ID) as AssetManager
	if am == null:
		return null
	if am.assets.is_empty():
		var pm: PathManager = _m(PathManager.ID) as PathManager
		if pm == null:
			return null
		am.list(pm.parsers_root())
	return am.lookup(asset_id)

# --- Resource API (Parser-driven typed Resources) ---

func rules() -> Rules:
	return _get_resource("rules") as Rules

func directories() -> Directories:
	return _get_resource("directories") as Directories

# --- Def API ---

func def(def_id: String) -> Def:
	var dm: DefManager = _m(DefManager.ID) as DefManager
	if dm == null:
		return null
	return dm.get_def(def_id)

func defs() -> Array[String]:
	var dm: DefManager = _m(DefManager.ID) as DefManager
	if dm == null:
		return []
	return dm.list_ids()

# --- Path API ---

func _all_content_roots() -> Array[String]:
	var pm: PathManager = _m(PathManager.ID) as PathManager
	if pm == null:
		return []
	return pm.content_roots()

func content_path(asset_id: String, extension: String = "json") -> String:
	var pm: PathManager = _m(PathManager.ID) as PathManager
	if pm == null:
		return ""
	return pm.content_path(asset_id, extension)

func things_path() -> String:
	var pm: PathManager = _m(PathManager.ID) as PathManager
	if pm == null:
		return ""
	return pm.things_path()

func thing_base_script() -> String:
	var pm: PathManager = _m(PathManager.ID) as PathManager
	if pm == null:
		return ""
	return pm.thing_base_script()

# --- Typed media API (Loader-backed) ---
#
# Every method below resolves an id → path via PathManager, then
# delegates to ResourceManager.load_resource which dispatches to the
# right Loader. Callers never see paths and never call load().

func texture(asset_id: String, extension: String = "png") -> Texture2D:
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	if rm == null:
		return null
	var path: String = content_path(asset_id, extension)
	if path == "":
		return null
	return rm.load_resource(path) as Texture2D

func shader(asset_id: String, extension: String = "gdshader") -> Shader:
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	if rm == null:
		return null
	var path: String = content_path(asset_id, extension)
	if path == "":
		return null
	return rm.load_resource(path) as Shader

func sound(asset_id: String, extension: String = "ogg") -> AudioStream:
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	if rm == null:
		return null
	var path: String = content_path(asset_id, extension)
	if path == "":
		return null
	return rm.load_resource(path) as AudioStream

func scene(scene_id: String) -> PackedScene:
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	var pm: PathManager = _m(PathManager.ID) as PathManager
	if rm == null or pm == null:
		return null
	var path: String = pm.scene_path(scene_id, directories())
	if path == "":
		return null
	return rm.load_resource(path) as PackedScene

# class_name → Script via ResourceManager.resolve_class. Used for
# JSON entries like `"class": "GuanabaraMapGen"`.
func script(class_name_str: String) -> Script:
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	if rm == null:
		return null
	var path: String = rm.resolve_class(class_name_str)
	if path == "":
		push_warning("Drive.script: unknown class_name '%s'" % class_name_str)
		return null
	return rm.load_resource(path) as Script

# Thing-script lookup by short id (e.g. "card", "creature"). Special
# case "thing"/"thing_part" resolve to the engine base. Other ids
# resolve via AssetManager scanning `things_path()`.
func script_by_id(id: String, things_asset_root: String = "") -> Script:
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	var am: AssetManager = _m(AssetManager.ID) as AssetManager
	if rm == null or am == null:
		return null
	var key: String = String(id).strip_edges().to_lower()
	if key == "":
		return null
	if key == "thing":
		var base_path: String = thing_base_script()
		if base_path == "":
			return null
		return rm.load_resource(base_path) as Script
	var asset: Asset = am.lookup(key)
	if asset == null and things_asset_root != "":
		am.list(things_asset_root)
		asset = am.lookup(key)
	if asset == null:
		return null
	return rm.load_resource(asset.path) as Script

func json(asset_id: String) -> Dictionary:
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	if rm == null:
		return {}
	var path: String = content_path(asset_id, "json")
	if path == "":
		return {}
	var raw: Variant = rm.load_resource(path)
	return raw if raw is Dictionary else {}

# Raw JSON path read — for callers that already resolved the path
# (the content-scan iterators below). Goes through ResourceManager
# so caching + dispatch still apply.
func read_content(path: String) -> Dictionary:
	var rm: ResourceManager = _m(ResourceManager.ID) as ResourceManager
	if rm == null:
		# Pre-init fallback (should never trigger in normal boot).
		return _bootstrap_json(path)
	var raw: Variant = rm.load_resource(path)
	return raw if raw is Dictionary else {}

func list_all_content() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for root: String in _all_content_roots():
		var paths: Array[String] = []
		_scan_files(root, "json", paths)
		for path: String in paths:
			var raw: Dictionary = read_content(path)
			if not raw.is_empty():
				results.append(raw)
	return results

func list_json_by_group(group_id: String) -> Array[Dictionary]:
	var group: String = String(group_id).strip_edges().to_lower()
	if group == "":
		return []
	var results: Array[Dictionary] = []
	for root: String in _all_content_roots():
		var paths: Array[String] = []
		_scan_files(root, "json", paths)
		for path: String in paths:
			var raw: Dictionary = read_content(path)
			if raw.is_empty():
				continue
			if String(raw.get("group", "")).strip_edges().to_lower() == group:
				results.append(raw)
	return results
