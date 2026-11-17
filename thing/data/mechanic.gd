# Mechanic — a Thing that plugs into another Thing and gives it a behavior
# (J188: "Mechanic -> Thing pq a Mechanic pode ter estado"). It is inherited
# like any Thing: same catalog, same ancestor chain, same ThingVariant merge.
#
# Writing a mechanic (J189) is writing its JSON and, when it does something,
# its `<id>.gd`, a script that extends Mechanic and overrides the hooks below,
# and only them; the boot warns of a hook that does not exist and of a method
# of the library a script overrides.
#
#   {
#     "id": "mechanic.armor",
#     "priority": 10,              lower hears sooner; 0 when it says none
#     "hears": ["event.attack"],   the facts about its Thing it hears first
#     "watches": ["event.dawn"],   the facts of its space it hears after
#     "armor": 2
#   }
#
#   extends Mechanic
#   func _on_event(e: Event) -> void:
#       e.data["damage"] = maxi(0, int(e.data["damage"]) - int(attr("armor")))
#
# A mechanic acts directly only on its Thing, `big_thing`; to reach another
# Thing it manifests a fact, `manifest(id, marks, about)`, which the other's
# mechanics hear. Its `think` and `manifest` speak as its Thing. A name in
# `hears` and `watches` catches its heirs: `attack` hears `attack.melee`.
# They are read when it plugs in.
#
# Lightweight RefCounted: no scene tree, no _process, and no mind of its own
# until someone reads it, so many mechanics per Thing are cheap. The Thing
# owns its mechanics and a mechanic only points back weakly, so dropping the
# last reference to a Thing frees the Thing and its mechanics with no detach.
# A mechanic someone else still holds can outlive its Thing: `big_thing` just
# reads null from then on.
extends Thing
class_name Mechanic

# --- Data ---

## The Thing it plugs into; null when it plugs into none, or its Thing is gone.
var big_thing: Thing:
	get:
		return null if _big_thing == null else _big_thing.get_ref() as Thing
	set(value):
		_big_thing = null if value == null else weakref(value)

var _big_thing: WeakRef = null
# What it read of its data when it plugged in: its priority, the names it
# hears (about its Thing) and the names it watches (in its space).
var _priority: int = 0
var _hears: Dictionary = {}
var _watches: Array[StringName] = []
# The space it watches in, while it watches.
var _watching: Bus = null

# --- Hooks: override these, and only these ---

## Runs once it plugs into its Thing, `big_thing` already set.
func _on_attach() -> void:
	pass

## Runs once before it leaves its Thing, `big_thing` still set.
func _on_detach() -> void:
	pass

## A thought of its Thing: every one, by priority. `e.hold()` stops it, and
## the mechanics after this one do not hear it.
func _on_thought(_e: Event) -> void:
	pass

## A fact it hears: one about its Thing that it `hears`, before the fact
## happens in the space, when it may change `e.data` or `e.hold()` it; or one
## of its space that it `watches`, after. `e.target == big_thing` tells which.
func _on_event(_e: Event) -> void:
	pass

# --- Tools ---

## What a field of it reads: its own value and effects, with the effects that
## reach its Thing over them, where they name it or a mechanic it inherits
## from: `"mods": { "mechanic.birth": { "max": "-1" } }`.
func attribute(key: String, default_value: Variant = null) -> Variant:
	var value: Variant = super(key, default_value)
	var t: Thing = big_thing
	if t == null:
		return value
	var union: Effect = t.effect()
	return value if union == null else format_attr(union.over_mechanic(lineage(), key, value))

## Whether an effect that reaches its Thing blocks it: a mechanic blocked hears
## nothing.
func is_blocked() -> bool:
	var t: Thing = big_thing
	return t != null and t.blocked(thing_id if ancestor == "" else ancestor + ID_DOT + thing_id)

## The table its Thing plays on: the first Table up the chain of `above`, its
## Thing included; null when it plays on none.
func table() -> Table:
	var at: Thing = big_thing
	var seen: int = 0
	while at != null and seen < 64:
		if at is Table:
			return at as Table
		at = at.above
		seen += 1
	return null

