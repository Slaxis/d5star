# ScriptBindingValidator — the script a Thing is born from, the
# `<id>.gd` of the content of the active modules, extends the base of
# its kind.
#
# For every Thing (or ThingPart) type declared in content, if its
# module brings a script with the same id (`Drive.script_by_id`),
# verify that it extends the appropriate base (`Thing` for kind
# "thing", `ThingPart` for kind "part"). A mismatch would only show
# when the catalog builds the Thing — better to catch at boot.
#
# What this DOES NOT check: orphan scripts (a `foo.gd` in the content
# with no Thing of that id). Defer until a concrete case makes it
# worth the plumbing.
extends Validator
class_name ScriptBindingValidator

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var thing_base: Script = Drive.script_by_id("thing")
	var part_base: Script = Drive.script_by_id("thing_part")
	if thing_base == null and part_base == null:
		return issues   # engine bases missing — Loader/ancestor validators cover that
	var all_content: Array[Dictionary] = Drive.list_all_content()
	for raw: Dictionary in all_content:
		var id: String = String(raw.get("id", "")).strip_edges().to_lower()
		if id == "" or raw.size() < 2:
			continue
		var kind: String = String(raw.get("kind", "thing")).strip_edges().to_lower()
		if kind != "part":
			kind = "thing"
		# Skip base ids — they're the targets, not auto-binders.
		if id == "thing" or id == "thing_part":
			continue
		var script: Script = Drive.script_by_id(id)
		if script == null:
			continue   # no matching script → generic base takes over, fine
		var target: Script = part_base if kind == "part" else thing_base
		if target == null:
			continue
		if not _extends_from(script, target):
			var expected: String = "ThingPart" if kind == "part" else "Thing"
			issues.append(
				"Thing '%s': auto-bind script found but doesn't extend %s"
					% [id, expected])
	return issues

# Walks the base_script chain until it hits `target`, `null`, or a
# self-loop. Returns true iff `target` is reached.
func _extends_from(script: Script, target: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == target:
			return true
		var next: Script = current.get_base_script()
		if next == current:
			return false
		current = next
	return false
