# Thing — everything the library holds is a Thing: its data, as its JSON
# wrote it over its ancestors', the mechanics plugged into it, and the spaces
# it talks in. A Mechanic is a Thing too, one that plugs into another, and so
# is an Event, a fact that happens (J188, J189).
#
# A Thing talks in two ways, and the verb says the way (J189):
#
#   - `think(id, marks)` — a thought, from the Thing to its mechanics: they
#     hear it in `_on_thought`, every one, by priority, and nobody else. It
#     goes through the Thing's `mind`, a Bus born the first time someone reads
#     it, so a Thing nobody listens to, a mechanic among them, costs no bus.
#   - `manifest(id, marks, about)` — a fact the Thing makes happen in the space
#     it shares with others. The Thing it is about hears it first: those of its
#     mechanics that `hears` it, in `_on_event`, by priority, which may change
#     its marks or hold it. Then, if nobody held it, the space: its `channel`,
#     the space of its group, such as the Things of one match, or the `Air`
#     when it is on no channel; there the mechanics that `watches` it hear it,
#     with whoever subscribed.
#
# A mechanic acts directly only on its own Thing; to reach another Thing it
# manifests a fact, and the other's mechanics hear it. Reading another Thing
# is free.
#
# Pure RefCounted, no Node. When something needs to be visible in the scene
# tree, an upstream layer wraps a Thing in a Node-based adapter (e.g. H3X4X's
# `Piece extends Node2D` holds a Thing ref). Keeping the brain out of the scene
# tree gives clean refcount-based lifetime, no _process overhead, no scene
# tree noise, and makes the Model/View separation explicit.
extends RefCounted
class_name Thing

# The id of a Thing may say the Thing it inherits from (J188):
# `<parent>.<name>`, as `card.loot` is the Thing `loot`, a heir of `card`.
# The name is unique, as a class_name is, so a Thing is found by its name
# or by its whole id. An id with no dot is of the format of before, which
# names its ancestor apart.
const ID_DOT := "."

# --- Data ---

## Its name: `loot` for the Thing written `card.loot`.
var thing_id: String = ""
## The Thing it inherits from: `card` for `card.loot`.
var ancestor: String = ""
## The canonical payload: the data of the JSON, merged over the ancestors'.
var data: Dictionary = {}
## The mechanics plugged into it, in the order they came.
var mechanics: Array[Mechanic] = []
## The Thing's own bus, where its mechanics hear what it thinks; born the
## first time it is read.
var mind: Bus:
	get:
		if _mind == null:
			_mind = Bus.new()
		return _mind
## The space the Thing is tuned to, shared with its group. Whoever makes the
## channel, a `Bus.new()`, sets it on each Thing of its group; `null`, the
## default, is the `Air`. Its mechanics watch there what they watch, and move
## with it. A clone comes without one.
var channel: Bus = null:
	set(value):
		if value == channel:
			return
		for mechanic: Mechanic in mechanics:
			mechanic._unwatch()
		channel = value
		for mechanic: Mechanic in mechanics:
			mechanic._watch()
## The Thing it is under, whose effects reach it too: a scrapper's tribe, a
## hexel's owner, the table. Weak: the Thing above holds nothing of it.
var above: Thing:
	get:
		return null if _above == null else _above.get_ref() as Thing
	set(value):
		_above = null if value == null else weakref(value)
		Effect.epoch += 1

var _mind: Bus = null
var _above: WeakRef = null
# The union of the effects that reach it, and the epoch it was worked out at.
var _union: Effect = null
var _union_epoch: int = -1

# --- Tools ---

## The name in an id: `loot` in `card.loot`, and the id itself when it has no
## dot.
static func name_of(id: String) -> String:
	var key: String = String(id).strip_edges().to_lower()
	var at: int = key.rfind(ID_DOT)
	return key if at < 0 else key.substr(at + ID_DOT.length())

## The parent an id says: `card` in `card.loot`; "" when it has no dot.
static func parent_of(id: String) -> String:
	var key: String = String(id).strip_edges().to_lower()
	var at: int = key.rfind(ID_DOT)
	return "" if at < 0 else key.substr(0, at)

## Normalises leaf values so consumers don't have to handle case / whitespace
## differences on every read. Static, so ThingType and others can call it
## without owning a Thing.
static func format_attr(value: Variant) -> Variant:
	if value is String:
		return String(value).strip_edges().to_lower()
	return value

## What a field reads (J189): its value in `data`, the raw one, with the
## effects that reach the Thing over it, its own and those of the Things above
## it. Normalised through `format_attr`, so callers can assume canonical form
## for strings.
func attribute(key: String, default_value: Variant = null) -> Variant:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	var union: Effect = effect()
	if union != null:
		value = union.over(key, value)
	return format_attr(value)

## The alias of `attribute`.
func attr(key: String, default_value: Variant = null) -> Variant:
	return attribute(key, default_value)

