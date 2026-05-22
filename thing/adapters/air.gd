# Per-Thing typed command bus for internal thought routing.
extends RefCounted
class_name ThingAir

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

func dispatch_raw(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var cmd := Cmd.new()
	cmd.type = StringName(String(payload.get("type", payload.get("cmd", ""))))
	cmd.payload = payload
	dispatch(cmd)
