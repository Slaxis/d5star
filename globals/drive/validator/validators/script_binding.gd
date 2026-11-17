# ScriptBindingValidator — the script a Thing is born from, the
# `<id>.gd` of the content of the active modules, extends the base of
# its kind.
#
# For every Thing (or Mechanic) type declared in content, if its
# module brings a script with the same name (`Drive.script_by_id`),
# verify that it extends the appropriate base: `Thing` for kind
# "thing", `Mechanic` for kind "part", and for a Thing whose id says
# its parent, `<parent>.<name>` (J188), the native at the root of its
# chain. A mismatch would only show when the catalog builds the Thing —
# better to catch at boot.
#
# What this DOES NOT check: orphan scripts (a `foo.gd` in the content
# with no Thing of that id). Defer until a concrete case makes it
# worth the plumbing.
extends Validator
class_name ScriptBindingValidator

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	if Drive.script_by_id("thing") == null and Drive.script_by_id("mechanic") == null:
		return issues   # engine bases missing — Loader/ancestor validators cover that
	var all_content: Array[Dictionary] = Drive.list_all_content()
	var by_name: Dictionary = things_by_name(all_content)
	for raw: Dictionary in all_content:
		var written: String = String(raw.get("id", "")).strip_edges().to_lower()
		var id: String = Thing.name_of(written)
		if id == "" or (raw.size() < 2 and not written.contains(Thing.ID_DOT)):
			continue
		if is_patch(raw) and not is_same(by_name.get(id, raw), raw):
			continue   # a patch is checked by the Thing it changes (Mesclar, J188)
		# Skip the natives — they're the targets, not auto-binders.
		if Drive.is_native(id):
			continue
		var script: Script = Drive.script_by_id(id)
		if script == null:
			continue   # no matching script → generic base takes over, fine
		var target: Script = Drive.script_by_id(_root(raw, by_name, []))
		if target == null:
			continue
		if not extends_script(script, target):
			issues.append(
				"Thing '%s': auto-bind script found but doesn't extend %s"
					% [written, target.get_global_name()])
	return issues

# The native whose script a Thing's own must extend: for a Thing whose id
# says its parent, the native its parents go up to; for a Thing of the
# format of before, or the one such a chain reaches, the base of its kind.
func _root(raw: Dictionary, by_name: Dictionary, seen: Array) -> String:
	var written: String = String(raw.get("id", "")).strip_edges().to_lower()
	var id: String = Thing.name_of(written)
	if not written.contains(Thing.ID_DOT) or seen.has(id):
		var kind: String = String(raw.get("kind", "thing")).strip_edges().to_lower()
		return "mechanic" if kind == "part" else "thing"
	var parent: String = Thing.parent_of(written)
	if Drive.is_native(parent):
		return parent
	return _root(by_name.get(parent, {}), by_name, seen + [id])
