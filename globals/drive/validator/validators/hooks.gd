# HookValidator — a mechanic is a script that overrides the hooks of the
# library, and only them (J189). For the script of every Thing of the content,
# and each script of the game it extends on the way up to the library, it warns
# of:
#
#   - a method `_on_<name>` that is no hook of the library, in a script whose
#     library has hooks, as a Mechanic's: a typo such as `_on_thougth`, which
#     nobody would ever call;
#   - a method of the library it overrides that is no hook, such as `think`,
#     `manifest` or `attach`, which the library calls and counts on.
#
# A hook is a method of a library script whose name starts with `_on_`. The
# methods are read from the source of each script, the top-level `func` lines;
# a script with no source, as in an exported game, says nothing.
extends Validator
class_name HookValidator

const HOOK := "_on_"
const LIBRARY := "res://addons/d5star/"

var _func: RegEx = RegEx.create_from_string("(?m)^(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)")
# The methods of each script read, by its path.
var _read: Dictionary = {}

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	var done: Dictionary = {}
	for raw: Dictionary in Drive.list_all_content():
		var written: String = String(raw.get("id", "")).strip_edges().to_lower()
		var id: String = Thing.name_of(written)
		if id == "" or Drive.is_native(id) or done.has(id):
			continue
		done[id] = true
		var script: Script = Drive.script_by_id(id)
		if script != null:
			issues.append_array(_check(written, script))
	return issues

# What is wrong with the methods of `script`, the script of the Thing `written`.
func _check(written: String, script: Script) -> Array[String]:
	var own: Array[String] = []
	var library: Dictionary = {}
	var base: String = ""
	var at: Script = script
	while at != null:
		var methods: Array[String] = _methods(at)
		if at.resource_path.begins_with(LIBRARY):
			if base == "":
				base = at.get_global_name()
			for method: String in methods:
				library[method] = true
		else:
			for method: String in methods:
				if not own.has(method):
					own.append(method)
		at = at.get_base_script()
	var issues: Array[String] = []
	if library.is_empty():
		return issues
	var hooked: bool = library.keys().any(func(method: String) -> bool: return method.begins_with(HOOK))
	for method: String in own:
		if method.begins_with(HOOK):
			if hooked and not library.has(method):
				issues.append("Thing '%s': %s is no hook of %s" % [written, method, base])
		elif library.has(method):
			issues.append("Thing '%s': overrides %s of %s, which is no hook" % [written, method, base])
	return issues

# The names of the top-level methods of a script, from its source.
func _methods(script: Script) -> Array[String]:
	var path: String = script.resource_path
	if _read.has(path):
		return _read[path]
	var out: Array[String] = []
	for found: RegExMatch in _func.search_all(script.source_code):
		out.append(found.get_string(1))
	_read[path] = out
	return out
