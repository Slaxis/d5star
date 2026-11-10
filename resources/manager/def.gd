# DefManager: discovers, loads, and manages game definitions (Def subclasses).
#
# A Def is provided or inferred. A provided Def is a script, one `.gd` each,
# its file name the Def's id, in the game's folder of Defs, `game/defs/`
# (`defs` in d5star.json), with an optional `.json` beside it that it loads
# whole. The library provides none of its own.
#
# Every Thing under a module's `things/` names its Def, `"def": "<id>"`, in
# itself or in its ancestor, and the folder it sits in does not count. The
# provided Def of that id takes the Thing, and must be a KindDef, the only Def
# that holds Things; with none, the Thing goes to a KindDef inferred for that
# id, which lives while its module is active. A Thing with no way to its Def,
# or of a Def that holds no Things, is an error, with its path: `errors()`.
extends D5Manager
class_name DefManager

const ID := "defs"
const GD_EXT := "gd"
const JSON_EXT := "json"

# The keys of a Thing that place it, which no Def receives.
const KEY_ID := "id"
const KEY_DEF := "def"
const KEY_ANCESTOR := "ancestor"
const KEY_ABSTRACT := "abstract"

func manager_id() -> String: return ID

var defs_root: String = "res://game/defs"
var system_subdir: String = "system"
# Subdirectory inside a module's content_root that holds the Things, at any
# depth. Named `def_things` in the config to avoid colliding with the
# engine-level `"things"` (which points at the legacy Thing autoload base).
var def_things_subdir: String = "things"

func configure(config: Dictionary) -> void:
	var game_root: String = "res://" + String(config.get("game_root", "game"))
	defs_root = game_root + "/" + String(config.get("defs", "defs"))
	system_subdir = String(config.get("system", system_subdir))
	def_things_subdir = String(config.get("def_things", def_things_subdir))

var _scripts: Dictionary = {}
var _defs: Dictionary = {}
var _base_json: Dictionary = {}
var _inferred: Array[String] = []    # the KindDefs inferred for the active modules
var _errors: Array[String] = []      # the Things the last activation could not place

func _read_json(path: String) -> Dictionary:
	if path == "":
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

func scan() -> void:
	_scripts.clear()
	_defs.clear()
	_base_json.clear()
	_inferred.clear()
	_errors.clear()
	_scan_defs(defs_root)

# The provided Defs: each script of the folder whose instance is a Def.
func _scan_defs(root: String) -> void:
	if root == "":
		return
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if entry.begins_with(".") or dir.current_is_dir():
			continue
		if entry.get_extension().to_lower() != GD_EXT:
			continue
		var def_id: String = _key(entry.get_basename())
		if def_id == "":
			continue
		var script_path: String = root + "/" + entry
		var script: GDScript = load(script_path) as GDScript
		if script == null:
			continue
		var instance: Object = script.new()
		if not instance is Def:
			continue
		var def: Def = instance as Def
		def.def_id = def_id
		_scripts[def_id] = script
		var json_path: String = root + "/" + def_id + "." + JSON_EXT
		var raw: Dictionary = _read_json(json_path)
		_base_json[def_id] = raw
		if not raw.is_empty():
			def.load_data(raw)
		_defs[def_id] = def
	dir.list_dir_end()

func _reset_def(def_id: String) -> void:
	var script: GDScript = _scripts.get(def_id, null)
	if script == null:
		return
	var instance: Object = script.new()
	if not instance is Def:
		return
	var def: Def = instance as Def
	def.def_id = def_id
	var raw: Dictionary = _base_json.get(def_id, {})
	if not raw.is_empty():
		def.load_data(raw)
	_defs[def_id] = def

func _apply_override(def_id: String, content_roots: Array[String]) -> void:
	for root: String in content_roots:
		var script_path: String = root + "/" + system_subdir + "/" + def_id + "." + GD_EXT
		if not ResourceLoader.exists(script_path):
			continue
		var script: GDScript = load(script_path) as GDScript
		if script == null:
			continue
		var instance: Object = script.new()
		if not instance is Def:
			continue
		var override_def: Def = instance as Def
		override_def.def_id = def_id
		var base_raw: Dictionary = _base_json.get(def_id, {})
		if not base_raw.is_empty():
			override_def.load_data(base_raw)
		_defs[def_id] = override_def
		break
	var overrides: Array[Dictionary] = []
	for root: String in content_roots:
		var json_path: String = root + "/" + system_subdir + "/" + def_id + "." + JSON_EXT
		var raw: Dictionary = _read_json(json_path)
		if not raw.is_empty():
			overrides.append(raw)
	overrides.reverse()
	var active_def: Def = _defs.get(def_id, null)
	if active_def == null:
		return
	for raw: Dictionary in overrides:
		active_def.merge_data(raw)

