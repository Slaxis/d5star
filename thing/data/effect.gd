# Effect — a mechanic that lasts (J189): while it is plugged into a Thing, it
# changes what the Thing's attributes read, blocks mechanics and lends others.
# One instance per application. Its JSON:
#
#   {
#     "id": "effect.fortified",
#     "turns": 2,                  how many turns it lasts; -1, the default, forever
#     "mods": {
#       "defense": "+2",           a field of its Thing, by an operator
#       "mechanic.birth": { "max": "-1" }   a field of a mechanic of its Thing
#     },
#     "blocks": ["job"],           the mechanics it blocks, and their heirs
#     "lends": ["card.march"],     the mechanics it plugs into its Thing while it lasts
#     "stack": "renew"             when it lands again on a Thing that has it:
#                                  renew (the default), add, or keep
#   }
#
# The Thing integrates its effects (`Thing.effect()`): the union of every effect
# that reaches it, its own and those of the Things above it, is one Effect, which
# `attribute()` reads. The union is an operator, `Effect.union(a, b)`, and it
# commutes: of the effects that set a field, the one of the highest priority
# wins, the latest if they tie; else a number reads (raw + the sum of the adds)
# × the product of the multiplications, `-` adding the negative and `/`
# multiplying by the inverse. A value that is no number takes the operations in
# the order of priority, as the Mesclar would.
extends Mechanic
class_name Effect

const STACK_RENEW := "renew"
const STACK_ADD := "add"
const STACK_KEEP := "keep"

## Moves each time an effect comes or goes, or a Thing goes under another: a
## Thing whose union was worked out before works it out again.
static var epoch: int = 0
static var _arrivals: int = 0

# --- Data ---

## The turns it has left; -1 forever. Set when it lands, from `turns`.
var left: int = -1

# The changes worked out from `mods`: of each field of its Thing, and of each
# field of each mechanic, by the name of the mechanic.
var _fields: Dictionary = {}
var _of_mechanics: Dictionary = {}
var _blocks: Dictionary = {}
var _worked: bool = false
var _arrival: int = 0
var _lent: Array[Mechanic] = []

# What an effect, or a union, does to one field.
class Change extends RefCounted:
	var add: float = 0.0
	var mul: float = 1.0
	var sets: bool = false
	var value: Variant = null
	var set_at: Array = []
	# Each operation in order, [rank, operand, counted in add or mul].
	var steps: Array = []

	func joined(other: Change) -> Change:
		var out := Change.new()
		out.add = add + other.add
		out.mul = mul * other.mul
		out.sets = sets or other.sets
		if sets and (not other.sets or Effect._sooner(other.set_at, set_at)):
			out.value = value
			out.set_at = set_at
		elif other.sets:
			out.value = other.value
			out.set_at = other.set_at
		out.steps = steps + other.steps
		out.steps.sort_custom(func(a: Array, b: Array) -> bool: return Effect._sooner(a[0], b[0]))
		return out

	func over(raw: Variant) -> Variant:
		if sets:
			return value
		var out: Variant = raw
		var counted: bool = raw is int or raw is float
		if counted:
			out = (float(raw) + add) * mul
		for step: Array in steps:
			if not (counted and bool(step[2])):
				out = ThingVariant.merge(out, step[1])
		return out

# --- Tools ---

## The union of two effects: one Effect that changes each field as both do. It
## commutes, so the order of the effects never matters.
static func union(a: Effect, b: Effect) -> Effect:
	if a == null:
		return b
	if b == null:
		return a
	a._work()
	b._work()
	var out := Effect.new()
	out._worked = true
	out._fields = _joined(a._fields, b._fields)
	for name: StringName in a._of_mechanics.keys() + b._of_mechanics.keys():
		if not out._of_mechanics.has(name):
			out._of_mechanics[name] = _joined(a._of_mechanics.get(name, {}), b._of_mechanics.get(name, {}))
	out._blocks = a._blocks.merged(b._blocks)
	return out

## The union of many effects; null for none.
static func union_of(effects: Array[Effect]) -> Effect:
	var out: Effect = null
	for one: Effect in effects:
		out = union(out, one)
	return out

## What the field `key` of its Thing reads, `raw`, with this effect over it.
func over(key: String, raw: Variant) -> Variant:
	_work()
	var change: Change = _fields.get(key)
	return raw if change == null else change.over(raw)

