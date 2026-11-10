# FlowDef — the registry of the Flows of the active modules. Each Thing
# under `<module>/content/things/flow/` is one Flow declaration, found by
# its id through `get_flow(id)`. The library registers it by itself, as the
# Def `flow`, so a game only writes its flows.
#
# A Flow declaration is a Dictionary with `id`, `entry` and `steps`
# (each step carries `scene_class`, `scene_file`, optional `consumes`
# / `produces`, and a `transitions` map). `Game` hands the flow the rules
# name to the Flow runtime, `scene/flow.gd`, through `Flow.start(data)`.
#
# Discovery: DefManager hands every Thing it finds under `things/flow/`
# in each active module to `add_thing()`, once per entry.
extends Def
class_name FlowDef

var _by_id: Dictionary = {}    # id -> raw flow Dictionary

func load_data(_raw: Dictionary) -> void:
	pass

func add_thing(thing: Dictionary) -> void:
	var id: String = String(thing.get("id", ""))
	if id == "":
		return
	_by_id[id] = thing

func get_flow(id: String) -> Dictionary:
	return _by_id.get(id, {})

func all() -> Array:
	return _by_id.values()

func ids() -> Array:
	return _by_id.keys()
