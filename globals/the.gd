# Game session: UI cache, runtime state, and scene transitions.
# Layer: The -> God -> Drive.
extends Node

var rules: Rules = null
var uis: Dictionary = {}
var session: Dictionary = {}

func _ready() -> void:
	pass

func load_rules() -> void:
	rules = God.rules()

func ui(ui_id: String) -> PackedScene:
	if uis.has(ui_id):
		return uis[ui_id]
	var the_ui: PackedScene = God.ui(ui_id)
	if the_ui:
		uis[ui_id] = the_ui
	return the_ui

func next_scene(scene: PackedScene) -> void:
	if scene == null:
		Log.log(self, "error", "Next scene is null.")
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		Log.log(self, "error", "SceneTree is not available.")
		return
	tree.call_deferred("change_scene_to_packed", scene)

# --- Memento: Save / Load ---

func _snapshot_data(node: Node) -> Dictionary:
	if node.has_method("get") and node.get("data") != null:
		var d: Variant = node.get("data")
		if d is Dictionary:
			return (d as Dictionary).duplicate(true)
	return {}

func snapshot() -> Dictionary:
	var save: Dictionary = {}
	save["session"] = session.duplicate(true)
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
	var saved_session: Variant = save.get("session", null)
	if saved_session is Dictionary:
		session = (saved_session as Dictionary).duplicate(true)
	var entities: Variant = save.get("entities", null)
	if not entities is Array:
		return
	var specs: Array = []
	for entry: Variant in (entities as Array):
		if entry is Dictionary:
			specs.append(entry)
	if not specs.is_empty():
		God.load_types(specs)
