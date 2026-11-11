# Air — the world bus. Autoload Node wrapping a `Bus` instance so
# the SAME pub/sub primitive is shared with each Thing's local
# `mind` and with the channel of each group of Things. Adds
# `dispatch_deferred` — a Node-only sugar that queues a dispatch
# until the next idle frame.
#
# What a Thing on no channel says (`Thing.say`) broadcasts here.
# World-facing systems (log, achievements, HUD, replay) subscribe.
# Things don't need to know about their listeners — the bus
# decouples them. A Thing on a channel is heard only there, and
# whoever listens to that channel relays here what the world needs.
#
# The metaphor is deliberate: minds think privately; a channel is
# a frequency only those tuned to it hear; air carries what is
# announced to everyone.
#
# Signal `on_command` is re-emitted from the wrapped Bus so both
# subscribers of the signal and subscribers of a type work
# identically to the plain Bus class.
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

# Node-only: schedule dispatch for the next idle frame. Useful when
# the caller is mid-signal-emit and wants to avoid re-entrancy or
# deferred subscriber lookup.
func dispatch_deferred(cmd: Cmd) -> void:
	if cmd != null and cmd.type != &"":
		call_deferred("dispatch", cmd)
