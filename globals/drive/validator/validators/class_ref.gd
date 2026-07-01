# ClassRefValidator — verifies that every `class` field references
# a Godot class_name that's registered in the project. Walks each
# top-level JSON + one level of nesting into array-of-dicts (to
# cover def-shaped payloads like `map_gens: [{class: "..."}]` or
# worldgen `steps: [{class: "..."}]`).
#
# Catches typos like `"class": "GanabaraMapGen"` that would fail
# silently at runtime with a "class not found" warning.
extends Validator
class_name ClassRefValidator

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var all_content: Array[Dictionary] = Drive.list_all_content()
	for raw: Dictionary in all_content:
		var owner_id: String = String(raw.get("id", "")).strip_edges().to_lower()
		var owner_label: String = owner_id if owner_id != "" else "<no-id>"
		_check_class_in(raw, owner_label, "", issues)
		for key: Variant in raw.keys():
			var val: Variant = raw[key]
			if not val is Array:
				continue
			for i: int in range((val as Array).size()):
				var entry: Variant = (val as Array)[i]
				if entry is Dictionary:
					_check_class_in(entry as Dictionary, owner_label,
						"%s[%d]" % [String(key), i], issues)
	return issues

func _check_class_in(d: Dictionary, owner_label: String, path: String, issues: Array[String]) -> void:
	if not d.has("class"):
		return
	var class_val: String = String(d.get("class", "")).strip_edges()
	if class_val == "":
		return
	if Drive.script(class_val) != null:
		return
	var location: String = owner_label if path == "" else "%s.%s" % [owner_label, path]
	issues.append("'%s': class '%s' not found in Godot class registry" % [location, class_val])