# Content roots come highest priority first: the active module, then the
# modules it requires.
func apply_module_overrides(content_roots: Array[String]) -> void:
	for def_id: String in _inferred:
		_defs.erase(def_id)
	_inferred.clear()
	_errors.clear()
	for def_id: String in _scripts.keys():
		_reset_def(def_id)
	for def_id: String in _scripts.keys():
		_apply_override(def_id, content_roots)
	_place(_read_things(content_roots))

# What the last activation could not place, one line each, with its path.
func errors() -> Array[String]:
	return _errors.duplicate()

# ─── Reading the Things ───────────────────────────────────────────

# Every Thing of the active modules, lowest priority first, so a Thing of the
# active module takes the place of its dependency's Thing of the same id, and
# a new one goes to the end. Inside a module the walk is the same on every
# machine: files before folders, both sorted, at any depth. One file holds
# one Thing (an object, its id the file name when it names none) or many (a
# list). Each Thing comes as { "thing": Dictionary, "path": String }.
func _read_things(content_roots: Array[String]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for i: int in range(content_roots.size() - 1, -1, -1):
		_read_dir(content_roots[i] + "/" + def_things_subdir, found)
	return found

func _read_dir(dir_path: String, found: Array[Dictionary]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var files: Array[String] = []
	var subdirs: Array[String] = []
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		if dir.current_is_dir():
			subdirs.append(entry)
		elif entry.get_extension().to_lower() == JSON_EXT:
			files.append(entry)
	dir.list_dir_end()
	files.sort()
	subdirs.sort()
	for file_name: String in files:
		_read_file(dir_path + "/" + file_name, found)
	for sub_dir: String in subdirs:
		_read_dir(dir_path + "/" + sub_dir, found)

func _read_file(path: String, found: Array[Dictionary]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_error(path, "could not be opened")
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_error(path, "not JSON, line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	var parsed: Variant = json.data
	if parsed is Dictionary:
		_take(parsed as Dictionary, path, path.get_file().get_basename(), found)
	elif parsed is Array:
		for entry: Variant in (parsed as Array):
			if entry is Dictionary:
				_take(entry as Dictionary, path, "", found)
			else:
				_error(path, "an entry of the list is not an object")
	else:
		_error(path, "not an object nor a list of objects")

func _take(raw: Dictionary, path: String, fallback_id: String, found: Array[Dictionary]) -> void:
	if String(raw.get(KEY_ID, "")).strip_edges() == "":
		if fallback_id == "":
			_error(path, "a Thing without an id")
			return
		raw[KEY_ID] = fallback_id
	found.append({ "thing": raw, "path": path })

# ─── Placing them ─────────────────────────────────────────────────

# Each Thing to the KindDef it names, in the order read: the one a script
# provides, or one inferred for that id. A template, `abstract`, only gives
# itself to the Things that name it as their ancestor. A Thing of a Def that
# holds no Things, such as one that loads its JSON whole, template or not,
# goes nowhere, after saying so.
func _place(found: Array[Dictionary]) -> void:
	var by_id: Dictionary = {}    # id -> its Things, in the order read
	for entry: Dictionary in found:
		var id: String = _key(String(entry["thing"][KEY_ID]))
		if not by_id.has(id):
			by_id[id] = []
		(by_id[id] as Array).append(entry)
	var placed: int = 0
	for entry: Dictionary in found:
		var def_id: String = _def_of(entry, by_id, [])
		if def_id == "":
			continue
		var def: Def = _defs.get(def_id, null)
		if def != null and not def is KindDef:
			var how: String = "names the def" if entry["thing"].has(KEY_DEF) else "takes from its ancestor the def"
			_error(entry["path"], "'%s' %s '%s', which holds no Things" % [
				_key(String(entry["thing"][KEY_ID])), how, def_id])
			continue
		if bool(entry["thing"].get(KEY_ABSTRACT, false)):
			continue
		var data: Variant = _data_of(entry, def_id, by_id, [])
		if data == null:
			continue
		var kind: KindDef = def as KindDef
		if kind == null:
			kind = KindDef.new()
			kind.def_id = def_id
			_defs[def_id] = kind
			_inferred.append(def_id)
		var thing: Dictionary = { KEY_ID: entry["thing"][KEY_ID] }
		thing.merge(data as Dictionary)
		kind.add_thing(thing)
		placed += 1
	if not found.is_empty():
		print("[DefManager] %d of %d Things placed; %d Defs, %d of them inferred; %d errors" % [
			placed, found.size(), _defs.size(), _inferred.size(), _errors.size()])

# The id of the Def a Thing names, in itself or up its ancestors; "" when
# there is none, after saying why. Each Thing is worked out once.
func _def_of(entry: Dictionary, by_id: Dictionary, chain: Array) -> String:
	if entry.has("def"):
		return String(entry["def"])
	var thing: Dictionary = entry["thing"]
	var id: String = _key(String(thing[KEY_ID]))
	var def_id: String = ""
	if thing.has(KEY_DEF):
		def_id = _key(String(thing[KEY_DEF]))
		if def_id == "":
			_error(entry["path"], "'%s' names an empty def" % id)
	elif String(thing.get(KEY_ANCESTOR, "")).strip_edges() == "":
		_error(entry["path"], "'%s' names no def, and has no ancestor to take one from" % id)
	elif chain.has(id):
		_error(entry["path"], "'%s' is its own ancestor: %s" % [id, " -> ".join(chain + [id])])
	else:
		var ancestor: String = _key(String(thing[KEY_ANCESTOR]))
		var defs: Array[String] = []
		for other: Dictionary in by_id.get(ancestor, []):
			var other_def: String = _def_of(other, by_id, chain + [id])
			if other_def != "" and not defs.has(other_def):
				defs.append(other_def)
		if entry.has("def"):
			return String(entry["def"])    # a circle back to this Thing, said where it closed
		if not by_id.has(ancestor):
			_error(entry["path"], "'%s' names the ancestor '%s', and no Thing is '%s'" % [id, ancestor, ancestor])
		elif defs.size() > 1:
			_error(entry["path"], "'%s' names the ancestor '%s', a Thing of %s: say its def" % [id, ancestor, " and ".join(defs)])
		elif defs.is_empty():
			_error(entry["path"], "'%s' names the ancestor '%s', which has no def" % [id, ancestor])
		else:
			def_id = defs[0]
	entry["def"] = def_id
	return def_id

# A Thing's data, without the keys that place it: its own, merged over its
# ancestor's as D5Star merges Things, the ancestor being the last Thing read
# with that id in the same Def. null when the ancestor is not there, after
# saying why. Each Thing is worked out once.
func _data_of(entry: Dictionary, def_id: String, by_id: Dictionary, chain: Array) -> Variant:
	if entry.has("data"):
		return entry["data"]
	var thing: Dictionary = entry["thing"]
	var id: String = _key(String(thing[KEY_ID]))
	var own: Dictionary = {}
	for key: Variant in thing:
		if not [KEY_ID, KEY_DEF, KEY_ANCESTOR, KEY_ABSTRACT].has(key):
			own[key] = thing[key]
	var ancestor: String = _key(String(thing.get(KEY_ANCESTOR, "")))
	var data: Variant = own
	if ancestor != "":
		data = null
		var base: Dictionary = {}
		for other: Dictionary in by_id.get(ancestor, []):
			if _def_of(other, by_id, []) == def_id:
				base = other
		if chain.has(id):
			_error(entry["path"], "'%s' is its own ancestor: %s" % [id, " -> ".join(chain + [id])])
		elif base.is_empty():
			_error(entry["path"], "'%s' names the ancestor '%s', which is no Thing of the def '%s'" % [id, ancestor, def_id])
		else:
			var inherited: Variant = _data_of(base, def_id, by_id, chain + [id])
			if inherited != null:
				data = ThingVariant.merge(inherited, own)
	entry["data"] = data
	return data

func _error(path: String, message: String) -> void:
	var line: String = "%s: %s" % [path, message]
	_errors.append(line)
	push_error("[DefManager] " + line)

func get_def(def_id: String) -> Def:
	return _defs.get(_key(def_id), null)

func list_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: String in _defs.keys():
		ids.append(k)
	return ids
