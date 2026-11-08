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
# A 0 and a 5 both continue the chain, so each roll explodes with odds of 1
# in 3 and a chain of 12 comes up once in 531,441 dice (1 in 6 per step only
# holds for a run in a single direction). Rare, and harmless when it happens:
# the die just stops exploding, which trims the far tail. The cap exists so a
# pathological RNG cannot hang a match.
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

# --- The other reading of the same die ---
#
# A TALLY instead of a magnitude, the way White Wolf counts: 5 is one success,
# 0 is one failure, 1..4 is nothing happened, and both ends explode. So a week
# of training asks "how many successes today" rather than "how much".
#
# Centred on zero and symmetric: 67% of rolls are a flat nothing, ~11% each way
# is a single success or failure, and the tails past that are where the day you
# remember lives. That shape is the point — most days do not move a needle.
static func successes(rng: RandomNumberGenerator) -> int:
	return _successes(rng, 0)

# Several days at once, summed.
static func successes_many(rng: RandomNumberGenerator, rolls: int) -> int:
	var total: int = 0
	for _i: int in range(maxi(rolls, 0)):
		total += successes(rng)
	return total

static func _successes(rng: RandomNumberGenerator, depth: int) -> int:
	if depth >= MAX_CHAIN:
		return 0
	var face: int = rng.randi_range(MIN_FACE, MAX_FACE)
	if face == MAX_FACE:
		return 1 + _successes(rng, depth + 1)
	if face == MIN_FACE:
		return -1 + _successes(rng, depth + 1)
	return 0

# --- Stars: one roll, read for its total and for its fives ---
#
# The same throw as `roll`, the same total from the same RNG, read twice. Its
# STARS are the 5s that added to the total. A 5 that comes up while the chain
# runs down, after an odd number of 0s, makes the total worse, so it is no star.
# Stars are counted apart from the total: a roll can lose and still shine, and
# each game decides what a star buys.
#
#   5, 3        total  8, one star
#   5, 0, 5, 2  total -2, one star: the second 5 fell while subtracting
#   0, 0, 5, 1  total  6, one star: two 0s turned the chain back up
#
# A d5* gives 0.21 stars on average, so 2d5* gives 0.42.

# Five points of margin are one degree: a 17 against a difficulty of 5 is 2.4 degrees.
const DEGREE := 5

# One roll read both ways.
class Roll:
	extends RefCounted
	var total: int = 0
	var stars: int = 0

# A roll held against something else: a fixed difficulty, or another roll.
class Outcome:
	extends RefCounted
	# How far past it the roll went; negative when it fell short.
	var margin: int = 0
	# The actor's stars, which count win or lose.
	var stars: int = 0
	# The other side's stars in a contest; always 0 against a difficulty.
	var foe_stars: int = 0

	# The margin in degrees of DEGREE points, fractions kept.
	func degrees() -> float:
		return float(margin) / float(DEGREE)

# The sum of `count` d5*, read both ways.
static func read(rng: RandomNumberGenerator, count: int = DEFAULT_DICE) -> Roll:
	var out := Roll.new()
	for _i: int in range(maxi(count, 0)):
		_read_one(rng, out)
	return out

# A base value plus dice against a fixed difficulty.
static func against(base: int, difficulty: int, rng: RandomNumberGenerator,
		dice: int = DEFAULT_DICE) -> Outcome:
	var dice_roll: Roll = read(rng, dice)
	var out := Outcome.new()
	out.margin = base + dice_roll.total - difficulty
	out.stars = dice_roll.stars
	return out

# Both sides roll, the attacker first, as in `contest`: the margin is the
# attacker's, and each side keeps its own stars.
static func versus(attacker_base: int, defender_base: int, rng: RandomNumberGenerator,
		dice: int = DEFAULT_DICE) -> Outcome:
	var attack: Roll = read(rng, dice)
	var defense: Roll = read(rng, dice)
	var out := Outcome.new()
	out.margin = (attacker_base + attack.total) - (defender_base + defense.total)
	out.stars = attack.stars
	out.foe_stars = defense.stars
	return out

# One d5* into `into`: the same draws as `_roll`, walked as a loop, with the direction
# of the chain kept so a 5 knows whether it adds.
static func _read_one(rng: RandomNumberGenerator, into: Roll) -> void:
	var direction: int = 1
	for depth: int in MAX_CHAIN + 1:
		var face: int = rng.randi_range(MIN_FACE, MAX_FACE)
		if depth >= MAX_CHAIN:
			into.total += direction * face
			return
		if face == MAX_FACE:
			into.total += direction * MAX_FACE
			if direction > 0:
				into.stars += 1
		elif face == MIN_FACE:
			direction = -direction
		else:
			into.total += direction * face
			return
