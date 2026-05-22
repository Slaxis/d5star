# Game rules parsed from game.json.
extends Resource
class_name Rules

var id: String = ""
var name: String = ""
var version: String = ""
var asset: String = ""

func is_empty() -> bool:
	return id == "" and name == "" and version == "" and asset == ""

func get_asset() -> String:
	return String(asset).strip_edges()

func is_valid() -> bool:
	return not is_empty() and get_asset() != ""
