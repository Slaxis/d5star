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
