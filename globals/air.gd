# Air — the world bus. Autoload Node wrapping a `Bus`, the same primitive as
# the mind of each Thing and the channel of each group of Things. Adds
# `dispatch_deferred`, a Node-only sugar that queues an event until the next
# idle frame.
#
# What a Thing on no channel manifests (`Thing.manifest`) happens here, and
# the mechanics of such a Thing watch here what they watch. World-facing
# systems (log, achievements, HUD, replay) hear it without knowing about the
# Thing. A Thing on a channel is heard only there, and whoever listens to that
# channel relays here what the world needs.
#
# The metaphor is deliberate: minds think privately; a channel is a frequency
# only those tuned to it hear; air carries what is manifested to everyone.
#
# The signal `on_event` is re-emitted from the wrapped Bus, so its readers and
# the ears of an id work as on a plain Bus.
extends Node

## Every event that happens in the air, before any ear (`Bus.on_event`).
signal on_event(e: Event)

## The Bus of the air, for whoever takes a space as a Bus: the mechanics of a
## Thing on no channel watch here.
var bus: Bus = Bus.new()

func _ready() -> void:
	bus.on_event.connect(_relay)

## Hears the events of `id` and of its heirs, by priority (`Bus.subscribe`).
func subscribe(id: StringName, callback: Callable, priority: int = 0) -> void:
	bus.subscribe(id, callback, priority)

func unsubscribe(id: StringName, callback: Callable) -> void:
	bus.unsubscribe(id, callback)

## Makes `e` happen in the air (`Bus.dispatch`).
func dispatch(e: Event) -> void:
	bus.dispatch(e)

## Node-only: makes `e` happen at the next idle frame, for a caller in the
## middle of an emission that wants no re-entrancy.
func dispatch_deferred(e: Event) -> void:
	if e != null and e.thing_id != "":
		call_deferred("dispatch", e)

func _relay(e: Event) -> void:
	on_event.emit(e)