## The union of the effects that reach it (`Effect.union`): those plugged into
## it and into each Thing above it; null when none does. Worked out again only
## when an effect comes or goes, or a Thing moves under another.
func effect() -> Effect:
	if _union_epoch == Effect.epoch:
		return _union
	var reaching: Array[Effect] = []
	var at: Thing = self
	var seen: Array[Thing] = []
	while at != null and not seen.has(at):
		seen.append(at)
		for mechanic: Mechanic in at.mechanics:
			if mechanic is Effect:
				reaching.append(mechanic as Effect)
		at = at.above
	reaching.sort_custom(func(a: Effect, b: Effect) -> bool:
		return Effect._sooner([a._rank(), a._arrival], [b._rank(), b._arrival]))
	_union = Effect.union_of(reaching)
	_union_epoch = Effect.epoch
	return _union

## Whether an effect that reaches it blocks the mechanic `id`, or one it
## inherits from: blocking `job` blocks every job.
func blocked(id: String) -> bool:
	var union: Effect = effect()
	return union != null and union.blocks_one_of(God.things.lineage(id))

## Its name and the names it inherits, the closest first, up to the native at
## the root of its chain. Shared: read it, never change it.
func lineage() -> Array[StringName]:
	return God.things.lineage(thing_id if ancestor == "" else ancestor + ID_DOT + thing_id)

## Bilingual text resolution: `data[key]` is either a raw string or an
## `{ "pt": ..., "en": ... }` dict; I18n picks the active language.
func text(key: String, default_value: String = "") -> String:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return I18n.text(value, default_value)

## Whether the mind was born: true once someone read `mind`.
func has_mind() -> bool:
	return _mind != null

## Plugs a Mechanic into this Thing: it hears the Thing's mind, watches its
## space, and its `_on_attach` runs. A mechanic plugged into another Thing
## refuses, until it leaves it.
func add_mechanic(mechanic: Mechanic) -> void:
	if mechanic == null or mechanics.has(mechanic) or not mechanic._joins(self):
		return
	mechanics.append(mechanic)
	mechanic.attach(self)

## Unplugs a Mechanic: its `_on_detach` runs, and it hears this Thing no more.
func remove_mechanic(mechanic: Mechanic) -> void:
	if mechanic == null or not mechanics.has(mechanic):
		return
	mechanic.detach()
	mechanics.erase(mechanic)

## A thought: every mechanic of the Thing hears it, in `_on_thought`, by
## priority, until one holds it; nobody else. With no mind yet, nobody listens,
## and the thought goes nowhere without making one. Returns the event, with
## the marks as the mechanics left them.
func think(id: String, marks: Dictionary = {}) -> Event:
	var thought: Event = Event.make(id, marks, self)
	if _mind != null:
		_mind.dispatch(thought)
	return thought

## A fact the Thing makes happen in its space: `about`, the Thing it is about,
## hears it first, by the mechanics of its own that hear it, which may change
## its marks or hold it; then, if nobody held it, the space, its channel or the
## Air. Returns the event, with its marks as they were left, and whether
## someone held it.
func manifest(id: String, marks: Dictionary = {}, about: Thing = null) -> Event:
	var fact: Event = Event.make(id, marks, self, about)
	fact._happen(channel)
	return fact

## Shallow clone, for the catalog's prototype pattern: a fresh Thing of the
## same script with the same id / ancestor / data. Mechanics are NOT copied
## (the assembler attaches a fresh set on the clone, so each instance owns its
## own behavior state), and neither is the channel: whoever puts the clone in
## a group tunes it.
func clone() -> Thing:
	var copy: Thing = (get_script() as Script).new()
	if copy == null:
		return null
	copy._apply_data(thing_id, ancestor, data)
	return copy

# --- Library ---

# Called by the catalog after instantiation to seed the Thing with its
# resolved id / ancestor / merged data. Kept as a method (not a constructor
# arg) so the catalog can clone prototypes via the script-less `script.new()`
# path and then populate them.
func _apply_data(new_id: String, new_ancestor: String, new_data: Dictionary) -> void:
	thing_id = new_id
	ancestor = new_ancestor
	data = new_data.duplicate(true)

# A fact about this Thing, before it happens in the space: each of its
# mechanics that hears its id, or an id it inherits, by priority, the same
# priority in the order they came, until one holds it.
func _hear_about(e: Event) -> void:
	if mechanics.is_empty():
		return
	var ears: Array[Mechanic] = []
	var ids: Array[StringName] = []
	for mechanic: Mechanic in mechanics:
		if mechanic._hears.is_empty():
			continue
		if ids.is_empty():
			ids = e.lineage()
		if mechanic._hears_one_of(ids) and not mechanic.is_blocked():
			var at: int = ears.size()
			while at > 0 and ears[at - 1]._priority > mechanic._priority:
				at -= 1
			ears.insert(at, mechanic)
	for mechanic: Mechanic in ears:
		mechanic._on_event(e)
		if e.held:
			return
