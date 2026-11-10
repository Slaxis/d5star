# Def: abstract base for all game definitions.
# A Def knows how to interpret raw JSON into typed, query-ready data.
#
# Two ingestion modes are supported:
#   1. Single-file mode: `load_data(raw)` receives the whole JSON beside its
#      script, `<defs folder>/<def_id>.json`. Used by Defs that work their
#      data once per module, such as the numbers of a game's rules.
#   2. Per-thing mode: `add_thing(thing)` receives ONE Thing of the active
#      modules that names this Def, `"def": "<def_id>"`, wherever its file
#      sits, with its `id` and without the keys that place it. The
#      DefManager calls it once per Thing, in the order read. A def that no
#      script provides gets a KindDef, inferred by the DefManager.
#
# A Def can implement either or both. `add_thing()` defaults to a no-op so a
# single-file Def doesn't have to opt in.
extends Resource
class_name Def

var def_id: String = ""

func load_data(_raw: Dictionary) -> void:
	push_error("Def.load_data() not overridden in " + get_script().resource_path)

func merge_data(raw: Dictionary) -> void:
	load_data(raw)

# Per-thing ingestion: one Thing that names this Def. Override it in a Def
# that holds Things; the default is a no-op, for single-file Defs.
func add_thing(_thing: Dictionary) -> void:
	pass

func _key(value: String) -> String:
	return String(value).strip_edges().to_lower()
