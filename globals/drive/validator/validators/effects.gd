# EffectValidator — an effect changes fields that exist (J189). For every
# Effect of the content, a Thing whose chain goes up to the native `effect`,
# and every event of the content with an effect written inline, it warns of a
# field in `mods` that no Thing of the content has, and of a mechanic named in
# `mods` that is no Thing, or has no such field. A typo in `mods` would
# otherwise change nothing, and say nothing.
extends Validator
class_name EffectValidator

const RESERVED: Array[String] = ["id", "def", "ancestor", "parts", "mechanics", "kind", "abstract"]

func validate(hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var all_content: Array[Dictionary] = Drive.list_all_content()
	var fields: Dictionary = {}
	for raw: Dictionary in all_content:
		for key: Variant in raw:
			if not RESERVED.has(String(key)):
				fields[String(key)] = true
	for raw: Dictionary in all_content:
		var written: String = String(raw.get("id", "")).strip_edges().to_lower()
		if written == "":
			continue
		var root: Array[StringName] = hub.lineage(written)
		if root.is_empty():
			continue
		var mods: Variant = null
		if root.back() == &"effect":
			mods = raw.get("mods")
		elif root.back() == StringName(Event.NATIVE) and raw.get("effect") is Dictionary:
			mods = (raw["effect"] as Dictionary).get("mods")
		if mods is Dictionary:
			issues.append_array(_check(written, mods as Dictionary, fields, hub))
	return issues

func _check(written: String, mods: Dictionary, fields: Dictionary, hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	for key: Variant in mods:
		var name: String = String(key)
		if not mods[key] is Dictionary:
			if not fields.has(name):
				issues.append("Thing '%s': mods %s, a field no Thing has" % [written, name])
			continue
		var mechanic: ThingType = hub.resolve_type(Thing.name_of(name))
		if mechanic == null:
			issues.append("Thing '%s': mods %s, which is no Thing" % [written, name])
			continue
		for field: Variant in (mods[key] as Dictionary):
			if not mechanic.data.has(String(field)):
				issues.append("Thing '%s': mods %s of %s, a field it does not have" % [written, String(field), name])
	return issues
