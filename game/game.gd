# Game entrypoint: activate the default module, load rules, hand the
# active Flow to a Flow runtime that survives scene swaps.
extends Node2D
class_name Game

var _flow: Flow = null

func _ready() -> void:
	var modules: Array[ModuleInfo] = Drive.list_modules()
	if modules.is_empty():
		_boot_error("No modules found under game/modules/.")
		return
	if not Drive.set_module(modules[0].id):
		_boot_error("Failed to activate module: " + modules[0].id)
		return
	The.load_rules()
	var the_rules: Rules = The.rules
	if the_rules == null or not the_rules.is_valid():
		_boot_error("Invalid rules — check content/system/game.json in module '" + modules[0].id + "'.")
		return
	var flow_id: String = the_rules.get_flow()
	var flow_def: FlowDef = Drive.def("flow") as FlowDef
	if flow_def == null:
		_boot_error("FlowDef not registered — check game/defs/flow.gd.")
		return
	var flow_data: Dictionary = flow_def.get_flow(flow_id)
	if flow_data.is_empty():
		_boot_error("Flow '" + flow_id + "' not found — check content/things/flow/<id>/<id>.json.")
		return
	# Flow lives as a child of the SceneTree root so it survives the
	# change_scene_to_packed calls it issues to swap screens; otherwise
	# Game (which IS the boot scene) would take Flow down with it on
	# the first transition.
	_flow = Flow.new()
	_flow.name = "FlowRuntime"
	get_tree().root.add_child.call_deferred(_flow)
	_flow.start.call_deferred(flow_data)

# R8 — show a visible error screen instead of a blank window on boot failure.
func _boot_error(message: String) -> void:
	Log.log(self, "error", "Boot: " + message)
	var layer: CanvasLayer = CanvasLayer.new()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var label: Label = Label.new()
	label.text = "Scrap Warriors One — boot failed\n\n" + message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	layer.add_child(label)
	add_child(layer)
