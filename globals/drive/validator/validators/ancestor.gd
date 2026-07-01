# AncestorValidator — verifies that every Thing's `ancestor` field
# resolves to either another Thing id in the loaded content OR a
# Thing base script (discoverable via `Drive.script_by_id`).
#
# Catches typos like `ancestor: "creture"` (missing 'a') that would
# otherwise fail silently the first time the type is materialised.
extends Validator
class_name AncestorValidator

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var all_content: Array[Dictionary] = Drive.list_all_content()
	var known_ids: Dictionary = _collect_thing_ids(all_content)
	for raw: Dictionary in all_content:
		var id: String = String(raw.get("id", "")).strip_edges().to_lower()
		var anc: String = String(raw.get("ancestor", "")).strip_edges().to_lower()
		if id == "" or anc == "":
			continue
		if known_ids.has(anc):
			continue
		# Ancestor might also be a Thing base script (asset-registered).
		if Drive.script_by_id(anc, Drive.things_path()) != null:
			continue
		issues.append(
			"Thing '%s': ancestor '%s' not found (not a Thing id, not a base script)"
				% [id, anc])
	return issues

func _collect_thing_ids(all_content: Array[Dictionary]) -> Dictionary:
	var ids: Dictionary = {}
	for raw: Dictionary in all_content:
		var id: String = String(raw.get("id", "")).strip_edges().to_lower()
		# Match ThingCatalog._is_thing_payload: needs id + more fields.
		if id == "" or raw.size() < 2:
			continue
		ids[id] = true
	return ids
