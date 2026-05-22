# Shared Thing state: data container and behavior helpers for all Thing node types.
extends RefCounted
class_name ThingCore

var owner: Node = null
var thing_id: String = ""
var ancestor: String = ""
var data: Dictionary = {}
var parts: Array[Node] = []
var big_thing: Node = null
var thought_air: ThingAir = ThingAir.new()

static func format_attr(value: Variant) -> Variant:
	if value is String:
		return String(value).strip_edges().to_lower()
	return value

func _init(new_owner: Node) -> void:
	owner = new_owner

func _copy_data() -> Dictionary:
	return data.duplicate(true)

func _apply_data(new_id: String, new_ancestor: String, new_data: Dictionary) -> void:
	thing_id = new_id
	ancestor = new_ancestor
	data = new_data.duplicate(true)

func _set_big_thing(big: Node) -> void:
	big_thing = big
	if big != null and big.has_method("_get_thought_air"):
		thought_air = big.call("_get_thought_air")
	else:
		thought_air = ThingAir.new()

func _add_part(part: Node) -> void:
	if part == null:
		return
	parts.append(part)
	if owner:
		owner.add_child(part)
	if part.has_method("_set_big_thing"):
		part.call("_set_big_thing", owner)

func attr(key: String, default_value: Variant = null) -> Variant:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return format_attr(value)

func clone_owner() -> Node:
	if owner == null:
		return null
	var script: Script = owner.get_script()
	if script == null:
		return null
	var cloned: Node = script.new()
	if cloned == null:
		return null
	if cloned.has_method("_apply_data"):
		cloned.call("_apply_data", thing_id, ancestor, _copy_data())
	return cloned

func connect_thought(callback: Callable) -> void:
	if thought_air == null:
		thought_air = ThingAir.new()
	if callback.is_valid() and not thought_air.on_command.is_connected(callback):
		thought_air.on_command.connect(callback)

func propagate_thought(cmd: Cmd) -> void:
	for part in parts:
		if part != null and part.has_method("think"):
			part.call("think", cmd)

func dispatch_think(cmd: Cmd) -> void:
	if thought_air != null:
		thought_air.dispatch(cmd)
	propagate_thought(cmd)
