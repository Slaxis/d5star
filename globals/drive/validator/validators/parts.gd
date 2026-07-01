# PartsValidator — verifies that every entry in a Thing's `parts`
# field resolves to an existing Thing with `kind == "part"`. Catches
# both typos (part id doesn't exist) and category mistakes (part id
# refers to a full Thing, not a ThingPart).
extends Validator
class_name PartsValidator

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var all_content: Array[Dictionary] = Drive.list_all_content()
	var by_id: Dictionary = _index_by_id(all_content)
	for raw: Dictionary in all_content:
		var parts_v: Variant = raw.get("parts", [])
		if not parts_v is Array or (parts_v as Array).is_empty():
			continue
		var id: String = String(raw.get("id", "")).strip_edges().to_lower()
		if id == "":
			continue
		for part_v: Variant in (parts_v as Array):
			var part_id: String = String(part_v).strip_edges().to_lower()
			if part_id == "":
				continue
			if not by_id.has(part_id):
				issues.append("Thing '%s': part '%s' not found" % [id, part_id])
				continue
			var part_raw: Dictionary = by_id[part_id]
			var kind: String = String(part_raw.get("kind", "thing")).strip_edges().to_lower()
			if kind != "part":
				issues.append(
					"Thing '%s': part '%s' has kind='%s' (expected 'part')"
						% [id, part_id, kind])
	return issues

func _index_by_id(all_content: Array[Dictionary]) -> Dictionary:
	var by_id: Dictionary = {}
	for raw: Dictionary in all_content:
		var id: String = String(raw.get("id", "")).strip_edges().to_lower()
		if id == "" or raw.size() < 2:
			continue
		by_id[id] = raw
	return by_id
