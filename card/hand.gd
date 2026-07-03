# Hand — the typed Selection that holds a draw of cards and the pick.
#
# A Hand is the player's offered choice: N cards drawn from a Deck,
# plus a single `picked` card once the player commits. It extends
# Selection so the entire draw + pick state round-trips through
# `to_session()` / `from_session()` — letting a save reload mid-draw
# without the player losing their offered cards.
class_name Hand
extends Selection

var deck_id: String = ""
var cards: Array[Card] = []
var picked: Card = null

# Convenience constructor: draw `n` cards from the named deck and
# return them in a fresh Hand. Default is 5 — the Sugar Loaf canon
# size that gives each character creation step ~84 distinct possible
# hands from a typical 14-card visible pool. Pass an RNG for
# deterministic draws.
static func draw(group_id: String, n: int = 5, rng: RandomNumberGenerator = null) -> Hand:
	var hand := Hand.new()
	hand.deck_id = group_id
	var deck: Deck = Deck.from_group(group_id).filter_by_edition(Deck.active_edition)
	hand.cards = deck.draw(n, rng)
	return hand

# Constrained constructor: draw `n` cards with at most ONE per
# casta (first `class_affinity` tag). Used by Sugar Loaf for the
# Ancestrais step so the player always sees a spread of distinct
# castas instead of rolling double-DOMINI and having to restart.
# When the deck has more castas than `n`, the excluded ones are
# random per draw — restart is still useful for re-rolling which
# casta gets dropped.
static func draw_one_per_class(group_id: String, n: int = 5, rng: RandomNumberGenerator = null, max_cost: int = -1) -> Hand:
	var hand := Hand.new()
	hand.deck_id = group_id
	var deck: Deck = Deck.from_group(group_id) \
		.filter_by_edition(Deck.active_edition) \
		.filter_by_max_cost(max_cost)
	hand.cards = deck.draw_one_per_class(n, rng)
	return hand

# Filtered constructor: draw `n` cards from a Deck after restricting
# the pool to cards whose `class_affinity` intersects `accepted`. The
# `accepted` list is computed by the caller against its own affinity
# rules (Sugar Loaf maps a player class → its allies + EXSULES via
# `ClassAffinity.for_class()`; another module could plug a different
# table without touching the engine).
static func draw_filtered(group_id: String, n: int, accepted: Array, rng: RandomNumberGenerator = null) -> Hand:
	var hand := Hand.new()
	hand.deck_id = group_id
	var deck: Deck = Deck.from_group(group_id).filter_by_edition(Deck.active_edition)
	var filtered: Deck = deck.filter_by_affinity(accepted)
	hand.cards = filtered.draw(n, rng)
	return hand

# Composite constructor: filter the pool by `accepted` affinities AND
# spread the draw across distinct castas. Used by Sugar Loaf for the
# post-Ancestrais steps (Origem, Mentor) — once the player has picked
# a casta the draw should both (a) hide enemy-pyramid cards and (b)
# keep showing one card per remaining casta so each draw spans the
# allowed colours. With the canonical pyramid 4 castas wide (self +
# 2 allies + EXSULES), `n=5` returns 4 cards — one per allied colour.
static func draw_one_per_allied_class(group_id: String, n: int, accepted: Array, rng: RandomNumberGenerator = null, max_cost: int = -1) -> Hand:
	var hand := Hand.new()
	hand.deck_id = group_id
	var deck: Deck = Deck.from_group(group_id) \
		.filter_by_edition(Deck.active_edition) \
		.filter_by_affinity(accepted) \
		.filter_by_max_cost(max_cost)
	hand.cards = deck.draw_one_per_class(n, rng)
	return hand

