# HookValidator — a mechanic is a script that overrides the hooks of the
# library, and only them (J189). For the script of every Thing of the content,
# and each script of the game it extends on the way up to the library, it warns
# of:
#
#   - a method `_on_<name>` that is no hook of the library, in a script whose
#     library has hooks, as a Mechanic's: a typo such as `_on_thougth`, which
#     nobody would ever call;
#   - a method of the library it overrides that is no hook, such as `think`,
#     `manifest` or `attach`, which the library calls and counts on;
#   - under a library script that names its hooks, a public method that is none
#     of them: a typo such as `scroe` for a card's `score`, which nobody would
#     ever call either. A helper of such a script starts with `_`.
#
# The library is D5Star and the script of every native a game registers in its
# `d5star.json`, as C4RD5's `card`: so a card that overrides `cost`, a tool of
# its native, is named too. A hook is a method of the library whose name starts
# with `_on_`, or one a library script names in its constant `HOOKS`, as the
# card names `can`, `resolve`, `score` and `targets`. The methods are read from
# the source of each script, the top-level `func` lines; a script with no
# source, as in an exported game, says nothing.
extends Validator
class_name HookValidator

const HOOK := "_on_"
const LIBRARY := "res://addons/d5star/"
# The constant in which a library script names the hooks that do not start
# with `_on_`.
const NAMED := "HOOKS"

var _func: RegEx = RegEx.create_from_string("(?m)^(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)")
# The methods of each script read, by its path.
var _read: Dictionary = {}
# The paths of the scripts of the natives, which count as library.
var _natives: Dictionary = {}

func validate(_hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	_natives.clear()
	for native: String in Drive.natives():
		var born: Script = Drive.script_by_id(native)
		if born != null:
			_natives[born.resource_path] = true
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
	var named: Array[String] = []
	var base: String = ""
	var at: Script = script
	while at != null:
		var methods: Array[String] = _methods(at)
		if _is_library(at):
			if base == "":
				base = at.get_global_name()
			for method: String in methods:
				library[method] = true
			var given: Variant = at.get_script_constant_map().get(NAMED)
			if given is Array:
				for method: Variant in given:
					if not named.has(String(method)):
						named.append(String(method))
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
		elif named.has(method):
			continue
		elif library.has(method):
			issues.append("Thing '%s': overrides %s of %s, which is no hook" % [written, method, base])
		elif not named.is_empty() and not method.begins_with("_"):
			issues.append("Thing '%s': %s is no hook of %s, whose hooks are %s; a helper starts with _"
				% [written, method, base, ", ".join(named)])
	return issues

# Whether `script` is the library's: D5Star's, or a native's that a game registers.
func _is_library(script: Script) -> bool:
	return script.resource_path.begins_with(LIBRARY) or _natives.has(script.resource_path)

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
