# Game rules parsed from game.json.
extends Resource
class_name Rules

var id: String = ""
var name: String = ""
var version: String = ""
var flow: String = ""

func is_empty() -> bool:
	return id == "" and name == "" and version == "" and flow == ""

func get_flow() -> String:
	return String(flow).strip_edges()

func is_valid() -> bool:
	return not is_empty() and get_flow() != ""
