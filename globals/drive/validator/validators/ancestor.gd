# AncestorValidator — verifies that every Thing's ancestor resolves to
# either another Thing in the loaded content OR a script: a native Thing
# of a lib, or a Thing's `<id>.gd` (discoverable via `Drive.script_by_id`).
# The ancestor of a Thing whose id says its parent, `<parent>.<name>`
# (J188), is that parent.
#
# Catches typos like `ancestor: "creture"` (missing 'a') that would
# otherwise fail silently the first time the type is materialised.
extends Validator
class_name AncestorValidator

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var all_content: Array[Dictionary] = Drive.list_all_content()
	var known: Dictionary = things_by_name(all_content)
	for raw: Dictionary in all_content:
		var id: String = String(raw.get("id", "")).strip_edges().to_lower()
		var anc: String = parent_of(raw)
		if id == "" or anc == "":
			continue
		if known.has(anc):
			continue
		# Ancestor might also be a script: a native of a lib, or an
		# `<id>.gd` of the content.
		if Drive.script_by_id(anc) != null:
			continue
		issues.append(
			"Thing '%s': ancestor '%s' not found (not a Thing id, not a base script)"
				% [id, anc])
	return issues
