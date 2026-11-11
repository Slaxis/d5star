# Bus — typed pub/sub command bus. Same implementation used in three
# scopes:
#
#   - The global `Air` autoload (world bus). A Node adapter wraps
#     this to add `dispatch_deferred` (Node-only sugar).
#   - A channel: a private bus a group of Things shares, such as
#     the Things of one match, so two groups alive at once never
#     hear each other. Whoever makes it tunes each Thing to it,
#     `thing.channel = channel`.
#   - Every Thing's local `mind` (thought bus). Per-Thing RefCounted
#     instance — no scene tree, no _process overhead.
#
# One primitive, three scopes. Subscribers listen to a specific
# `cmd_type` OR connect to the `on_command` signal to receive
# every dispatch.
#
# Semantic mapping in Thing:
#   Thing.think(thought)  → mind.dispatch(thought)      (local)
#   Thing.say(message)    → channel.dispatch(message)   (its group)
#                           or Air.dispatch(message)    (on no channel)
#
# A bus holds its listeners, and a lambda holds what it uses: a
# lambda that uses a Thing, subscribed on that Thing's `mind` or
# channel, keeps both alive for good. Subscribe a method instead
# (`part.hear`), which lets its object go.
extends RefCounted
class_name Bus

signal on_command(cmd: Cmd)

var _listeners: Dictionary = {}  # StringName -> Array[Callable]

func subscribe(cmd_type: StringName, callback: Callable) -> void:
	if not _listeners.has(cmd_type):
		_listeners[cmd_type] = []
	(_listeners[cmd_type] as Array).append(callback)

func unsubscribe(cmd_type: StringName, callback: Callable) -> void:
	if _listeners.has(cmd_type):
		(_listeners[cmd_type] as Array).erase(callback)

func dispatch(cmd: Cmd) -> void:
	if cmd == null or cmd.type == &"":
		return
	on_command.emit(cmd)
	var listeners: Array = _listeners.get(cmd.type, [])
	for fn in listeners:
		if (fn as Callable).is_valid():
			(fn as Callable).call(cmd)
