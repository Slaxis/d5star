# Bus — typed pub/sub command bus. Same implementation used in two
# scopes:
#
#   - The global `Air` autoload (world bus). A Node adapter wraps
#     this to add `dispatch_deferred` (Node-only sugar).
#   - Every Thing's local `mind` (thought bus). Per-Thing RefCounted
#     instance — no scene tree, no _process overhead.
#
# One primitive, two scopes. Subscribers listen to a specific
# `cmd_type` OR connect to the `on_command` signal to receive
# every dispatch.
#
# Semantic mapping in Thing:
#   Thing.think(thought)  → mind.dispatch(thought)   (local)
#   Thing.say(message)    → Air.dispatch(message)     (global)
extends RefCounted
class_name Bus

signal on_command(cmd: Cmd)

var _channels: Dictionary = {}  # StringName -> Array[Callable]

func subscribe(cmd_type: StringName, callback: Callable) -> void:
	if not _channels.has(cmd_type):
		_channels[cmd_type] = []
	(_channels[cmd_type] as Array).append(callback)

func unsubscribe(cmd_type: StringName, callback: Callable) -> void:
	if _channels.has(cmd_type):
		(_channels[cmd_type] as Array).erase(callback)

func dispatch(cmd: Cmd) -> void:
	if cmd == null or cmd.type == &"":
		return
	on_command.emit(cmd)
	var listeners: Array = _channels.get(cmd.type, [])
	for fn in listeners:
		if (fn as Callable).is_valid():
			(fn as Callable).call(cmd)

# Convenience: build a Cmd from a raw dict (`type` or `cmd` key
# names the command, everything else becomes payload) and dispatch.
func dispatch_raw(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var cmd := Cmd.new()
	cmd.type = StringName(String(payload.get("type", payload.get("cmd", ""))))
	cmd.payload = payload
	dispatch(cmd)
