# ViewHost — where the views of a screen stand (0.17.0). A screen is a Thing whose mechanics
# are its views (View). The host tunes the screen to a channel of its own, so its views hear
# the facts of the screen and never those of a match; lays the slots the screen's data names;
# and builds each view in its slot, in the order the screen holds them.
#
#   {
#     "id": "thing.hud",
#     "slots": {
#       "top":   { "anchors": [0, 0, 1, 0], "offsets": [0, 0, 0, 36], "box": "row" },
#       "left":  { "anchors": [0, 0, 0, 1], "offsets": [0, 40, 280, -124] },
#       "float": { "anchors": [0, 0, 1, 1], "offsets": [0, 0, 0, 0], "box": "free" }
#     },
#     "mechanics": ["view.turn_view"]
#   }
#
# A slot is a box at its `anchors` and `offsets` (left, top, right, bottom): a column of
# views by default, a row with `"box": "row"`, and with `"box": "free"` a plain Control in
# which a view places itself, as a window does. Where no Control of a view is, the pointer
# passes through to what stands under the host, the board of a World. A view whose slot the
# screen does not lay is left out, and said.
#
# The host builds and lets go of Controls only: what a view shows and what it asks for are
# the game's, through the facts of the screen's channel. A game dresses `base`, the Control of
# the whole screen, with its Theme.
extends CanvasLayer
class_name ViewHost

## The ways a slot stacks its views.
const ROW: String = "row"
const COLUMN: String = "column"
const FREE: String = "free"

# --- Data ---

## The Thing the screen is; null before `mount`.
var screen: Thing = null
## The space of the screen, which its Things share, and nothing else.
var channel: Bus = null
## The Control the slots stand in, the whole screen.
var base: Control = null

var _slots: Dictionary = {}    # slot name -> its Control

func _init() -> void:
	base = Control.new()
	base.name = "Base"
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

# --- Tools ---

## Mounts `p_screen` on `p_channel`, or on a new channel when none is given: tunes the screen
## to it, lays the screen's slots and builds each of its views in its slot.
func mount(p_screen: Thing, p_channel: Bus = null) -> void:
	unmount()
	if p_screen == null:
		return
	screen = p_screen
	channel = p_channel if p_channel != null else Bus.new()
	screen.channel = channel
	var slots: Variant = screen.data.get("slots", {})
	if slots is Dictionary:
		for slot_name: Variant in slots:
			_lay(String(slot_name), (slots as Dictionary)[slot_name] as Dictionary)
	for view: View in views():
		var box: Control = _slots.get(view.slot()) as Control
		if box == null:
			push_warning("ViewHost.mount: the view %s stands in the slot '%s', which the screen %s does not lay." % [view.thing_id, view.slot(), screen.thing_id])
			continue
		var root := VBoxContainer.new()
		root.name = view.thing_id
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if box is BoxContainer:
			root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.visible = bool(view.attribute("shown", true))
		box.add_child(root)
		view.root = root
		view.build(root)

## The views of the screen, in the order it holds them.
func views() -> Array[View]:
	var out: Array[View] = []
	if screen != null:
		for mechanic: Mechanic in screen.mechanics:
			if mechanic is View:
				out.append(mechanic as View)
	return out

## The view of the screen named `id`, by its name or its whole id; null when it holds none.
func view(id: String) -> View:
	var name: String = Thing.name_of(id)
	for one: View in views():
		if one.thing_id == name:
			return one
	return null

## The Control of a slot of the screen; null when it lays no such slot.
func slot(slot_name: String) -> Control:
	return _slots.get(slot_name) as Control

## Shows a view that is hidden, or hides one that is shown; whether it is shown now.
func toggle(id: String) -> bool:
	var one: View = view(id)
	if one == null or one.root == null:
		return false
	one.root.visible = not one.root.visible
	return one.root.visible

## Takes the views down: their Controls go, and the screen keeps its channel and its views.
func unmount() -> void:
	for one: View in views():
		one.root = null
	for box: Variant in _slots.values():
		var node: Node = box as Node
		if node != null and is_instance_valid(node):
			base.remove_child(node)
			node.queue_free()
	_slots.clear()
	screen = null

# --- Library ---

# Lays one slot: a box at its anchors and offsets.
func _lay(slot_name: String, spec: Dictionary) -> void:
	var how: String = String(spec.get("box", COLUMN))
	var box: Control = null
	match how:
		ROW:
			box = HBoxContainer.new()
		FREE:
			box = Control.new()
		_:
			box = VBoxContainer.new()
	box.name = slot_name
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var anchors: Array = spec.get("anchors", [0, 0, 0, 0])
	var offsets: Array = spec.get("offsets", [0, 0, 0, 0])
	box.anchor_left = float(anchors[0])
	box.anchor_top = float(anchors[1])
	box.anchor_right = float(anchors[2])
	box.anchor_bottom = float(anchors[3])
	box.offset_left = float(offsets[0])
	box.offset_top = float(offsets[1])
	box.offset_right = float(offsets[2])
	box.offset_bottom = float(offsets[3])
	if box is BoxContainer:
		(box as BoxContainer).add_theme_constant_override("separation", int(spec.get("gap", 4)))
	base.add_child(box)
	_slots[slot_name] = box
