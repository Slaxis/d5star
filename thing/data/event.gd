# Event — a fact, and the Thing that carries it (J189). One object travels
# both ways a Thing talks, and the verb says the way:
#
#   - `think(id, marks)`: a thought, from the Thing to its mechanics, which
#     only they hear (Mechanic._on_thought).
#   - `manifest(id, marks, target)`: a fact the Thing makes happen in the
#     space it shares with others. It reaches first its target, whose
#     mechanics that hear it may change its marks or hold it, as a Caves of
#     Qud handler returns false; then, if nobody held it, the space, where
#     whoever watches it hears it (Mechanic._on_event).
#
# An event is a Thing: its id says what happened, `event.born`, or a word of
# before such as `leader_died`; its data are its marks, the values its text
# fills; `source` is the Thing that made it happen, and `target` the one it is
# about. Whoever hears an event hears its heirs too: `attack` hears
# `attack.melee`.
#
# An event of the content, a Thing whose chain goes up to the native `event`,
# is its definition, one per id, and each time it happens points to it:
#
#   {
#     "id": "event.heatwave",
#     "text": { "pt": "Calorão em {region}.", "en": "Heatwave in {region}." },
#     "effect": { "on": "region", "turns": 4, "mods": { "housing": "*0.75" } },
#     "mechanics": ["mechanic.panic"]
#   }
#
# `told()` is its text with the marks filled. When it happens and nobody held
# it, its effect lands, an Effect written inline or the id of one, on `on`: the
# target, the default, the source, or the Thing a mark holds; then the
# mechanics of the definition hear it, in `_on_event`, by priority; then the
# space.
#
# An event lives while someone holds it: GDScript frees it the moment the last
# one lets go, so there is no pool to fill, as Caves of Qud keeps against the
# pauses of its collector.
extends Thing
class_name Event

## The native at the root of every event of the content.
const NATIVE := "event"

# --- Data ---

## The Thing that made it happen: the Thing of the mechanic that manifested
## it, or the Thing that thought it.
var source: Thing = null
## The Thing it is about; null for a fact about nobody, such as a phase of the
## table.
var target: Thing = null
## Whether someone held it: nobody after them hears it, and it does not land.
var held: bool = false

# --- Tools ---

## An event that has not happened yet. A whole id, `event.born`, names it by
## its name, `born`; an id of before, with no dot, stays as it was written.
static func make(id: String, marks: Dictionary = {}, from: Thing = null, about: Thing = null) -> Event:
	var made := Event.new()
	if id.contains(ID_DOT):
		made.thing_id = Thing.name_of(id)
		made.ancestor = Thing.parent_of(id)
	else:
		made.thing_id = id
	made.data = marks
	made.source = from
	made.target = about
	return made

## Stops the event where it is: nobody after hears it, and it does not land.
func hold() -> void:
	held = true

## Whether it is the event `id` or one of its heirs.
func is_a(id: String) -> bool:
	return lineage().has(StringName(Thing.name_of(id)))

## Its name and the names it inherits, the closest first, up to `event`; only
## its name when it is no event of the content, as the facts of before. Shared:
## read it, never change it.
func lineage() -> Array[StringName]:
	return God.things.lineage(thing_id if ancestor == "" else ancestor + ID_DOT + thing_id, NATIVE)

## The Thing of the content that defines it, shared by every time it happens;
## null for a fact of before.
func definition() -> Thing:
	return God.things.definition(lineage())

## Its text, in the language of the game, with each mark in its place: a Thing
## by its name, anything else as it reads. "" when it has no text.
func told() -> String:
	var defined: Thing = definition()
	if defined == null or not defined.data.has("text"):
		return ""
	var shown: Dictionary = {}
	for mark: Variant in data:
		var value: Variant = data[mark]
		if value is Thing:
			var named: Thing = value as Thing
			shown[mark] = named.text("name", named.thing_id) if named.data.has("name") else named.thing_id
		else:
			shown[mark] = value
	return I18n.format(defined.text("text"), shown)

# --- Library ---

# Makes the fact happen: the target first, then, if nobody held it, its
# definition, its effect landing and its mechanics hearing it, then the space,
# `space`, or the Air when the Thing that manifested it is on no channel.
func _happen(space: Bus) -> void:
	if target != null:
		target._hear_about(self)
		if held:
			return
	var defined: Thing = definition()
	if defined != null:
		_land(defined)
		if held:
			return
	if space != null:
		space.dispatch(self)
	else:
		Air.dispatch(self)

func _land(defined: Thing) -> void:
	var written: Variant = defined.data.get("effect")
	if written != null:
		var on: String = String((written as Dictionary).get("on", "target")) if written is Dictionary else "target"
		var lands_on: Thing = _thing_at(on)
		var made: Effect = _effect(written, defined)
		if lands_on != null and made != null:
			lands_on.add_mechanic(made)
	var ears: Array[Mechanic] = []
	for mechanic: Mechanic in defined.mechanics:
		var at: int = ears.size()
		while at > 0 and ears[at - 1]._priority > mechanic._priority:
			at -= 1
		ears.insert(at, mechanic)
	for mechanic: Mechanic in ears:
		if not mechanic.is_blocked():
			mechanic._on_event(self)
			if held:
				return

# The Thing a word of `on` names: the target, the source, or a mark that holds one.
func _thing_at(on: String) -> Thing:
	match on:
		"target":
			return target
		"source":
			return source
	var marked: Variant = data.get(on)
	return marked as Thing if marked is Thing else null

# The effect an event leaves: the id of an Effect of the content, or one
# written inline, which takes the name of the event, so that it renews when the
# event happens again.
static func _effect(written: Variant, defined: Thing) -> Effect:
	if written is String:
		return God.things.create(Thing.name_of(String(written))) as Effect
	if not written is Dictionary:
		return null
	var made := Effect.new()
	made.thing_id = defined.thing_id
	made.data = (written as Dictionary).duplicate(true)
	made.data.erase("on")
	return made
