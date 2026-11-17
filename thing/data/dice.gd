# Dice — the die of a table (J189), a native Thing: the d5* of `D5`, thrown
# `count` times, read for its total, its stars (each 5 that adds) and its zeros
# (each 0 that turns the chain down). A game names its own die as a heir,
# `{ "id": "dice.d5", "count": 2 }` for the 2d5*, and its numbers are
# attributes, so an effect may change them.
#
# Every throw takes the rng it is given, the seeded rng of a match, so the same
# seed throws the same dice.
extends Thing
class_name Dice

# --- Tools ---

## How many dice it throws: 2 for the 2d5*.
func count() -> int:
	return maxi(0, int(attribute("count", D5.DEFAULT_DICE)))

## The points of margin of one degree: 5.
func degree() -> int:
	return maxi(1, int(attribute("degree", D5.DEGREE)))

## One throw: its total, its stars and its zeros.
func throw(rng: RandomNumberGenerator) -> D5.Roll:
	return D5.read(rng, count())

## `base` and a throw against a fixed `difficulty`, which does not throw;
## reaching it exactly is no win.
func against(base: int, difficulty: int, rng: RandomNumberGenerator) -> D5.Outcome:
	var out: D5.Outcome = D5.against(base, difficulty, rng, count())
	out.degree = degree()
	return out

## Both sides throw, the one who acts first: the margin is the actor's, each
## side keeps its stars and its zeros, and a tie goes to who resists.
func versus(actor: int, resister: int, rng: RandomNumberGenerator) -> D5.Outcome:
	var out: D5.Outcome = D5.versus(actor, resister, rng, count())
	out.degree = degree()
	return out
