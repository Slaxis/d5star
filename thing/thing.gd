# Thing node: data-only object with parts and command/thought buses.
extends Node
class_name Thing

var _core: ThingCore

var thing_id: String:
	get: return _core.thing_id
	set(value): _core.thing_id = value

var ancestor: String:
	get: return _core.ancestor
	set(value): _core.ancestor = value

var data: Dictionary:
	get: return _core.data
	set(value): _core.data = value.duplicate(true)

var parts: Array[Node]:
	get: return _core.parts
	set(value): _core.parts = value

var big_thing: Node:
	get: return _core.big_thing
	set(value): _core._set_big_thing(value)

func _on_thought(_cmd: Cmd) -> void:
	pass

func _init() -> void:
	_core = ThingCore.new(self)

func _connect_thought() -> void:
	_core.connect_thought(_on_thought)

func _get_thought_air() -> ThingAir:
	return _core.thought_air

func _set_big_thing(big: Node) -> void:
	_core._set_big_thing(big)
	_connect_thought()

func _apply_data(new_id: String, new_ancestor: String, new_data: Dictionary) -> void:
	_core._apply_data(new_id, new_ancestor, new_data)

func _ready() -> void:
	_connect_thought()

func clone() -> Node:
	return _core.clone_owner()

func add_part(part: Node) -> void:
	_core._add_part(part)

func get_data(key: String, default_value: Variant = null) -> Variant:
	return _core.data.get(key, default_value)

func set_data(key: String, value: Variant) -> void:
	_core.data[key] = value

func attr(key: String, default_value: Variant = null) -> Variant:
	return _core.attr(key, default_value)

func text(key: String, default_value: String = "") -> String:
	if key == "":
		return default_value
	var value: Variant = _core.data.get(key, default_value)
	return I18n.text(value, default_value)

func think(cmd: Cmd) -> void:
	_core.dispatch_think(cmd)

func command(cmd: Cmd) -> void:
	Air.dispatch(cmd)
