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
#
# It keeps each Thing as it was written too, for the catalog, which builds a
# Thing of a list as it builds one of a file of its own: `thing()`.
#
# A Thing carries parts as Caves of Qud's blueprints do: it names them in
# `parts`, and each part, a Thing of kind part wherever its file sits, gives
# its data under the Thing's own, so the Thing writes only what differs from
# the part (v0.13.0). A heir joins its parts to its ancestor's.
#
# The id of a Thing may say its parent, `<parent>.<name>` (J188): `card.loot`
# is the Thing `loot`, a heir of `card`. Such a Thing writes no def, ancestor
# nor kind: its def is the root of its chain, a native Thing that a lib
# registers (`natives` in engine.json and d5star.json), and its name is unique,
# as a class_name is. A Thing with no dot in its id is of the format of before,
# which names its def and its ancestor apart, and keeps working.
#
# Mesclar (J188): the Things read with one name and one def are the layers of
# one Thing, as Caves of Qud merges a blueprint: each changes only what it
# writes, the operators work on what came before it, and the lists join. A
# patch, a Thing that writes neither def, ancestor nor parent, only its name and
# what it changes, is a layer of the Thing of its name, so a mod changes one
# number without copying the line; a name that is a Thing of two defs makes it
# say its def.
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
# The keys of the parts a Thing carries, which stay in its data.
const KEY_PARTS := "parts"
const KEY_KIND := "kind"
const KIND_PART := "part"

func manager_id() -> String: return ID

var defs_root: String = "res://game/defs"
var system_subdir: String = "system"
# Subdirectory inside a module's content_root that holds the Things, at any
# depth. Named `def_things` in the config to avoid colliding with the
# engine-level `"things"` (which points at the legacy Thing autoload base).
var def_things_subdir: String = "things"
# The ids of the native Things, the roots of the chains of the format of J188:
# the library's and each composite's, as the configuration registers them.
var natives: Array[String] = []

func configure(config: Dictionary) -> void:
	var game_root: String = "res://" + String(config.get("game_root", "game"))
	defs_root = game_root + "/" + String(config.get("defs", "defs"))
	system_subdir = String(config.get("system", system_subdir))
	def_things_subdir = String(config.get("def_things", def_things_subdir))
	natives.clear()
	var given: Variant = config.get("natives", {})
	if given is Dictionary:
		for id: Variant in (given as Dictionary):
			natives.append(_key(String(id)))

var _scripts: Dictionary = {}
var _defs: Dictionary = {}
var _base_json: Dictionary = {}
var _inferred: Array[String] = []    # the KindDefs inferred for the active modules
var _errors: Array[String] = []      # the Things the last activation could not place
var _things: Dictionary = {}         # name -> the layers of the Thing of its last read, as written

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
	_things.clear()
	_scan_defs(defs_root)

# The provided Defs: each script of the folder whose instance is a Def. An
# abstract script is left unbuilt: it is there to be extended.
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
		if script == null or script.is_abstract():
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

# The module changed: its Things, and its overrides of the provided Defs,
# take the last module's place.
func on_module_changed(_module_id: String, content_roots: Array[String], _module_root: String) -> void:
	apply_module_overrides(content_roots)

# Content roots come highest priority first: the active module, then the
# modules it requires.
func apply_module_overrides(content_roots: Array[String]) -> void:
	for def_id: String in _inferred:
		_defs.erase(def_id)
	_inferred.clear()
	_errors.clear()
	_things.clear()
	for def_id: String in _scripts.keys():
		_reset_def(def_id)
	for def_id: String in _scripts.keys():
		_apply_override(def_id, content_roots)
	_place(_read_things(content_roots))

# What the last activation could not place, one line each, with its path.
func errors() -> Array[String]:
	return _errors.duplicate()

