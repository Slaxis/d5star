# ResourceManager — owns typed resource loading. Holds pluggable
# Loaders (one per file extension family) and dispatches each
# `load_resource(path)` to the matching Loader. Caches by path so
# repeated lookups (cards re-querying the same texture etc.) skip
# disk + parsing.
#
# Adding a new resource type = drop a new Loader subclass in
# `engine/d5star/globals/drive/loader/loaders/`. ResourceManager
# auto-discovers it at boot via `register_from_assets`; no edit
# here.
#
# Also owns the class_name → script path lookup (`resolve_class`)
# so God / Drive never touch `ProjectSettings` directly. Class
# registry is conceptually a registry, not a load, but it lives
# here because everything it produces (paths to Scripts) flows
# into `load_resource` anyway.
extends Manager
class_name ResourceManager

const ID := "resources"

func manager_id() -> String: return ID

var _loaders_by_ext: Dictionary = {}    # ext -> Loader
var _cache: Dictionary = {}              # path -> Variant
var _class_paths: Dictionary = {}        # class_name -> resolved path (lazy)

func register(ldr: Loader) -> void:
	if ldr == null:
		return
	for ext: String in ldr.extensions():
		var key: String = String(ext).strip_edges().to_lower()
		if key != "":
			_loaders_by_ext[key] = ldr

# Discovery — same flow as ParserManager. Drive feeds the asset
# list from PathManager.loaders_root(); each .gd whose script
# extends `Loader` gets instantiated and registered.
func register_from_assets(asset_list: Array[Asset]) -> void:
	for asset in asset_list:
		register_from_asset(asset)

func register_from_asset(asset: Asset) -> void:
	if asset == null or asset.kind != "gd":
		return
	var script: Script = load(asset.path)
	if script == null:
		return
	var instance: Object = script.new()
	if instance is Loader:
		register(instance as Loader)

# Path → typed Variant dispatch. Returns null on miss or unknown
# extension; logs the unknown-extension case since that's almost
# always a registration bug (loader folder out of sync).
func load_resource(path: String) -> Variant:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var ext: String = path.get_extension().to_lower()
	var ldr: Loader = _loaders_by_ext.get(ext, null) as Loader
	if ldr == null:
		Log.log(self, "warning",
			"ResourceManager: no Loader registered for extension '%s' (path: %s)" % [ext, path])
		return null
	var resource: Variant = ldr.load_resource(path)
	if resource != null:
		_cache[path] = resource
	return resource

# class_name → file path via Godot's project-wide class registry.
# Cached on first lookup. Returns "" for unknown classes; caller
# is responsible for the typical `if path == "": ... fail` flow.
func resolve_class(class_name_str: String) -> String:
	var key: String = String(class_name_str).strip_edges()
	if key == "":
		return ""
	if _class_paths.has(key):
		return _class_paths[key]
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == key:
			var path: String = String(entry.get("path", ""))
			_class_paths[key] = path
			return path
	_class_paths[key] = ""
	return ""

# Clears the resource cache. Class path cache is preserved because
# `class_name` declarations don't shift between modules — they're
# baked into ProjectSettings at editor time. Called by Drive on
# module change.
func reset() -> void:
	_cache.clear()