## Both sides throw the dice of its table, with the table's rng: the margin is
## the actor's, and a tie goes to who resists. Null, after saying so, when its
## Thing plays on no table.
func versus(actor: int, resister: int) -> D5.Outcome:
	var at: Table = table()
	if at == null or at.dice == null:
		push_warning("Mechanic.versus: %s plays on no table." % thing_id)
		return null
	return at.dice.versus(actor, resister, at.rng)

## `base` and a throw of the dice of its table against a fixed `difficulty`.
## Null, after saying so, when its Thing plays on no table.
func against(base: int, difficulty: int) -> D5.Outcome:
	var at: Table = table()
	if at == null or at.dice == null:
		push_warning("Mechanic.against: %s plays on no table." % thing_id)
		return null
	return at.dice.against(base, difficulty, at.rng)

## Its Thing thinks it: every mechanic of its Thing hears it, this one too.
## With no Thing, it thinks as a Thing of its own.
func think(id: String, marks: Dictionary = {}) -> Event:
	var t: Thing = big_thing
	return super(id, marks) if t == null else t.think(id, marks)

## Its Thing manifests it, in its Thing's space (`Thing.manifest`). With no
## Thing, it manifests as a Thing of its own.
func manifest(id: String, marks: Dictionary = {}, about: Thing = null) -> Event:
	var t: Thing = big_thing
	return super(id, marks, about) if t == null else t.manifest(id, marks, about)

## Plugs it into `t`: it hears the mind of `t` and watches its space, then its
## `_on_attach` runs. Refuses a second Thing: detach first. Called by
## `Thing.add_mechanic`.
func attach(t: Thing) -> void:
	if t == null or big_thing == t:
		return
	if big_thing != null:
		push_warning("Mechanic.attach: %s already plugs into %s; detach first." % [thing_id, big_thing.thing_id])
		return
	big_thing = t
	_read_ears()
	t.mind.subscribe(Bus.ANY, _thought, _priority)
	_watch()
	_attached()
	_on_attach()

## Unplugs it from its Thing: its `_on_detach` runs, then it hears the Thing no
## more. Harmless when its Thing is gone. Called by `Thing.remove_mechanic`.
func detach() -> void:
	var t: Thing = big_thing
	if t == null:
		return
	_on_detach()
	_detaching()
	_unwatch()
	if t.has_mind():
		t.mind.unsubscribe(Bus.ANY, _thought)
	big_thing = null

# --- Library ---

# Whether it joins `t` when plugged in; an Effect may refuse, by its `stack`.
func _joins(_t: Thing) -> bool:
	return true

# What the library does when it plugs in, before `_on_attach`, and when it
# leaves, after `_on_detach`; an Effect lends and counts here.
func _attached() -> void:
	pass

func _detaching() -> void:
	pass

# A thought or a fact on its way to the hook, unless an effect blocks it.
func _thought(e: Event) -> void:
	if not is_blocked():
		_on_thought(e)

func _watched(e: Event) -> void:
	if not is_blocked():
		_on_event(e)

func _read_ears() -> void:
	_priority = int(data.get("priority", 0))
	_hears.clear()
	for id: StringName in _names(data.get("hears", [])):
		_hears[id] = true
	_watches = _names(data.get("watches", []))

# Whether it hears one of `ids`, the lineage of a fact.
func _hears_one_of(ids: Array[StringName]) -> bool:
	for id: StringName in ids:
		if _hears.has(id):
			return true
	return false

# Watches in the space of its Thing, its channel or the Air.
func _watch() -> void:
	var t: Thing = big_thing
	if t == null or _watches.is_empty():
		return
	_unwatch()
	_watching = t.channel if t.channel != null else Air.bus
	for id: StringName in _watches:
		_watching.subscribe(id, _watched, _priority)

func _unwatch() -> void:
	if _watching == null:
		return
	for id: StringName in _watches:
		_watching.unsubscribe(id, _watched)
	_watching = null

# The names of a list of ids, as the buses keep them: `attack` for
# `event.attack`.
static func _names(listed: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if listed is Array:
		for one: Variant in (listed as Array):
			var name: String = Thing.name_of(String(one))
			if name != "":
				out.append(StringName(name))
	elif listed is String and String(listed) != "":
		out.append(StringName(Thing.name_of(String(listed))))
	return out