# A Thing of the active modules as its layers write it, with the keys that
# place it: the Thing of the last read of its id, which is the module's of
# highest priority, so the catalog builds a Thing of a list as it builds one of
# a file of its own, with each later layer's keys over the first's (Mesclar,
# J188). A Thing of the format of J188 comes by its name or by its whole id,
# with its id split in its name and its ancestor, the parent. A copy, empty
# when no module has the id.
func thing(thing_id: String) -> Dictionary:
	var written: Array[Dictionary] = layers(thing_id)
	if written.is_empty():
		return {}
	var out: Dictionary = written[0]
	for i: int in range(1, written.size()):
		out = ThingVariant.merge(out, written[i]) as Dictionary
	return out

# The layers of that Thing, each as it was written, the lowest priority first
# (Mesclar, J188): the catalog merges each over the one before, over what the
# Thing inherits. Copies; empty when no module has the id.
func layers(thing_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var key: String = _key(thing_id)
	var written: Variant = _things.get(Thing.name_of(key), null)
	if not written is Array:
		return out
	var ancestor: String = ""
	for layer: Dictionary in (written as Array):
		var named: String = _key(String(layer.get(KEY_ANCESTOR, "")))
		if named != "":
			ancestor = named
		out.append(layer.duplicate(true))
	var parent: String = Thing.parent_of(key)
	if parent != "" and ancestor != parent:
		out.clear()
	return out

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
	var entry: Dictionary = { "thing": raw, "path": path }
	var written: String = _key(String(raw[KEY_ID]))
	if written.contains(Thing.ID_DOT) and not _split_id(entry, written):
		return
	found.append(entry)

# A Thing of the format of J188 says its parent in its id, `<parent>.<name>`,
# with one dot, and writes no def, ancestor nor kind: the entry takes its name
# and its parent. False, after saying why, when the id is not so.
func _split_id(entry: Dictionary, written: String) -> bool:
	var parent: String = Thing.parent_of(written)
	var own_name: String = Thing.name_of(written)
	if parent == "" or own_name == "" or parent.contains(Thing.ID_DOT):
		_error(entry["path"], "'%s' is no id: an id is <parent>.<name>, with one dot" % written)
		return false
	if natives.has(own_name):
		_error(entry["path"], "'%s' takes the name of the native '%s'" % [written, own_name])
		return false
	for key: String in [KEY_DEF, KEY_ANCESTOR, KEY_KIND]:
		if (entry["thing"] as Dictionary).has(key):
			_error(entry["path"], "'%s' says its parent in its id, and so writes no %s" % [written, key])
			return false
	entry["name"] = own_name
	entry["parent"] = parent
	return true

# ─── Placing them ─────────────────────────────────────────────────

# Each Thing to the KindDef it names, in the order read: the one a script
# provides, or one inferred for that id. The Things read with one name and one
# def are the layers of one Thing (Mesclar, J188), placed once, where its first
# layer was read. A template, `abstract`, only gives itself to the Things that
# name it as their ancestor. A Thing of a Def that holds no Things, such as one
# that loads its JSON whole, template or not, goes nowhere, after saying so.
func _place(read: Array[Dictionary]) -> void:
	var found: Array[Dictionary] = _unique_names(read)
	var by_id: Dictionary = {}    # name -> its Things that are no patch, in the order read
	for entry: Dictionary in found:
		if _is_patch(entry):
			continue
		var id: String = _name(entry)
		if not by_id.has(id):
			by_id[id] = []
		(by_id[id] as Array).append(entry)
	var index: Dictionary = {}    # name -> def -> its Thing, with its layers
	var placed: int = 0
	for thing_of: Dictionary in _layered(found, by_id, index):
		var first: Dictionary = thing_of["layers"][0]
		var def_id: String = thing_of["def"]
		var def: Def = _defs.get(def_id, null)
		if def != null and not def is KindDef:
			var how: String = "names the def" if first["thing"].has(KEY_DEF) else "takes from its ancestor the def"
			_error(first["path"], "'%s' %s '%s', which holds no Things" % [_label(first), how, def_id])
			continue
		if _abstract(thing_of):
			continue
		var data: Variant = _data_of(thing_of, index, [])
		if data == null:
			continue
		data = _with_parts(data as Dictionary, index, first)
		var kind: KindDef = def as KindDef
		if kind == null:
			kind = KindDef.new()
			kind.def_id = def_id
			_defs[def_id] = kind
			_inferred.append(def_id)
		var thing: Dictionary = { KEY_ID: first.get("name", first["thing"][KEY_ID]) }
		thing.merge(data as Dictionary)
		kind.add_thing(thing)
		placed += 1
	if not read.is_empty():
		print("[DefManager] %d of %d Things placed; %d Defs, %d of them inferred; %d errors" % [
			placed, read.size(), _defs.size(), _inferred.size(), _errors.size()])

# The Things of the active modules, each with its layers (Mesclar, J188): the
# Things read with one name and one def, in the order read. A patch is a layer
# of the Thing of its name, in the one def that has it; one whose name has no
# Thing, or a Thing of two defs, is an error. Each Thing comes once, in the
# order of its first layer, and the catalog reads the layers of the Thing of
# the last read of each name.
func _layered(found: Array[Dictionary], by_id: Dictionary, index: Dictionary) -> Array[Dictionary]:
	var defs_of: Dictionary = {}    # name -> the defs of its Things, in the order read
	for entry: Dictionary in found:
		if _is_patch(entry):
			continue
		var def_id: String = _def_of(entry, by_id, [])
		var own_name: String = _name(entry)
		var defs: PackedStringArray = defs_of.get(own_name, PackedStringArray())
		if def_id != "" and not defs.has(def_id):
			defs.append(def_id)
		defs_of[own_name] = defs    # a packed array is a value: put it back
	var things: Array[Dictionary] = []
	var latest: Dictionary = {}    # name -> the Thing of its last read
	for entry: Dictionary in found:
		var own_name: String = _name(entry)
		var def_id: String = String(entry.get("def", ""))
		if _is_patch(entry):
			var defs: PackedStringArray = defs_of.get(own_name, PackedStringArray())
			if defs.size() == 1:
				def_id = defs[0]
			elif defs.is_empty():
				_error(entry["path"], "'%s' names no def, and has no ancestor to take one from" % _label(entry))
			else:
				_error(entry["path"], "'%s' names no def, and '%s' is a Thing of %s: say its def" % [
					_label(entry), own_name, " and ".join(defs)])
		if def_id == "":
			latest[own_name] = { "layers": [entry] }
			continue
		if not index.has(own_name):
			index[own_name] = {}
		if not (index[own_name] as Dictionary).has(def_id):
			var made: Dictionary = { "name": own_name, "def": def_id, "layers": [] }
			index[own_name][def_id] = made
			things.append(made)
		var thing_of: Dictionary = index[own_name][def_id]
		(thing_of["layers"] as Array).append(entry)
		latest[own_name] = thing_of
	for own_name: String in latest:
		var written: Array[Dictionary] = []
		for layer: Dictionary in latest[own_name]["layers"]:
			written.append(_as_written(layer))
		_things[own_name] = written
	return things

# A patch: a Thing that writes no def, no ancestor nor parent, only its name and
# what it changes, a layer of the Thing of its name (Mesclar, J188).
func _is_patch(entry: Dictionary) -> bool:
	var thing: Dictionary = entry["thing"]
	return not entry.has("parent") and not thing.has(KEY_DEF) and not thing.has(KEY_ANCESTOR)

# A layer's own data, without the keys that place it.
func _own(entry: Dictionary) -> Dictionary:
	var own: Dictionary = {}
	for key: Variant in entry["thing"]:
		if not [KEY_ID, KEY_DEF, KEY_ANCESTOR, KEY_ABSTRACT].has(key):
			own[key] = entry["thing"][key]
	return own

# Whether a Thing is a template: the last of its layers that says.
func _abstract(thing_of: Dictionary) -> bool:
	var out: bool = false
	for layer: Dictionary in thing_of["layers"]:
		if (layer["thing"] as Dictionary).has(KEY_ABSTRACT):
			out = bool(layer["thing"][KEY_ABSTRACT])
	return out

# The kind of a Thing, the last of its layers that writes one; "" when none.
func _kind(thing_of: Dictionary) -> String:
	var out: String = ""
	for layer: Dictionary in thing_of["layers"]:
		if (layer["thing"] as Dictionary).has(KEY_KIND):
			out = String(layer["thing"][KEY_KIND]).strip_edges().to_lower()
	return out

# The layer that says what a Thing inherits from: the last that names an
# ancestor or a parent, or its first.
func _naming(thing_of: Dictionary) -> Dictionary:
	var out: Dictionary = thing_of["layers"][0]
	for layer: Dictionary in thing_of["layers"]:
		if _ancestor(layer) != "":
			out = layer
	return out

# A name of the format of J188 is unique, as a class_name is: every Thing that
# writes it is the same Thing, with the same whole id, or a patch of it. One
# that takes the name of another, of either format, is left out, after saying
# so with its path. Two Things of the format of before may still share an id
# in two defs.
func _unique_names(read: Array[Dictionary]) -> Array[Dictionary]:
	var first: Dictionary = {}    # name -> the first Thing read with it
	var kept: Array[Dictionary] = []
	for entry: Dictionary in read:
		var own_name: String = _name(entry)
		var before: Dictionary = first.get(own_name, {})
		if _is_patch(entry):
			pass    # a layer of the Thing of its name, whatever its format
		elif before.is_empty():
			first[own_name] = entry
		elif (entry.has("parent") or before.has("parent")) and \
				(entry.has("parent") != before.has("parent") or _ancestor(entry) != _ancestor(before)):
			_error(entry["path"], "'%s' takes the name '%s', which is '%s' in %s: a name is unique" % [
				_label(entry), own_name, _label(before), before["path"]])
			continue
		kept.append(entry)
	return kept

# The name of the Thing of an entry: its id, or the name in an id of the format
# of J188.
func _name(entry: Dictionary) -> String:
	return String(entry["name"]) if entry.has("name") else _key(String(entry["thing"][KEY_ID]))

# The id of an entry as it was written, for what the boot says.
func _label(entry: Dictionary) -> String:
	return _key(String(entry["thing"][KEY_ID]))

# The Thing an entry inherits from: its ancestor, or the parent in an id of the
# format of J188; "" when none.
func _ancestor(entry: Dictionary) -> String:
	if entry.has("parent"):
		return String(entry["parent"])
	return _key(String(entry["thing"].get(KEY_ANCESTOR, "")))

# How the boot names what an entry inherits from.
func _ancestor_word(entry: Dictionary) -> String:
	return "the parent" if entry.has("parent") else "the ancestor"

# A Thing as the catalog reads it, as it was written: one of the format of J188
# with its id split in its name and its ancestor, the parent.
func _as_written(entry: Dictionary) -> Dictionary:
	if not entry.has("parent"):
		return entry["thing"]
	var out: Dictionary = { KEY_ID: entry["name"], KEY_ANCESTOR: entry["parent"] }
	for key: Variant in entry["thing"]:
		if key != KEY_ID:
			out[key] = entry["thing"][key]
	return out

# The id of the Def a Thing names, in itself or up its ancestors; "" when
# there is none, after saying why. A native at the root of the chain is the
# def (J188). Each Thing is worked out once.
func _def_of(entry: Dictionary, by_id: Dictionary, chain: Array) -> String:
	if entry.has("def"):
		return String(entry["def"])
	var thing: Dictionary = entry["thing"]
	var id: String = _name(entry)
	var label: String = _label(entry)
	var ancestor: String = _ancestor(entry)
	var def_id: String = ""
	if thing.has(KEY_DEF):
		def_id = _key(String(thing[KEY_DEF]))
		if def_id == "":
			_error(entry["path"], "'%s' names an empty def" % label)
	elif ancestor == "":
		_error(entry["path"], "'%s' names no def, and has no ancestor to take one from" % label)
	elif natives.has(ancestor):
		def_id = ancestor
	elif chain.has(id):
		_error(entry["path"], "'%s' is its own ancestor: %s" % [label, " -> ".join(chain + [id])])
	else:
		var defs: Array[String] = []
		for other: Dictionary in by_id.get(ancestor, []):
			var other_def: String = _def_of(other, by_id, chain + [id])
			if other_def != "" and not defs.has(other_def):
				defs.append(other_def)
		if entry.has("def"):
			return String(entry["def"])    # a circle back to this Thing, said where it closed
		var word: String = _ancestor_word(entry)
		if not by_id.has(ancestor):
			_error(entry["path"], "'%s' names %s '%s', and no Thing is '%s'" % [label, word, ancestor, ancestor])
		elif defs.size() > 1 and entry.has("parent"):
			_error(entry["path"], "'%s' names the parent '%s', a Thing of %s: name a parent of one def" % [
				label, ancestor, " and ".join(defs)])
		elif defs.size() > 1:
			_error(entry["path"], "'%s' names the ancestor '%s', a Thing of %s: say its def" % [label, ancestor, " and ".join(defs)])
		elif defs.is_empty():
			_error(entry["path"], "'%s' names %s '%s', which has no def" % [label, word, ancestor])
		else:
			def_id = defs[0]
	entry["def"] = def_id
	return def_id

# A Thing's data, without the keys that place it: its first layer's own data,
# merged over its ancestor's as D5Star merges Things, the ancestor being the
# Thing of that name in the same Def, and each later layer's merged over it in
# the order read (Mesclar, J188); a native has no data to give. null when the
# ancestor is not there, after saying why. Each Thing is worked out once.
func _data_of(thing_of: Dictionary, index: Dictionary, chain: Array) -> Variant:
	if thing_of.has("data"):
		return thing_of["data"]
	var layers_of: Array = thing_of["layers"]
	var own_name: String = thing_of["name"]
	var def_id: String = thing_of["def"]
	var named: Dictionary = _naming(thing_of)
	var ancestor: String = _ancestor(named)
	var data: Variant = _own(layers_of[0])
	if ancestor != "" and not natives.has(ancestor):
		data = null
		var base: Dictionary = (index.get(ancestor, {}) as Dictionary).get(def_id, {})
		if chain.has(own_name):
			_error(named["path"], "'%s' is its own ancestor: %s" % [_label(named), " -> ".join(chain + [own_name])])
		elif base.is_empty():
			_error(named["path"], "'%s' names %s '%s', which is no Thing of the def '%s'" % [
				_label(named), _ancestor_word(named), ancestor, def_id])
		else:
			var inherited: Variant = _data_of(base, index, chain + [own_name])
			if inherited != null:
				data = ThingVariant.merge(inherited, _own(layers_of[0]))
	if data != null:
		for i: int in range(1, layers_of.size()):
			data = ThingVariant.merge(data, _own(layers_of[i]))
	thing_of["data"] = data
	return data

# A Thing's data with its parts' under it: each part the Thing names in
# `parts`, its own and its ancestors', is the last Thing with that id whose
# kind is part, and gives each field of its data, its own `kind` and `parts`
# aside, that the Thing does not write; of two parts with a field, the one named
# last gives it. A part that is not there is an error, with the Thing's path.
func _with_parts(data: Dictionary, index: Dictionary, entry: Dictionary) -> Dictionary:
	var named: Variant = data.get(KEY_PARTS, [])
	if not named is Array or (named as Array).is_empty():
		return data
	var under: Dictionary = {}
	for part: Variant in named:
		var part_id: String = _key(String(part))
		var found: Dictionary = {}
		var of_name: Dictionary = index.get(part_id, {})
		for def_id: Variant in of_name:
			if _kind(of_name[def_id]) == KIND_PART:
				found = of_name[def_id]
		if found.is_empty():
			_error(entry["path"], "'%s' names the part '%s', and no Thing of kind part is '%s'" % [
				_key(String(entry["thing"][KEY_ID])), part_id, part_id])
			continue
		var given: Variant = _data_of(found, index, [])
		if given is Dictionary:
			var copy: Dictionary = (given as Dictionary).duplicate(true)
			copy.erase(KEY_KIND)
			copy.erase(KEY_PARTS)
			under.merge(copy, true)
	var out: Dictionary = {}
	for key: Variant in under:
		if not data.has(key):
			out[key] = under[key]
	out.merge(data, true)
	return out

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
