# Def: abstract base for all game definitions.
# A Def knows how to interpret raw JSON into typed, query-ready data.
#
# Two ingestion modes are supported:
#   1. Single-file legacy mode: `load_data(raw)` receives the whole JSON
#      from `game/defs/<def_id>.json`. Used by Defs whose data is small
#      enough to live in one file (color_palette, terrain, …).
#   2. Per-thing mode: `add_thing(thing)` receives ONE entry parsed
#      from `<module>/things/<def_id>/<thing_id>/<thing_id>.json`. The
#      DefManager calls it once per Thing found across active modules.
#      Defs with many entries (worldgen blueprints) use this so each
#      Thing is an isolated file alongside its assets.
#
# A Def can implement either or both. `add_thing()` defaults to a
# no-op so legacy Defs don't have to opt in.
extends Resource
class_name Def

var def_id: String = ""

func load_data(_raw: Dictionary) -> void:
	push_error("Def.load_data() not overridden in " + get_script().resource_path)

func merge_data(raw: Dictionary) -> void:
	load_data(raw)

# Per-thing ingestion. Override in Defs that consume one-file-per-entry
# Things from `<module>/things/<def_id>/<thing_id>/<thing_id>.json`.
# Default is a no-op for backward compatibility with single-file Defs.
func add_thing(_thing: Dictionary) -> void:
	pass

func _key(value: String) -> String:
	return String(value).strip_edges().to_lower()
