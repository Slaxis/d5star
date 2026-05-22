# Directory map parsed from game.json.
extends Resource
class_name Directories

var items: Dictionary = {}

func get_dir(id: String, default_value: String = "") -> String:
	var key: String = String(id).strip_edges().to_lower()
	if key == "":
		return default_value
	return String(items.get(key, default_value))

func set_dir(id: String, path: String) -> void:
	var key: String = String(id).strip_edges().to_lower()
	if key == "":
		return
	items[key] = String(path).strip_edges()
