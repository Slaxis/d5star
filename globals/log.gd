# Lightweight logger with levels and injectable sinks.
extends Node

enum Level { DEBUG = 0, INFO = 1, WARNING = 2, ERROR = 3 }

var min_level: Level = Level.INFO
var _sinks: Array[Callable] = []

func add_sink(fn: Callable) -> void:
	if fn.is_valid():
		_sinks.append(fn)

func remove_sink(fn: Callable) -> void:
	_sinks.erase(fn)

func _level_from_string(msg_type: String) -> Level:
	match msg_type.strip_edges().to_lower():
		"debug":
			return Level.DEBUG
		"warning", "warn":
			return Level.WARNING
		"error":
			return Level.ERROR
		_:
			return Level.INFO

func _level_tag(level: Level) -> String:
	match level:
		Level.DEBUG:   return "DEBUG"
		Level.WARNING: return "WARNING"
		Level.ERROR:   return "ERROR"
		_:             return "INFO"

func _extract_class_name(logged: Object) -> String:
	if logged == null:
		return ""
	var script: Script = logged.get_script()
	if script:
		var global_name: String = String(script.get_global_name())
		if global_name != "":
			return global_name
	return logged.get_class()

func log(logged: Object, msg_type: String, message: String) -> void:
	var level: Level = _level_from_string(msg_type)
	if level < min_level:
		return
	var context: String = _extract_class_name(logged)
	var prefix: String = "[" + _level_tag(level) + "]"
	if context != "":
		prefix += "[" + context + "]"
	var line: String = prefix + " " + message
	for sink: Callable in _sinks:
		if sink.is_valid():
			sink.call(level, line)
	if _sinks.is_empty():
		match level:
			Level.ERROR:
				push_error(line)
			Level.WARNING:
				push_warning(line)
			_:
				print(line)
