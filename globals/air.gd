# Air — the world bus. Autoload Node wrapping a `Bus` instance so
# the SAME pub/sub primitive is shared with each Thing's local
# `mind`. Adds `dispatch_deferred` — a Node-only sugar that queues
# a dispatch until the next idle frame.
#
# Every `Thing.say(message)` broadcasts here. World-facing systems
# (log, achievements, HUD, replay) subscribe. Things don't need to
# know about their listeners — the bus decouples them.
#
# The metaphor is deliberate: minds think privately; air carries
# what is said. Everything spoken travels through Air.
#
# Signal `on_command` is re-emitted from the wrapped Bus so both
# signal-based and channel-based subscribers work identically to
# the plain Bus class.
extends Node

signal on_command(cmd: Cmd)

var _bus: Bus = Bus.new()

func _ready() -> void:
	_bus.on_command.connect(func(cmd: Cmd) -> void: on_command.emit(cmd))

func subscribe(cmd_type: StringName, callback: Callable) -> void:
	_bus.subscribe(cmd_type, callback)

func unsubscribe(cmd_type: StringName, callback: Callable) -> void:
	_bus.unsubscribe(cmd_type, callback)

func dispatch(cmd: Cmd) -> void:
	_bus.dispatch(cmd)

func dispatch_raw(payload: Dictionary) -> void:
	_bus.dispatch_raw(payload)

# Node-only: schedule dispatch for the next idle frame. Useful when
# the caller is mid-signal-emit and wants to avoid re-entrancy or
# deferred subscriber lookup.
func dispatch_deferred(cmd: Cmd) -> void:
	if cmd != null and cmd.type != &"":
		call_deferred("dispatch", cmd)
