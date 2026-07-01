# Thing — the main runtime abstraction. An entity in the game world,
# resolved from a ThingType, holding data + a list of plugged-in
# ThingParts, and dispatching messages through two buses:
#
#   - `mind` (local Bus) — internal thoughts, heard by self and by
#     its Parts only. Fired via `think(thought)`.
#   - `Air` (world bus, autoload) — external broadcasts, heard by
#     any subscriber in the world. Fired via `say(message)`.
#
# One primitive (`Bus`) backs both scopes. Verbs follow the original
# scrap-warriors design: `think` for cogitation, `say` for broadcast
# — an explicit decision the Thing makes.
#
# Pure RefCounted, no Node. When something needs to be visible in
# the scene tree, an upstream layer wraps a Thing in a Node-based
# adapter (e.g. H3X4X's `Piece extends Node2D` holds a Thing ref).
# Keeping the brain out of the scene tree gives clean refcount-based
# lifetime, no _process overhead, no scene tree noise, and makes the
# Model/View separation explicit.
extends ThingData
class_name Thing

var thing_id: String = ""
var ancestor: String = ""
var parts: Array[ThingPart] = []
var mind: Bus = null

func _init() -> void:
	mind = Bus.new()

# Called by the catalog after instantiation to seed the Thing with
# its resolved id / ancestor / merged data. Kept as a method (not a
# constructor arg) so the catalog can clone prototypes via the
# script-less `script.new()` path and then populate them.
func _apply_data(new_id: String, new_ancestor: String, new_data: Dictionary) -> void:
	thing_id = new_id
	ancestor = new_ancestor
	data = new_data.duplicate(true)

# Plug a ThingPart into this Thing. Wires the part's `_on_thought`
# into our local bus so `think` reaches it. Idempotent: the part
# rejects re-attaching to a different Thing (would silently leak
# the previous subscription).
func add_part(part: ThingPart) -> void:
	if part == null or parts.has(part):
		return
	parts.append(part)
	part.attach(self)

func remove_part(part: ThingPart) -> void:
	if part == null or not parts.has(part):
		return
	part.detach()
	parts.erase(part)

# Dispatch a thought through the LOCAL bus. Every plugged part
# hears it via the mind signal (parts.attach subscribes them); the
# Thing itself can also override `_on_thought` to react. This is
# the Qud-style duck-typed event flow, kept internal.
func think(thought: Cmd) -> void:
	if mind != null:
		mind.dispatch(thought)

# Broadcast a message through the GLOBAL bus. Anyone subscribed to
# Air receives it — world systems (log, achievements, HUD, replay)
# hear it without knowing about this Thing. Say what you want the
# world to hear; keep everything else inside `think`.
func say(message: Cmd) -> void:
	Air.dispatch(message)

# Shallow clone — used by the catalog's prototype pattern. Creates a
# fresh Thing with the same id / ancestor / data; parts are NOT
# copied (the assembler re-attaches a fresh set on the clone so each
# instance owns its own behavior state).
func clone() -> Thing:
	var copy: Thing = (get_script() as Script).new()
	if copy == null:
		return null
	copy._apply_data(thing_id, ancestor, data)
	return copy
