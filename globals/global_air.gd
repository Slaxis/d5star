# GlobalAir — world bus autoload. A thin Node adapter wrapping an
# `Air` instance so the SAME bus implementation is shared with each
# Thing's local `thought_air`. Adds `dispatch_deferred` — a Node-
# only sugar that queues a dispatch until the next idle frame.
#
# Every `Thing.say(message)` broadcasts here. World-facing systems
# (log, achievements, HUD, replay) subscribe. Things don't need to
# know about their listeners — the bus decouples them.
#
# Signal `on_command` is re-emitted from the wrapped Air so both
# signal-based and channel-based subscribers work identically to
# the plain Air class.
extends Node

signal on_command(cmd: Cmd)

var _air: Air = Air.new()

func _ready() -> void:
	_air.on_command.connect(func(cmd: Cmd) -> void: on_command.emit(cmd))

func subscribe(cmd_type: StringName, callback: Callable) -> void:
	_air.subscribe(cmd_type, callback)

func unsubscribe(cmd_type: StringName, callback: Callable) -> void:
	_air.unsubscribe(cmd_type, callback)

func dispatch(cmd: Cmd) -> void:
	_air.dispatch(cmd)

func dispatch_raw(payload: Dictionary) -> void:
	_air.dispatch_raw(payload)

# Node-only: schedule dispatch for the next idle frame. Useful when
# the caller is mid-signal-emit and wants to avoid re-entrancy or
# deferred subscriber lookup.
func dispatch_deferred(cmd: Cmd) -> void:
	if cmd != null and cmd.type != &"":
		call_deferred("dispatch", cmd)
