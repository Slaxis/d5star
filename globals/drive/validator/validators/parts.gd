# PartsValidator — verifies that every entry in a Thing's `parts` field
# resolves to an existing Thing with `kind == "part"`, and every entry of
# its `mechanics` (J188), by name or by whole id, to a Thing that is a
# Mechanic, as the catalog would build it. Catches both typos (the id
# doesn't exist) and category mistakes (the id refers to a full Thing,
# not a Mechanic).
#
# Since J204 `mechanics` may be a map, each mechanic with the fields the Thing
# gives it, `{"work": {"dc": 12}}`, and a list of ids under the symbol of an
# operation of lists, `{"-": ["work"]}`: every id of it is checked the same
# way, and each field given must be one the mechanic has, or one the library
# reads of every mechanic. It also says what DefManager placed but must say:
# a field two parts of one Thing give, which the part named last gives.
extends Validator
class_name PartsValidator

# The fields of every mechanic, read when it plugs in, which it need not write.
const EARS: Array[String] = ["priority", "hears", "watches"]

func validate(hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var all_content: Array[Dictionary] = Drive.list_all_content()
	var by_name: Dictionary = things_by_name(all_content)
	var mechanic: Script = Drive.script_by_id("mechanic")
	for raw: Dictionary in all_content:
		var id: String = String(raw.get("id", "")).strip_edges().to_lower()
		if id == "":
			continue
		if _maps_fields(raw.get("parts", [])):
			issues.append("Thing '%s': parts is a list of ids; a mechanic with its fields goes in mechanics" % id)
		for part_id: String in _listed(raw, "parts"):
			if not by_name.has(part_id):
				issues.append("Thing '%s': part '%s' not found" % [id, part_id])
				continue
			var part_raw: Dictionary = by_name[part_id]
			var kind: String = String(part_raw.get("kind", "thing")).strip_edges().to_lower()
			if kind != "part":
				issues.append(
					"Thing '%s': part '%s' has kind='%s' (expected 'part')"
						% [id, part_id, kind])
		for named: String in _listed(raw, "mechanics"):
			var mechanic_id: String = Thing.name_of(named)
			if not by_name.has(mechanic_id):
				issues.append("Thing '%s': mechanic '%s' not found" % [id, named])
			elif mechanic != null and not _is_mechanic(mechanic_id, by_name, mechanic, []):
				issues.append("Thing '%s': mechanic '%s' is no Mechanic" % [id, named])
			else:
				issues.append_array(_fields(hub, id, named, raw.get("mechanics")))
	issues.append_array(Drive.def_warnings())
	return issues

# The ids a field of a Thing names, lowercased: the items of a list; or, of a
# map, its keys and the items of each list under the symbol of an operation of
# lists (J204).
func _listed(raw: Dictionary, field: String) -> Array[String]:
	var out: Array[String] = []
	var listed: Variant = raw.get(field, [])
	var items: Array = []
	if listed is Array:
		items = listed as Array
	elif listed is Dictionary:
		for key: Variant in (listed as Dictionary):
			var value: Variant = (listed as Dictionary)[key]
			if _operates(String(key), value):
				items.append_array(value as Array)
			else:
				items.append(key)
	for one: Variant in items:
		var id: String = String(one).strip_edges().to_lower()
		if id != "" and not out.has(id):
			out.append(id)
	return out

# Whether a writing is a map that gives fields to a mechanic, and not only
# operations of lists, `{"-": ["shelter"]}`, which any list takes.
func _maps_fields(written: Variant) -> bool:
	if not written is Dictionary:
		return false
	for key: Variant in (written as Dictionary):
		if not _operates(String(key), (written as Dictionary)[key]):
			return true
	return false

# Whether a key of a map of mechanics is the symbol of an operation of lists
# over a list, `"-"` over `["work"]`, and not a mechanic.
func _operates(key: String, value: Variant) -> bool:
	var op: ThingOperator = ThingVariant.operator(key)
	return op != null and op.handles_lists() and value is Array

# The fields a Thing gives one of its mechanics, in a map of `mechanics`, each
# one the mechanic has, or one the library reads of every mechanic (J204).
func _fields(hub: ThingHub, id: String, named: String, written: Variant) -> Array[String]:
	var out: Array[String] = []
	if not written is Dictionary:
		return out
	var given: Variant = null
	for key: Variant in (written as Dictionary):
		if String(key).strip_edges().to_lower() == named and not _operates(String(key), (written as Dictionary)[key]):
			given = (written as Dictionary)[key]
	if given == null:
		return out
	if not given is Dictionary:
		out.append("Thing '%s': mechanic '%s' takes a map of its fields" % [id, named])
		return out
	var type: ThingType = hub.resolve_type(named) if hub != null else null
	if type == null:
		return out
	for field: Variant in (given as Dictionary):
		var name: String = String(field)
		if not type.data.has(name) and not EARS.has(name):
			out.append("Thing '%s': mechanic '%s' takes %s, a field it does not have" % [id, named, name])
	return out

# Whether the Thing named `id` is a Mechanic, as the catalog would build
# it: its own script extends Mechanic, or, with none, it is of kind part,
# or what it inherits from is a Mechanic, up to a native.
func _is_mechanic(id: String, by_name: Dictionary, mechanic: Script, seen: Array) -> bool:
	if Drive.is_native(id):
		return extends_script(Drive.script_by_id(id), mechanic)
	if seen.has(id) or not by_name.has(id):
		return false
	var own: Script = Drive.script_by_id(id)
	if own != null:
		return extends_script(own, mechanic)
	var raw: Dictionary = by_name[id]
	if String(raw.get("kind", "")).strip_edges().to_lower() == "part":
		return true
	var parent: String = parent_of(raw)
	return parent != "" and _is_mechanic(parent, by_name, mechanic, seen + [id])
