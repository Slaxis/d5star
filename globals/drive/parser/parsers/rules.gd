# Codex parser: maps game.json root attributes to Codex.
extends Parser
class_name RulesParser

func _create_resource() -> Resource:
	return Codex.new()

func _post_process(_resource: Resource, _data: Dictionary) -> void:
	pass