# Governança constructor: filter by casta affinity AND by moral
# proximity to the leader. `accepted` = allowed castas (pyramid
# affinity + EXSULES); `moral_center` = leader's morality total;
# `moral_tolerance` = window around center (±1 point per Sugar Loaf
# canon). Draws N random cards from the intersected pool. Each
# governanca deck has 5 cards per casta × 6 castas × 5 morality
# tiers — after both filters, a typical leader sees 8-18 candidates
# and picks 3.
static func draw_class_and_morality(group_id: String, n: int, accepted: Array,
		moral_center: int, moral_tolerance: int,
		rng: RandomNumberGenerator = null) -> Hand:
	var hand := Hand.new()
	hand.deck_id = group_id
	var deck: Deck = Deck.from_group(group_id) \
		.filter_by_edition(Deck.active_edition) \
		.filter_by_affinity(accepted) \
		.filter_by_morality_tier(moral_center - moral_tolerance, moral_center + moral_tolerance)
	hand.cards = deck.draw(n, rng)
	return hand

# Doutrina constructor: filter by obedience proximity to the leader
# WITHOUT a casta filter. Doctrines are universal ideological
# choices — any casta can pick any doctrine, provided it's within
# tolerance of the leader's current obedience position. An anarchist
# leader (obed=-2) with ±1 sees only -2/-1 tier doctrines; a
# hive-mind leader (obed=+2) sees only +1/+2.
static func draw_by_obedience(group_id: String, n: int,
		obed_center: int, obed_tolerance: int,
		rng: RandomNumberGenerator = null) -> Hand:
	var hand := Hand.new()
	hand.deck_id = group_id
	var deck: Deck = Deck.from_group(group_id) \
		.filter_by_edition(Deck.active_edition) \
		.filter_by_obedience_tier(obed_center - obed_tolerance, obed_center + obed_tolerance)
	hand.cards = deck.draw(n, rng)
	return hand

# Economia constructor: filter by the leader's town-center biome
# (set by the travessia pick). Cards with an EMPTY biome_affinity
# are universal and always pass — used for COMÉRCIO/TRIBUTO/PILHAGEM
# style options that make sense anywhere. A coastal leader sees
# PESCA/PIRATARIA/SALINAS + universals; a mountain leader sees
# MINERAÇÃO/CAÇA/CATA-SUCATA + universals.
static func draw_by_biome(group_id: String, n: int, biome_id: String,
		rng: RandomNumberGenerator = null) -> Hand:
	var hand := Hand.new()
	hand.deck_id = group_id
	var deck: Deck = Deck.from_group(group_id) \
		.filter_by_edition(Deck.active_edition) \
		.filter_by_biome(biome_id)
	hand.cards = deck.draw(n, rng)
	return hand

# Commit the player's choice. Out-of-range indices are silent no-ops
# (caller should validate input). Picking twice replaces the choice
# — UI can therefore allow "I changed my mind" before confirming.
func pick(idx: int) -> void:
	if idx < 0 or idx >= cards.size():
		return
	picked = cards[idx]

func is_picked() -> bool:
	return picked != null

func size() -> int:
	return cards.size()

# ─── Memento ─────────────────────────────────────────────────────
# Save only the ids — the cards themselves are reconstructed by
# re-querying the deck on restore. This keeps the snapshot small
# and lets card definitions evolve between save/load.

func to_session() -> Dictionary:
	var ids: Array = []
	for c: Card in cards:
		ids.append(c.id)
	return {
		"deck_id":  deck_id,
		"cards":    ids,
		"picked":   picked.id if picked != null else "",
	}

func from_session(state: Dictionary) -> void:
	deck_id = String(state.get("deck_id", ""))
	cards.clear()
	picked = null
	if deck_id == "":
		return
	var deck: Deck = Deck.from_group(deck_id)
	var card_ids: Variant = state.get("cards", [])
	if card_ids is Array:
		for id: Variant in (card_ids as Array):
			var c: Card = deck.find(String(id))
			if c != null:
				cards.append(c)
	var picked_id: String = String(state.get("picked", ""))
	if picked_id != "":
		for c: Card in cards:
			if c.id == picked_id:
				picked = c
				break
