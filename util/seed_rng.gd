# Seeded RNG helpers. Pure engine util — no game-specific logic.
#
# Use `SeedRng.make_rng(SeedRng.seed_from_string("my_seed"))` to get a
# deterministic RandomNumberGenerator. Derive sub-seeds with `derive`
# so different systems (teams, map, rosters) don't collide under the
# same base seed.
class_name SeedRng

static func seed_from_string(s: String) -> int:
	# Godot's String.hash() returns a deterministic 32-bit value,
	# fine as an RNG seed. Xor with length so two near-identical inputs
	# (e.g., "Lalala" vs "lalala" after casing fixes elsewhere) diverge.
	return String(s).hash() ^ s.length()

static func make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

static func derive(base_seed: int, salt: String) -> int:
	# Mix a textual salt with the base seed so callers can spawn
	# independent RNG streams (teams, map, rosters) from one career seed.
	return base_seed ^ seed_from_string(salt)
