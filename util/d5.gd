# D5 — the exploding die the library is named after.
#
# A d5* shows 0..5 and explodes in BOTH directions:
#
#   rolled 5  →  roll again and ADD       (5 + d5*)
#   rolled 0  →  roll again and SUBTRACT  (0 - d5*)
#   1..4      →  that is the result
#
# Mean is 2.5 and the explosions cancel exactly, so the die is symmetric: it
# is as likely to run away up as down. That symmetry is the whole point — a
# sandlot side genuinely can beat the champion, and the champion genuinely can
# have a catastrophic afternoon, without anyone tilting the odds by hand.
#
# A check is a base value plus dice, and the canonical shape is two dice
# because a contested action sums two things the actor owns:
#
#   attribute + d5*  +  skill + d5*     ==  attribute + skill + 2d5*
class_name D5

const MIN_FACE := 0
const MAX_FACE := 5
const DEFAULT_DICE := 2
# Each explosion is a 1-in-6 event, so a chain of 12 has odds around 1 in 2
# billion. The cap exists so a pathological RNG cannot hang a match, never
# because the chain is expected to reach it.
const MAX_CHAIN := 12

# One d5*, explosions included.
static func roll(rng: RandomNumberGenerator) -> int:
	return _roll(rng, 0)

# The sum of `count` independent d5*.
static func roll_many(rng: RandomNumberGenerator, count: int = DEFAULT_DICE) -> int:
	var total: int = 0
	for i: int in range(maxi(count, 0)):
		total += roll(rng)
	return total

# A base value plus its dice — what an actor's attempt is worth this time.
static func check(base: int, rng: RandomNumberGenerator, dice: int = DEFAULT_DICE) -> int:
	return base + roll_many(rng, dice)

# Attacker's margin over the defender. Positive means the attacker won, and by
# how much: a match cares about the size of the win, not only who took it.
static func contest(attacker_base: int, defender_base: int,
		rng: RandomNumberGenerator, dice: int = DEFAULT_DICE) -> int:
	return check(attacker_base, rng, dice) - check(defender_base, rng, dice)

# --- Internals ---

static func _roll(rng: RandomNumberGenerator, depth: int) -> int:
	var face: int = rng.randi_range(MIN_FACE, MAX_FACE)
	if depth >= MAX_CHAIN:
		return face
	if face == MAX_FACE:
		return MAX_FACE + _roll(rng, depth + 1)
	if face == MIN_FACE:
		return -_roll(rng, depth + 1)
	return face
