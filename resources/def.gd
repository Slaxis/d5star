# Def: abstract base for all game definitions.
# A Def knows how to interpret raw JSON into typed, query-ready data.
#
# A Def takes its data in one of two ways:
#   1. Whole: `load_data(raw)` receives the JSON beside its script,
#      `<defs folder>/<def_id>.json`. Used by Defs that work their data once
#      per module, such as the numbers of a game's rules.
#   2. One Thing at a time: only a KindDef holds Things. It receives each
#      Thing of the active modules that names it, `"def": "<def_id>"`,
#      wherever its file sits. A def that no script provides gets a KindDef,
#      inferred by the DefManager, and a script that provides a def of Things
#      extends KindDef.
#
# A Thing that names a Def that is no KindDef goes nowhere: an error, which
# stops the boot.
@abstract
extends Resource
class_name Def

var def_id: String = ""

func load_data(_raw: Dictionary) -> void:
	push_error("Def.load_data() not overridden in " + get_script().resource_path)

func merge_data(raw: Dictionary) -> void:
	load_data(raw)

func _key(value: String) -> String:
	return String(value).strip_edges().to_lower()
