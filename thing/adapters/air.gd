# Per-Thing typed command bus for internal thought routing.
# CLAUDE: ThingAir is redundant with Air. But how can we solve both having the same interface?
# I think the best solution is to have Air as a Node
# then the Singleton becomes GlobalAir, with an attribute "air", which is an Air instance.
# and then ThingAir can be dropped, and Things can just use Air directly. This way we avoid the redundancy and keep a clean architecture.
# GlobalAir has to be an adapter for Air, so we have to maintenance its interface
# But the way it is we have to synchronize both Air and ThingAir, which is error prone.
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
