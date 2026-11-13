# Refs: the fields that name other Things, as the modules declare them. A Thing
# of the def `ref`, its id the def it speaks of, says which fields of that
# def's Things hold ids, and of what:
#
#     { "id": "mutant", "def": "ref", "fields": {
#         "element": "element",
#         "habitat[]": "biome",
#         "stats{}": "stat",
#         "res": { "def": "element", "also": ["luxury"] } } }
#
# A path goes down the keys of a dictionary, `battle.hit.stat`. A step may end
# in `[]`, each item of a list, or in `{}`, each key of a dictionary, and `*` is
# each value of a dictionary: `battle.*.stat`, `marks.*`, `start.*{}`. A field
# that is not there, or holds "" or null, names nothing. Anything else must be
# the id of a Thing of the def the field names, one of its `also`, or, when it
# names `class`, a class_name of the project. A module brings the declarations
# of its own defs, and replaces a dependency's by bringing one of the same id,
# as it replaces any Thing.
#
# RefsValidator asks every Def, at each module switch, what it finds wrong in
# itself by these fields: a KindDef checks its Things, and a Def of data checks
# its data with `check`.
class_name Refs
extends RefCounted

const DEF := "ref"       # the def of the declarations
const CLASS := "class"   # the target of a field that names a class_name

# The fields the active modules declare for `def_id`, path -> target; empty
# when they declare none.
static func fields_of(def_id: String) -> Dictionary:
	var refs: KindDef = Drive.def(DEF) as KindDef
	if refs == null:
		return {}
	var fields: Variant = refs.get_thing(def_id).get("fields", {})
	return fields if fields is Dictionary else {}

# What a field names, as { "def": String, "also": Array }: a def id, or an
# object with its `def` and the names it takes that are no Thing, `also`.
# Empty when the declaration names nothing.
static func target(declared: Variant) -> Dictionary:
	if declared is String and String(declared) != "":
		return { "def": String(declared), "also": [] }
	if declared is Dictionary and declared.get("def") is String and String(declared["def"]) != "":
		var also: Variant = declared.get("also", [])
		return { "def": String(declared["def"]), "also": also if also is Array else [] }
	return {}

# Every value `path` reaches in `data`, each as [where, value]: `where` is the
# path with the keys and the places it went through, `habitat[1]`,
# `battle.hit.stat`, `stats{}`.
static func values(data: Variant, path: String) -> Array:
	var found: Array = []
	_walk(data, path.split("."), 0, "", found)
	return found

static func _walk(node: Variant, steps: PackedStringArray, i: int, where: String, found: Array) -> void:
	if i == steps.size():
		found.append([where, node])
		return
	if not node is Dictionary:
		return
	var step: String = steps[i]
	var tail: String = ""
	if step.ends_with("[]") or step.ends_with("{}"):
		tail = step.right(2)
		step = step.left(-2)
	var table: Dictionary = node
	var keys: Array = table.keys() if step == "*" else ([step] if table.has(step) else [])
	var here: String = where + ("." if where != "" else "")
	for key: Variant in keys:
		var at: String = here + str(key)
		var value: Variant = table[key]
		match tail:
			"[]":
				if value is Array:
					for k: int in (value as Array).size():
						_walk(value[k], steps, i + 1, "%s[%d]" % [at, k], found)
			"{}":
				if value is Dictionary:
					for name: Variant in value:
						_walk(name, steps, i + 1, at + "{}", found)
			_:
				_walk(value, steps, i + 1, at, found)

# What is wrong in `data` by the fields, one line each: a value that is the id
# of no Thing of the def its field names. A field whose def holds no Things is
# skipped, since the validator says so once. `known` keeps the ids of each def
# between calls, and `reached` counts, per path, the values each path reached,
# the empty ones too, so a caller can tell a declared field that no data has.
static func check(data: Variant, fields: Dictionary, known: Dictionary, reached: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for path: String in fields:
		var named: Dictionary = target(fields[path])
		if named.is_empty() or _ids(String(named["def"]), known) == null:
			continue
		var found: Array = values(data, path)
		reached[path] = int(reached.get(path, 0)) + found.size()
		for pair: Array in found:
			var value: Variant = pair[1]
			if value == null:
				continue
			if not (value is String or value is StringName):
				out.append("%s %s is no id" % [pair[0], JSON.stringify(value)])
				continue
			var id: String = String(value)
			if id == "" or (named["also"] as Array).has(id) or (_ids(named["def"], known) as Dictionary).has(id):
				continue
			out.append("%s '%s' is no %s" % [pair[0], id, String(named["def"])])
	return out

# The ids of a def, as a set, kept in `known`: the class_names of the project
# for `class`, null for a def that holds no Things.
static func _ids(def_id: String, known: Dictionary) -> Variant:
	if not known.has(def_id):
		var ids: Variant = null
		if def_id == CLASS:
			ids = {}
			for entry: Dictionary in ProjectSettings.get_global_class_list():
				ids[String(entry["class"])] = true
		elif Drive.def(def_id) is KindDef:
			ids = {}
			for id: String in (Drive.def(def_id) as KindDef).ids():
				ids[id] = true
		known[def_id] = ids
	return known[def_id]
