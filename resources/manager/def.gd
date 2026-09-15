# DefManager: discovers, loads, and manages game definitions (Def subclasses).
extends D5Manager
class_name DefManager

const ID := "defs"
const GD_EXT := "gd"
const JSON_EXT := "json"

func manager_id() -> String: return ID

var defs_root: String = "res://game/defs"
var system_subdir: String = "system"
# Subdirectory inside a module's content_root that holds per-Thing
# Def entries (one folder per Thing: `things/<def_id>/<thing_id>/<thing_id>.json`).
# Renamed `def_things` to avoid colliding with the engine-level
# `"things"` config (which points at the legacy Thing autoload base).
var def_things_subdir: String = "things"

func configure(config: Dictionary) -> void:
	var game_root: String = "res://" + String(config.get("game_root", "game"))
	defs_root = game_root + "/" + String(config.get("defs", "defs"))
	system_subdir = String(config.get("system", system_subdir))
	def_things_subdir = String(config.get("def_things", def_things_subdir))

var _scripts: Dictionary = {}
var _defs: Dictionary = {}
var _base_json: Dictionary = {}

func _read_json(path: String) -> Dictionary:
	var parsed: Variant = _parse_json(path)
	return parsed as Dictionary if parsed is Dictionary else {}

# Unlike _read_json this keeps an array instead of discarding it, because a
# Thing file is allowed to hold a list of them.
func _parse_json(path: String) -> Variant:
	if path == "":
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

func scan() -> void:
	_scripts.clear()
	_defs.clear()
	_base_json.clear()
	var root: String = defs_root
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

func apply_module_overrides(content_roots: Array[String]) -> void:
	for def_id: String in _scripts.keys():
		_reset_def(def_id)
	for def_id: String in _scripts.keys():
		_apply_override(def_id, content_roots)
	# After legacy overrides settle, scan each module's `things/`
	# subtree and feed per-Thing JSONs into the matching Defs via
	# Def.add_thing(). Defs that don't override add_thing() silently
	# ignore — keeps backward compat with the single-file mode.
	_scan_things(content_roots)

# Walks every active module's `<root>/<def_things_subdir>/<def_id>/<thing_id>/<thing_id>.json`
# and routes each Thing to its Def via Def.add_thing(). Modules later in
# content_roots[] overwrite earlier ones for the same Thing id.
func _scan_things(content_roots: Array[String]) -> void:
	print("[DefManager] _scan_things: content_roots=", content_roots, " def_things_subdir=", def_things_subdir)
	print("[DefManager] _defs keys=", _defs.keys())
	for root: String in content_roots:
		var things_root: String = root + "/" + def_things_subdir
		var things_dir: DirAccess = DirAccess.open(things_root)
		print("[DefManager]   root=", things_root, " dir_open=", things_dir != null)
		if things_dir == null:
			continue
		things_dir.list_dir_begin()
		while true:
			var def_id: String = things_dir.get_next()
			if def_id == "":
				break
			if def_id.begins_with(".") or not things_dir.current_is_dir():
				continue
			print("[DefManager]     found def_id=", def_id, " is_def=", _defs.has(def_id))
			var def: Def = _defs.get(def_id, null)
			if def == null:
				continue    # Module dropped Things for a Def we don't know
			_scan_thing_dir(def, things_root + "/" + def_id)
		things_dir.list_dir_end()

# Walks everything under `things/<def_id>/` and hands each Thing it finds to
# the Def. LAYOUT IS CONVENTION, NOT STRUCTURE:
#
#   things/team/flag_kings/flag_kings.json    one Thing, id from the folder
#   things/actor/flag_kings/qb.json           one Thing, id from inside
#   things/actor/flag_kings/squad.json        an ARRAY: many Things, one file
#   things/actor/everybody.json               all of them, flat
#
# All four are the same content organised differently, and a curator should be
# able to pick whichever fits how they actually work — by club, by
# neighbourhood, by whatever — without the engine caring. Files are read
# before subdirectories and both are sorted, so the merge order is the same on
# every machine rather than whatever the filesystem happened to hand back.
func _scan_thing_dir(def: Def, dir_path: String) -> void:
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
		_ingest_thing_file(def, dir_path + "/" + file_name)
	for sub_dir: String in subdirs:
		_scan_thing_dir(def, dir_path + "/" + sub_dir)

# One file holds one Thing (a JSON object) or many (a JSON array).
func _ingest_thing_file(def: Def, path: String) -> void:
	var parsed: Variant = _parse_json(path)
	if parsed is Dictionary:
		# The filename is the id when the Thing does not name itself, which is
		# what makes `<folder>/<folder>.json` keep working.
		_ingest_thing(def, parsed as Dictionary, path, path.get_file().get_basename())
	elif parsed is Array:
		for entry: Variant in (parsed as Array):
			if entry is Dictionary:
				# No filename fallback here: one name cannot identify many.
				_ingest_thing(def, entry as Dictionary, path, "")
			else:
				push_error("[DefManager] %s: array entry is not an object" % path)
	elif parsed != null:
		push_error("[DefManager] %s: expected an object or an array" % path)

func _ingest_thing(def: Def, raw: Dictionary, path: String, fallback_id: String) -> void:
	if not raw.has("id") or String(raw["id"]).strip_edges() == "":
		if fallback_id == "":
			push_error("[DefManager] %s: Thing without an id" % path)
			return
		raw["id"] = fallback_id
	print("[DefManager]       thing_id=", raw["id"], " path=", path)
	def.add_thing(raw)

func get_def(def_id: String) -> Def:
	return _defs.get(_key(def_id), null)

func list_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: String in _defs.keys():
		ids.append(k)
	return ids
