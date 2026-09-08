# The — the Blackboard. A shared, typed key/value store that flows between
# scenes: screens write Records to it, later screens and systems read them, and
# the Flow gates its own transitions on which keys are present.
# Layer: The -> God -> Drive.
extends Node

var rules: Codex = null
var scenes: Dictionary = {}
var board: Dictionary = {}

func _ready() -> void:
	pass

func load_rules() -> void:
	rules = God.rules.current()

func scene(scene_id: String) -> PackedScene:
	if scenes.has(scene_id):
		return scenes[scene_id]
	var the_scene: PackedScene = God.media.scene(scene_id)
	if the_scene:
		scenes[scene_id] = the_scene
	return the_scene

func next_scene(packed: PackedScene) -> void:
	if packed == null:
		Log.log(self, "error", "Next scene is null.")
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		Log.log(self, "error", "SceneTree is not available.")
		return
	tree.call_deferred("change_scene_to_packed", packed)

# --- Memento: Save / Load ---

func _snapshot_data(node: Node) -> Dictionary:
	if node.has_method("get") and node.get("data") != null:
		var d: Variant = node.get("data")
		if d is Dictionary:
			return (d as Dictionary).duplicate(true)
	return {}

func snapshot() -> Dictionary:
	var save: Dictionary = {}
	save["board"] = board.duplicate(true)
	var entities: Array = []
	var tree: SceneTree = get_tree()
	if tree != null:
		for node: Node in tree.get_nodes_in_group("things"):
			if node == null:
				continue
			var entry: Dictionary = {}
			if node.has_method("get_data"):
				entry["id"]       = String(node.get("thing_id")) if node.get("thing_id") != null else ""
				entry["ancestor"] = String(node.get("ancestor"))  if node.get("ancestor")  != null else ""
				entry["data"]     = _snapshot_data(node)
			if not entry.is_empty():
				entities.append(entry)
	save["entities"] = entities
	return save

func restore(save: Dictionary) -> void:
	if save.is_empty():
		return
	var saved_board: Variant = save.get("board", null)
	if saved_board is Dictionary:
		board = (saved_board as Dictionary).duplicate(true)
	var entities: Variant = save.get("entities", null)
	if not entities is Array:
		return
	var specs: Array = []
	for entry: Variant in (entities as Array):
		if entry is Dictionary:
			specs.append(entry)
	if not specs.is_empty():
		God.things.load_types(specs)
