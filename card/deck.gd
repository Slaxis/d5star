# Deck — a queryable collection of Cards belonging to the same group.
#
# A Deck is built on demand from Drive's group index: every Thing with
# `group: "card.<deck_id>"` (in any active module's content) becomes
# a member. Drawing pulls N cards weighted by rarity, without
# duplicates. Higher-rarity cards still appear — they're just
# proportionally less likely than commons.
class_name Deck
extends RefCounted

# Relative weights for the draw lottery. Heavier = more likely.
# A common card is 10x as likely to surface as a rare; mythic is the
# "show up once every fifty games" tier.
const RARITY_WEIGHTS: Dictionary = {
	"common":   100,
	"uncommon": 40,
	"rare":     10,
	"mythic":   2,
}

var id: String = ""
var cards: Array[Card] = []

# Build a Deck by scanning every Thing tagged `card.<deck_id>`. The
# active module's content roots (and its dependencies) are walked by
# Drive; modules can freely add cards to existing decks just by
# dropping a Thing with the right group.
static func from_group(deck_id: String) -> Deck:
	var deck := Deck.new()
	deck.id = deck_id
	var things: Array[Dictionary] = Drive.list_json_by_group("card." + deck_id)
	for thing: Dictionary in things:
		deck.cards.append(Card.from_thing(thing))
	return deck

# Build a Deck directly from an array of Cards or Thing dicts.
# Useful for tests + for callers that already have the cards in hand
# and don't want to round-trip through Drive.
static func from_cards(input: Array) -> Deck:
	var deck := Deck.new()
	for entry: Variant in input:
		if entry is Card:
			deck.cards.append(entry)
		elif entry is Dictionary:
			deck.cards.append(Card.from_thing(entry))
	return deck

# Draw `n` cards from the deck, weighted by rarity, without
# replacement. If the deck has fewer than `n` cards, returns whatever
# is available. Pass a seeded RNG for determinism (tests, replays).
func draw(n: int, rng: RandomNumberGenerator = null) -> Array[Card]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var hand: Array[Card] = []
	var pool: Array[Card] = cards.duplicate()
	var to_draw: int = mini(n, pool.size())
	for i: int in to_draw:
		var pick: Card = _weighted_pick(pool, rng)
		if pick == null:
			break
		hand.append(pick)
		pool.erase(pick)
	return hand

# Picks one card from `pool` weighted by rarity. Returns null if the
# pool is empty or every weight resolves to zero.
func _weighted_pick(pool: Array[Card], rng: RandomNumberGenerator) -> Card:
	var total: int = 0
	for c: Card in pool:
		total += _weight_of(c)
	if total <= 0:
		return null
	var roll: int = rng.randi() % total
	var cum: int = 0
	for c: Card in pool:
		cum += _weight_of(c)
		if roll < cum:
			return c
	return pool[-1]    # numerical fallback — shouldn't happen

func _weight_of(c: Card) -> int:
	return int(RARITY_WEIGHTS.get(c.rarity, 100))

func count() -> int:
	return cards.size()

func count_by_rarity(rarity: String) -> int:
	var n: int = 0
	for c: Card in cards:
		if c.rarity == rarity:
			n += 1
	return n

# Lookup a single card by id — useful for restoring a Hand from
# session state (`from_session`).
func find(card_id: String) -> Card:
	for c: Card in cards:
		if c.id == card_id:
			return c
	return null

# Draws `n` cards from the deck under the constraint that no two
# share a `class_affinity` value — at most one card per casta in
# the hand. Useful for the Ancestrais step: with 6 castas in the
# pool and a hand of 5, one casta is randomly excluded each draw,
# but the player always sees five DIFFERENT options instead of
# rolling double-DOMINI and being railroaded.
#
# Algorithm: bucket cards by their first affinity tag, shuffle the
# buckets, take the first `n`, then weighted-rarity-draw 1 card from
# each chosen bucket. Cards without an affinity tag (universal cards)
# are skipped — for those, fall back to the normal `draw()`.
func draw_one_per_class(n: int, rng: RandomNumberGenerator = null) -> Array[Card]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var by_class: Dictionary = {}    # class_id -> Array of cards
	for card: Card in cards:
		if card.class_affinity.is_empty():
			continue
		var key: String = card.class_affinity[0]
		if not by_class.has(key):
			by_class[key] = []
		(by_class[key] as Array).append(card)
	var class_ids: Array = by_class.keys()
	class_ids.shuffle()
	var to_keep: int = mini(n, class_ids.size())
	var result: Array[Card] = []
	for i: int in to_keep:
		var subset_raw: Array = by_class[String(class_ids[i])]
		var subset: Array[Card] = []
		for c: Variant in subset_raw:
			if c is Card:
				subset.append(c)
		var sub_deck := Deck.new()
		sub_deck.id = id
		sub_deck.cards = subset
		var pick: Array[Card] = sub_deck.draw(1, rng)
		if pick.size() > 0:
			result.append(pick[0])
	return result

# Returns a new Deck containing only the cards whose `class_affinity`
# intersects `accepted` (case-sensitive tag match). A card with an
# empty `class_affinity` is treated as UNIVERSAL and always passes
# the filter — letting modules ship "appears for everyone" cards
# without enumerating every class.
#
# The caller composes the `accepted` list against the game's own
# affinity rules (e.g. a Sugar Loaf player DOMINI passes
# ["domini", "clerus", "milites", "exsules"] — own class + pyramid
# allies + the universal EXSULES tag). The engine itself stays
# game-agnostic; the table lives in game/.
func filter_by_affinity(accepted: Array) -> Deck:
	var accepted_set: Dictionary = {}
	for tag: Variant in accepted:
		accepted_set[String(tag)] = true
	var pool: Array[Card] = []
	for card: Card in cards:
		if card.class_affinity.is_empty():
			pool.append(card)
			continue
		for tag: String in card.class_affinity:
			if accepted_set.has(tag):
				pool.append(card)
				break
	var filtered := Deck.new()
	filtered.id = id
	filtered.cards = pool
	return filtered
