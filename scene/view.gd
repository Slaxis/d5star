# View — a piece of a screen, as a Thing (0.17.0). A screen is a Thing whose mechanics are
# its views, and a ViewHost mounts them: each view builds its Controls in the slot of the
# screen its JSON names, once, and draws them again when a fact it watches happens on the
# screen's channel. A view never hears the facts of a match: the screen is a group of
# Things of its own, on a channel of its own (Thing.channel).
#
#   {
#     "id": "view.turn_view",
#     "slot": "top",                                   the slot of the screen it stands in
#     "title": { "pt": "Turno", "en": "Turn" },        for a tab, a tooltip or a menu
#     "icon": "turn",                                  the id of its icon
#     "shown": true,                                   false: it starts hidden
#     "watches": ["ui.changed"]                        the facts of the screen it hears
#   }
#
#   extends View
#   var _label: Label = null
#   func build(root: Control) -> void:
#       _label = Label.new()
#       root.add_child(_label)
#   func _on_event(e: Event) -> void:
#       _label.text = str(e.data.get("turn", 0))
#
# Writing a view is writing its JSON and its `<id>.gd`, a script that extends View and
# overrides `build` and the hooks of a Mechanic, and only them: a helper starts with `_`
# (HookValidator). A mod changes a view by its id, `{ "id": "view.turn_view", "slot":
# "bottom" }`, swaps its `<id>.gd`, takes it out of its screen or adds its own, and the host
# mounts what the screen holds, with no change to the screen's scene.
extends Mechanic
class_name View

## The hooks of a view that do not start with `_on_`.
const HOOKS: Array[String] = ["build"]

# --- Data ---

## The Control the host built it in; null while it is not mounted.
var root: Control = null

# --- Hooks of a view: override these ---

## Builds its Controls under `root`, once, when the host mounts it. Nothing, when it says
## nothing.
func build(_root: Control) -> void:
	pass

# --- Tools ---

## The slot of the screen it stands in, from its field `slot`.
func slot() -> String:
	return String(attribute("slot", ""))

## Whether it is mounted and shown.
func shown() -> bool:
	return root != null and root.visible
