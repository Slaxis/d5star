# DrawValidator — a draw draws from a family that is there (J205). Every
# `{ "from": "<template>" }` in the data of a Thing of the content, at any
# depth, names a Thing, and the family of that Thing has one to draw. A typo
# in a draw would otherwise draw nothing, and say nothing.
extends Validator
class_name DrawValidator

func validate(hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	for raw: Dictionary in Drive.list_all_content():
		var written: String = String(raw.get("id", "")).strip_edges().to_lower()
		if written == "":
			continue
		for template: String in _templates(raw, [] as Array[String]):
			var name: String = Thing.name_of(template)
			if hub.resolve_type(name) == null and not Drive.is_native(name):
				issues.append("Thing '%s': draws from '%s', which is no Thing" % [written, template])
			elif hub.family(name).is_empty():
				issues.append("Thing '%s': draws from '%s', a family with nothing to draw" % [written, template])
	return issues

# The templates the draws in a value name, at any depth, in the order written.
func _templates(value: Variant, out: Array[String]) -> Array[String]:
	if value is Dictionary:
		var dict: Dictionary = value
		var from: Variant = dict.get(ThingHub.DRAW_FROM, null)
		if from is String:
			out.append(String(from).strip_edges().to_lower())
		for key: Variant in dict:
			_templates(dict[key], out)
	elif value is Array:
		for item: Variant in (value as Array):
			_templates(item, out)
	return out
