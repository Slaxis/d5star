# PathManager: resolves all filesystem paths for the engine.
extends Manager
class_name PathManager

const ID := "paths"

func manager_id() -> String: return ID

const RES_ROOT       := "res://"
const JSON_EXTENSION := "json"
const SCENE_EXTENSION := "tscn"

var engine_root: String = RES_ROOT + "engine"
var game_root: String = RES_ROOT + "game"
var parsers_subpath: String = "globals/drive/parser/parsers"
var loaders_subpath: String = "globals/drive/loader/loaders"
var validators_subpath: String = "globals/drive/validator/validators"
var things_subpath: String = "thing/things"
var thing_base_subpath: String = "thing/thing.gd"
var scene_dir_id: String = "scene"
var game_config_name: String = "game"

func configure(config: Dictionary) -> void:
	engine_root = RES_ROOT + String(config.get("engine_root", "engine"))
	game_root = RES_ROOT + String(config.get("game_root", "game"))
	parsers_subpath = String(config.get("parsers", parsers_subpath))
	loaders_subpath = String(config.get("loaders", loaders_subpath))
	validators_subpath = String(config.get("validators", validators_subpath))
	things_subpath = String(config.get("things", things_subpath))
	thing_base_subpath = String(config.get("thing_base", thing_base_subpath))
	scene_dir_id = String(config.get("scene_dir", scene_dir_id))
	game_config_name = String(config.get("game_config", game_config_name))

var _content_roots: Array[String] = []
var _module_root: String = ""
var _resolvers: Dictionary = {}

func set_module_roots(roots: Array[String], module_root: String) -> void:
	_content_roots = roots.duplicate()
	_module_root = module_root

func register_resolver(resource_id: String, fn: Callable) -> void:
	_resolvers[resource_id.to_lower()] = fn

func _make_resolver(resolved_path: String) -> Callable:
	return func() -> String: return resolved_path

func absorb_directories(dirs: Directories) -> void:
	for key: String in dirs.items.keys():
		if not _resolvers.has(key):
			_resolvers[key] = _make_resolver(_module_root + "/" + dirs.get_dir(key))

func _make_file_name(path: String, extension: String) -> String:
	if path == "" or extension == "":
		return path
	var suffix: String = "." + extension
	if path.ends_with(suffix):
		return path
	return path + suffix

func _find_file(root: String, target: String) -> String:
	if root == "" or target == "":
		return ""
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		var global_root: String = ProjectSettings.globalize_path(root)
		dir = DirAccess.open(global_root)
		if dir == null:
			return ""
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
			var found: String = _find_file(entry_path, target)
			if found != "":
				dir.list_dir_end()
				return found
			continue
		if entry == target:
			dir.list_dir_end()
			return entry_path
	dir.list_dir_end()
	return ""

func _find_content_asset_multi(file_name: String, extension: String) -> String:
	var target: String = _make_file_name(file_name, extension)
	for root: String in _content_roots:
		var found: String = _find_file(root, target)
		if found != "":
			return found
	return ""

func parsers_root() -> String:
	return engine_root + "/" + parsers_subpath

func loaders_root() -> String:
	return engine_root + "/" + loaders_subpath

func validators_root() -> String:
	return engine_root + "/" + validators_subpath

func things_path() -> String:
	return engine_root + "/" + things_subpath

func thing_base_script() -> String:
	return engine_root + "/" + thing_base_subpath

func resolve_resource_path(resource_id: String) -> String:
	var key: String = resource_id.to_lower()
	# "rules" and "directories" both resolve from the active module's game
	# config file. Handled inline so PathManager keeps no self-capturing
	# resolver Callables — those would form a reference cycle and leak.
	if key == "rules" or key == "directories":
		return _find_content_asset_multi(game_config_name, JSON_EXTENSION)
	if _resolvers.has(key):
		return (_resolvers[key] as Callable).call()
	return ""

func content_root() -> String:
	if _content_roots.is_empty():
		return ""
	return _content_roots[0]

# All active content roots, highest priority first (active module, then
# the modules it requires). Used to scan content across the dependency set.
func content_roots() -> Array[String]:
	return _content_roots.duplicate()

func content_path(asset_id: String, extension: String = JSON_EXTENSION) -> String:
	var key: String = String(asset_id).strip_edges().to_lower()
	if key == "":
		return ""
	return _find_content_asset_multi(key, extension)

func scene_path(scene_id: String, dirs: Directories) -> String:
	if scene_id == "":
		return ""
	if scene_id.begins_with(RES_ROOT):
		return scene_id
	var scene_dir: String = dirs.get_dir(scene_dir_id, scene_dir_id) if dirs else scene_dir_id
	# 1) Scene shipped inside the active module.
	if _module_root != "":
		var in_module: String = _module_root + "/" + scene_dir + "/" + scene_id + "/" + scene_id + "." + SCENE_EXTENSION
		if ResourceLoader.exists(in_module):
			return in_module
	# 2) R5 — game-level shell scene for screens that cannot live inside
	#    a module (e.g. a module/campaign selector shown before any
	#    module is active).
	var in_game: String = game_root + "/" + scene_dir_id + "/" + scene_id + "/" + scene_id + "." + SCENE_EXTENSION
	if ResourceLoader.exists(in_game):
		return in_game
	return ""
