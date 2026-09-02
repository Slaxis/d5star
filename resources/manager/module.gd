# ModuleManager: discovers native and user modules, resolves content roots
# and dependency load order.
extends D5Manager
class_name ModuleManager

const ID := "modules"

func manager_id() -> String: return ID

var native_root: String = "res://game/modules"
var user_root: String = "user://modules"
var manifest_name: String = "module.json"
var content_subdir: String = "content"

func configure(config: Dictionary) -> void:
	var game_root: String = "res://" + String(config.get("game_root", "game"))
	native_root = game_root + "/" + String(config.get("modules", "modules"))
	user_root = String(config.get("user_modules", user_root))
	manifest_name = String(config.get("module_manifest", manifest_name))
	content_subdir = String(config.get("content", content_subdir))

var _native: Dictionary = {}
var _user:   Dictionary = {}

func _parse_manifest(manifest_path: String, base_path: String) -> ModuleInfo:
	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return null
	return ModuleInfo.from_dict(parsed as Dictionary, base_path)

func _scan_dir(root: String, cache: Dictionary, is_user: bool) -> Array[ModuleInfo]:
	var results: Array[ModuleInfo] = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return results
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if entry.begins_with(".") or not dir.current_is_dir():
			continue
		var module_path: String = root + "/" + entry
		var manifest_path: String = module_path + "/" + manifest_name
		var info: ModuleInfo = _parse_manifest(manifest_path, module_path)
		if info == null or info.id == "":
			continue
		if is_user:
			info.user_path = module_path
		results.append(info)
		cache[info.id] = info
	dir.list_dir_end()
	results.sort_custom(func(a: ModuleInfo, b: ModuleInfo) -> bool: return a.order < b.order)
	return results

func scan_native() -> Array[ModuleInfo]:
	_native.clear()
	return _scan_dir(native_root, _native, false)

func scan_user() -> Array[ModuleInfo]:
	_user.clear()
	return _scan_dir(user_root, _user, true)

func list_all() -> Array[ModuleInfo]:
	if _native.is_empty():
		scan_native()
	if _user.is_empty():
		scan_user()
	var seen: Dictionary = {}
	var results: Array[ModuleInfo] = []
	for info: ModuleInfo in (_native.values() as Array):
		var user_override: String = user_root + "/" + info.id
		if DirAccess.open(user_override) != null:
			info.user_path = user_override
		results.append(info)
		seen[info.id] = true
	for info: ModuleInfo in (_user.values() as Array):
		if not seen.has(info.id):
			results.append(info)
	results.sort_custom(func(a: ModuleInfo, b: ModuleInfo) -> bool: return a.order < b.order)
	return results

func get_module(id: String) -> ModuleInfo:
	var key: String = id.strip_edges().to_lower()
	if _native.is_empty():
		scan_native()
	if _native.has(key):
		return _native[key]
	if _user.is_empty():
		scan_user()
	return _user.get(key, null)

func get_content_roots(id: String) -> Array[String]:
	var key: String = id.strip_edges().to_lower()
	var info: ModuleInfo = get_module(key)
	var roots: Array[String] = []
	var user_content: String = user_root + "/" + key + "/" + content_subdir
	if DirAccess.open(user_content) != null:
		roots.append(user_content)
	if info != null and info.native_path != "":
		var native_content: String = info.native_path + "/" + content_subdir
		if DirAccess.open(native_content) != null:
			roots.append(native_content)
	return roots

func get_module_root(id: String) -> String:
	var key: String = id.strip_edges().to_lower()
	var info: ModuleInfo = get_module(key)
	if info != null and info.native_path != "":
		return info.native_path
	return ""

# --- Dependency resolution (R3 — module.requires) ---

# Returns the module plus its required dependencies, ordered so each
# dependency comes before the module that needs it. Returns an empty
# array if a required module is missing or a dependency cycle exists.
func resolve_load_order(id: String) -> Array[String]:
	var order: Array[String] = []
	var visiting: Dictionary = {}
	var done: Dictionary = {}
	if not _visit(id.strip_edges().to_lower(), order, visiting, done):
		return []
	return order

func _visit(id: String, order: Array[String], visiting: Dictionary, done: Dictionary) -> bool:
	if id == "":
		push_error("ModuleManager: empty module id in dependency graph.")
		return false
	if done.has(id):
		return true
	if visiting.has(id):
		push_error("ModuleManager: dependency cycle involving module: " + id)
		return false
	var info: ModuleInfo = get_module(id)
	if info == null:
		push_error("ModuleManager: required module not found: " + id)
		return false
	visiting[id] = true
	for dep: String in info.requires:
		if not _visit(dep, order, visiting, done):
			return false
	visiting.erase(id)
	done[id] = true
	order.append(id)
	return true
