# Menu — full-screen UI scene. Player makes choices; transitions out
# of the Flow via `go("transition_name")`. Subclasses build their UI
# in their own _ready() and emit go() in response to input.
class_name Menu
extends Control

signal transition_requested(transition_name: String)

var scene_flow: SceneFlow = SceneFlow.new()

func go(transition_name: String) -> void:
	transition_requested.emit(transition_name)

func read(key: String) -> Snapshot:
	return scene_flow.read(key)

func write(key: String, sel: Snapshot) -> void:
	scene_flow.write(key, sel)

# Lifecycle hooks — Flow calls these around scene swaps. Default no-op.
func _on_enter(_session: Dictionary) -> void: pass
func _on_exit(_session: Dictionary) -> void: pass
