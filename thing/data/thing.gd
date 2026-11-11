# Thing — the main runtime abstraction. An entity in the game world,
# resolved from a ThingType, holding data + a list of plugged-in
# ThingParts, and dispatching messages through three buses:
#
#   - `mind` (local Bus) — internal thoughts, heard by self and by
#     its Parts only. Fired via `think(thought)`.
#   - `channel` (a group's Bus, optional) — what the Thing says,
#     heard only by those tuned to the same channel, such as the
#     other Things of one match. Fired via `say(message)`.
#   - `Air` (world bus, autoload) — what a Thing on no channel
#     says, heard by any subscriber in the world. Also `say`.
#
# One primitive (`Bus`) backs every scope. Verbs follow the original
# scrap-warriors design: `think` for cogitation, `say` for broadcast
# — an explicit decision the Thing makes. The mind thinks, the
# channel talks, the air announces.
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
# The channel the Thing is tuned to. Whoever makes the channel, a
# `Bus.new()`, sets it on each Thing of its group; `null`, the
# default, sends `say` to `Air`. A clone comes without one.
var channel: Bus = null

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

# Say a message: on the Thing's channel when it is tuned to one, so
# only its group hears it, or on the GLOBAL bus, `Air`, when it is
# not — world systems (log, achievements, HUD, replay) hear it
# without knowing about this Thing. Never both: whoever listens to
# a channel relays to `Air` what the world needs. Say what you
# want others to hear; keep everything else inside `think`.
func say(message: Cmd) -> void:
	if channel != null:
		channel.dispatch(message)
	else:
		Air.dispatch(message)

# Shallow clone — used by the catalog's prototype pattern. Creates a
# fresh Thing with the same id / ancestor / data; parts are NOT
# copied (the assembler re-attaches a fresh set on the clone so each
# instance owns its own behavior state), and neither is the
# channel: whoever puts the clone in a group tunes it.
func clone() -> Thing:
	var copy: Thing = (get_script() as Script).new()
	if copy == null:
		return null
	copy._apply_data(thing_id, ancestor, data)
	return copy
