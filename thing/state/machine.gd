# ThingStateMachine: Callable-based state machine for Thing entities.
# States are registered as {enter, exit, update} Callables — no subclasses needed.
extends RefCounted
class_name ThingStateMachine

signal state_changed(from: StringName, to: StringName)

var _current: StringName = &""
var _states: Dictionary = {}  # StringName -> {enter, exit, update: Callable}
var _owner: Node = null

func _init(owner: Node) -> void:
	_owner = owner

func register(state_id: StringName, enter: Callable, exit: Callable, update: Callable = Callable()) -> void:
	_states[state_id] = {
		"enter":  enter,
		"exit":   exit,
		"update": update,
	}

func transition(next_id: StringName) -> void:
	if next_id == _current:
		return
	if not _states.has(next_id):
		return
	var from: StringName = _current
	if _current != &"" and _states.has(_current):
		var exit_fn: Callable = _states[_current].get("exit", Callable())
		if exit_fn.is_valid():
			exit_fn.call()
	_current = next_id
	var enter_fn: Callable = _states[_current].get("enter", Callable())
	if enter_fn.is_valid():
		enter_fn.call()
	state_changed.emit(from, _current)

func update(delta: float) -> void:
	if _current == &"" or not _states.has(_current):
		return
	var update_fn: Callable = _states[_current].get("update", Callable())
	if update_fn.is_valid():
		update_fn.call(delta)

func current() -> StringName:
	return _current

func has_state(state_id: StringName) -> bool:
	return _states.has(state_id)
