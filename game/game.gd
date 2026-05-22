# Game entrypoint: activate the default module, load rules, open the entry UI.
extends Node2D
class_name Game

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
	var asset_id: String = the_rules.get_asset()
	var ui: PackedScene = The.ui(asset_id)
	if ui == null:
		_boot_error("Entry UI scene not found for id: '" + asset_id + "'.")
		return
	The.next_scene(ui)

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