## What the field `key` of a mechanic reads, `raw`, with this effect over it:
## the changes written for its name and for the names it inherits.
func over_mechanic(lineage: Array[StringName], key: String, raw: Variant) -> Variant:
	_work()
	var change: Change = null
	for name: StringName in lineage:
		var of_name: Dictionary = _of_mechanics.get(name, {})
		if of_name.has(key):
			change = of_name[key] if change == null else change.joined(of_name[key])
	return raw if change == null else change.over(raw)

## Whether it blocks a mechanic of one of these names, its lineage.
func blocks_one_of(lineage: Array[StringName]) -> bool:
	_work()
	for name: StringName in lineage:
		if _blocks.has(name):
			return true
	return false

## One turn passes: true when it has just run out. An effect forever never does.
func tick() -> bool:
	if left < 0:
		return false
	left = maxi(0, left - 1)
	return left == 0

# --- Library ---

# An effect of the same id already on the Thing decides, by `stack`, whether
# this one joins: renew gives the one there the turns of the longer, add plugs
# this one too, keep leaves the one there as it is.
func _joins(t: Thing) -> bool:
	var stack: String = String(data.get("stack", STACK_RENEW)).strip_edges().to_lower()
	if stack == STACK_ADD or thing_id == "":
		return true
	for there: Mechanic in t.mechanics:
		if there is Effect and there.thing_id == thing_id and there != self:
			if stack == STACK_RENEW:
				var turns: int = int(attribute("turns", -1))
				var kept := there as Effect
				kept.left = -1 if turns < 0 or kept.left < 0 else maxi(kept.left, turns)
			return false
	return true

func _attached() -> void:
	left = int(attribute("turns", -1))
	_arrivals += 1
	_arrival = _arrivals
	_worked = false
	var t: Thing = big_thing
	for id: StringName in Mechanic._names(data.get("lends", [])):
		var lent: Mechanic = God.things.create(String(id)) as Mechanic
		if lent != null:
			_lent.append(lent)
			t.add_mechanic(lent)
	epoch += 1

func _detaching() -> void:
	var t: Thing = big_thing
	for lent: Mechanic in _lent:
		t.remove_mechanic(lent)
	_lent.clear()
	epoch += 1

# Works out the changes of its `mods` and its `blocks`, once.
func _work() -> void:
	if _worked:
		return
	_worked = true
	_fields = {}
	_of_mechanics = {}
	var at: Array = [_rank(), _arrival]
	var mods: Variant = data.get("mods", {})
	if mods is Dictionary:
		for key: Variant in (mods as Dictionary):
			var written: Variant = (mods as Dictionary)[key]
			if written is Dictionary:
				var of_name: Dictionary = {}
				for field: Variant in (written as Dictionary):
					of_name[String(field)] = _change(written[field], at)
				_of_mechanics[StringName(Thing.name_of(String(key)))] = of_name
			else:
				_fields[String(key)] = _change(written, at)
	_blocks = {}
	for name: StringName in Mechanic._names(data.get("blocks", [])):
		_blocks[name] = true

# The change a value written in `mods` makes: an operation, counted in the add
# or the multiplication when it is one of the four over a number, or a value
# that sets the field.
static func _change(written: Variant, at: Array) -> Change:
	var change := Change.new()
	if written is String and not String(written).begins_with(ThingVariant.ESCAPE):
		var op: ThingOperator = ThingVariant._operator_of(String(written))
		if op != null:
			var operand: String = String(written).substr(op.symbol().length()).strip_edges()
			var counted: bool = operand.is_valid_float() and ["+", "-", "*", "/"].has(op.symbol())
			if counted:
				var x: float = float(operand)
				match op.symbol():
					"+": change.add = x
					"-": change.add = -x
					"*": change.mul = x
					"/": change.mul = 1.0 / x if x != 0.0 else 1.0
			change.steps = [[at, written, counted]]
			return change
	change.sets = true
	change.value = ThingVariant.merge(null, written)
	change.set_at = at
	return change

static func _joined(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate()
	for key: Variant in b:
		out[key] = b[key] if not out.has(key) else (out[key] as Change).joined(b[key])
	return out

# Its priority, as its JSON says it, plugged in or not.
func _rank() -> int:
	return int(data.get("priority", 0))

# Whether the rank `a`, [priority, arrival], comes before `b`.
static func _sooner(a: Array, b: Array) -> bool:
	return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1]))
