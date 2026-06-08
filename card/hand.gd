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
	var deck: Deck = Deck.from_group(group_id)
	hand.cards = deck.draw(n, rng)
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
	var deck: Deck = Deck.from_group(group_id)
	var filtered: Deck = deck.filter_by_affinity(accepted)
	hand.cards = filtered.draw(n, rng)
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
