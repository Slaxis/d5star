# Flow runtime — drives the player through a sequence of Scenes.
# Loads the JSON declaration (a FlowDef Thing), instantiates each
# step's scene_file via God.scene(), validates that the required
# Selections exist in The.session before entering, and routes
# `transition_requested` signals against the step's transitions map.
#
# Reserved transition targets:
#  "$exit" — end the flow (emits `flow_finished`); the boot layer
#            decides whether to quit the app or return to a parent
#            scope.
#
# Flow lives as a child of get_tree().root so it survives the
# change_scene_to_packed calls it issues to swap screens.
class_name Flow
extends Node

const EXIT_TARGET: String = "$exit"

signal flow_finished

var _flow_data: Dictionary = {}
var _steps_by_id: Dictionary = {}    # step_id -> step Dictionary
var _current_step: Dictionary = {}
var _current_scene_instance: Node = null
var _transitioning: bool = false

func start(flow_data: Dictionary) -> void:
	_flow_data = flow_data
	_steps_by_id.clear()
	var steps: Variant = _flow_data.get("steps", [])
	if steps is Array:
		for step: Variant in (steps as Array):
			if step is Dictionary:
				var sid: String = String((step as Dictionary).get("id", ""))
				if sid != "":
					_steps_by_id[sid] = step
	var entry: String = String(_flow_data.get("entry", ""))
	if entry == "":
		Log.log(self, "error", "Flow.start: flow has no `entry` step.")
		return
	_goto(entry)

func _goto(step_id: String) -> void:
	if not _steps_by_id.has(step_id):
		Log.log(self, "error", "Flow: unknown step '%s'" % step_id)
		return
	var step: Dictionary = _steps_by_id[step_id]
	if not _validate_consumes(step):
		return
	_transitioning = true

	if _current_scene_instance != null and is_instance_valid(_current_scene_instance):
		if _current_scene_instance.has_method("_on_exit"):
			_current_scene_instance.call("_on_exit", The.session)
		if _current_scene_instance.has_signal("transition_requested"):
			var sig: Signal = _current_scene_instance.transition_requested
			if sig.is_connected(_on_transition_requested):
				sig.disconnect(_on_transition_requested)

	var scene_file: String = String(step.get("scene_file", ""))
	var packed: PackedScene = God.media.scene(scene_file)
	if packed == null:
		Log.log(self, "error", "Flow: scene_file '%s' not found for step '%s'." % [scene_file, step_id])
		_transitioning = false
		return

	_current_step = step
	var tree: SceneTree = get_tree()
	tree.change_scene_to_packed(packed)
	# Wait for the swap to take effect (change_scene_to_packed is
	# deferred internally) and for the new scene's _ready to run.
	await tree.process_frame
	await tree.process_frame

	_current_scene_instance = tree.current_scene
	if _current_scene_instance == null:
		Log.log(self, "error", "Flow: change_scene_to_packed produced null current_scene for step '%s'." % step_id)
		_transitioning = false
		return

	# Inject the brain metadata if the new instance is a Scene adapter.
	if "scene_flow" in _current_scene_instance:
		_current_scene_instance.scene_flow.flow_step = step
		_current_scene_instance.scene_flow.flow_id = step_id

	if _current_scene_instance.has_signal("transition_requested"):
		_current_scene_instance.transition_requested.connect(_on_transition_requested)

	if _current_scene_instance.has_method("_on_enter"):
		_current_scene_instance.call("_on_enter", The.session)

	_transitioning = false

func _validate_consumes(step: Dictionary) -> bool:
	var needs: Variant = step.get("consumes", [])
	if not needs is Array:
		return true
	for key: Variant in (needs as Array):
		var key_str: String = String(key)
		if not The.session.has(key_str):
			Log.log(self, "error",
				"Flow: step '%s' requires Selection '%s' which is not in session."
				% [step.get("id", "?"), key_str])
			return false
	return true

func _on_transition_requested(transition_name: String) -> void:
	if _transitioning:
		return
	var trans: Variant = _current_step.get("transitions", {})
	if not trans is Dictionary:
		Log.log(self, "warning",
			"Flow: step '%s' has no transitions table." % _current_step.get("id", "?"))
		return
	var target: String = String((trans as Dictionary).get(transition_name, ""))
	if target == "":
		Log.log(self, "warning",
			"Flow: step '%s' has no transition '%s'."
			% [_current_step.get("id", "?"), transition_name])
		return
	if target == EXIT_TARGET:
		flow_finished.emit()
		return
	_goto(target)
