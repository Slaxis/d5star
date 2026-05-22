# Rules parser: maps game.json root attributes to Rules.
extends Parser
class_name RulesParser

func _create_resource() -> Resource:
	return Rules.new()

func _post_process(_resource: Resource, _data: Dictionary) -> void:
	pass
