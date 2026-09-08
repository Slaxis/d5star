# World — gameplay scene rooted in 2D world coordinates. Hosts the
# board, the camera, the player's interaction with the simulation.
# Transitions out of the Flow via `go("transition_name")`.
class_name World
extends Node2D

signal transition_requested(transition_name: String)

var scene_flow: SceneFlow = SceneFlow.new()

func go(transition_name: String) -> void:
	transition_requested.emit(transition_name)

func read(key: String) -> Record:
	return scene_flow.read(key)

func write(key: String, sel: Record) -> void:
	scene_flow.write(key, sel)

# Lifecycle hooks — Flow calls these around scene swaps. Default no-op.
func _on_enter(_session: Dictionary) -> void: pass
func _on_exit(_session: Dictionary) -> void: pass
