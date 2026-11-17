# Table — where a game is played (J189), a native Thing: its channel, the space
# every Thing put on it shares; the seeded rng of the match; its dice; and its
# phases, the facts it manifests in order on each turn.
#
#   {
#     "id": "table.match",
#     "phases": ["event.pre", "event.turn", "event.post"],
#     "dice": "dice.d5"
#   }
#
# The table runs no mechanic by itself: whatever moves in a phase is a mechanic
# that watches the phase, and the channel calls them by their priority, the
# agenda of the table. A game with no turns names no phase. At the end of each
# turn every effect on the table counts a turn down, and one that runs out
# leaves its Thing, which manifests `effect_over`, with the name of the effect
# in the mark `effect`; the module gives that event its text.
extends Thing
class_name Table

## The fact of an effect that ran out.
const EFFECT_OVER := "effect_over"

# --- Data ---

## The rng of the match: every throw of the table's dice takes it, so the same
## seed plays the same game.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The die every action throws, from `dice`; the native d5*, twice, when it
## names none.
var dice: Dice = null
## The turns played.
var turn: int = 0

var _things: Array[WeakRef] = []

# --- Tools ---

## Sets the table: a channel of its own, the rng seeded by `match_seed`, its
## dice, and no turn played.
func start(match_seed: int) -> void:
	if channel == null:
		channel = Bus.new()
	rng.seed = match_seed
	turn = 0
	var named: String = String(attribute("dice", ""))
	dice = God.things.create(Thing.name_of(named)) as Dice if named != "" else null
	if dice == null:
		dice = Dice.new()
	dice.above = self

## Puts a Thing on the table: on its channel, under `under`, or under the table
## itself, so that the effects of the Things above reach it.
func put(thing: Thing, under: Thing = null) -> void:
	thing.channel = channel
	thing.above = under if under != null else self
	_things.append(weakref(thing))

## Plays one turn: each phase, in order, is a fact on the channel, with the turn
## in its mark `turn`; then each effect on the table counts a turn down.
func play_turn() -> void:
	var phases: Variant = attribute("phases", [])
	for phase: Variant in (phases as Array if phases is Array else []):
		manifest(String(phase), { "turn": turn })
	_count_down()
	turn += 1

# --- Library ---

func _count_down() -> void:
	var alive: Array[WeakRef] = []
	var on_table: Array[Thing] = [self]
	for ref: WeakRef in _things:
		var thing: Thing = ref.get_ref() as Thing
		if thing != null:
			alive.append(ref)
			on_table.append(thing)
	_things = alive
	for thing: Thing in on_table:
		var over: Array[Effect] = []
		for mechanic: Mechanic in thing.mechanics:
			if mechanic is Effect and (mechanic as Effect).tick():
				over.append(mechanic as Effect)
		for ran_out: Effect in over:
			thing.remove_mechanic(ran_out)
			thing.manifest(EFFECT_OVER, { "effect": ran_out.thing_id }, thing)
