# PartsValidator — verifies that every entry in a Thing's `parts` field
# resolves to an existing Thing with `kind == "part"`, and every entry of
# its `mechanics` (J188), by name or by whole id, to a Thing that is a
# Mechanic, as the catalog would build it. Catches both typos (the id
# doesn't exist) and category mistakes (the id refers to a full Thing,
# not a Mechanic).
extends Validator
class_name PartsValidator

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var all_content: Array[Dictionary] = Drive.list_all_content()
	var by_name: Dictionary = things_by_name(all_content)
	var mechanic: Script = Drive.script_by_id("mechanic")
	for raw: Dictionary in all_content:
		var id: String = String(raw.get("id", "")).strip_edges().to_lower()
		if id == "":
			continue
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
	return issues

# The ids a field of a Thing lists, lowercased.
func _listed(raw: Dictionary, field: String) -> Array[String]:
	var out: Array[String] = []
	var listed: Variant = raw.get(field, [])
	if listed is Array:
		for one: Variant in (listed as Array):
			var id: String = String(one).strip_edges().to_lower()
			if id != "":
				out.append(id)
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
