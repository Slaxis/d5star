# RefsValidator: every id that a module's Things and Defs name points to a Thing
# of the def its field names, as the modules declare their fields in the Things
# of the def `refs` (see Refs). It reads the declarations and says what they
# name that does not exist, then asks every Def what it finds wrong in itself:
# a KindDef in its Things, a Def of data, such as a game's rules, in its data.
#
# Catches a typo like `"element": "scrapp"` in a mod, which the game would
# otherwise find by a crash, or never.
extends Validator
class_name RefsValidator

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var declared: Dictionary = {}    # def id -> the fields it declares that name a def of Things
	var refs: KindDef = Drive.def(Refs.DEF) as KindDef
	if refs != null:
		for def_id: String in refs.ids():
			var fields: Variant = refs.get_thing(def_id).get("fields", {})
			if not fields is Dictionary:
				issues.append("refs '%s': its fields are no dictionary" % def_id)
				continue
			if Drive.def(def_id) == null:
				issues.append("refs '%s': no def has that id" % def_id)
				continue
			var good: Dictionary = {}
			for path: String in fields:
				var named: Dictionary = Refs.target(fields[path])
				if named.is_empty():
					issues.append("refs '%s': %s names no def" % [def_id, path])
				elif named["def"] != Refs.CLASS and not Drive.def(named["def"]) is KindDef:
					issues.append("refs '%s': %s names the def '%s', which holds no Things" % [
						def_id, path, named["def"]])
				else:
					good[path] = fields[path]
			declared[def_id] = good
	for def_id: String in Drive.defs():
		var def: Def = Drive.def(def_id)
		if def != null:
			issues.append_array(def.issues(declared.get(def_id, {})))
	return issues
