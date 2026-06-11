# Card — a single card that belongs to a Deck.
#
# A card is a Thing (`group: "card.<deck_id>"`) plus a small piece of
# card-specific metadata (rarity, name/flavor, art id) and a payload
# Dictionary that the caller applies when the card is picked. The
# engine does NOT interpret the payload — callers (game / module
# code) decide what fields they expect, so different decks can carry
# wildly different mechanics through the same plumbing.
#
# Card itself is a thin typed wrapper around the Thing dictionary; the
# heavy lifting (lookup, draw, persistence) lives in Deck and Hand.
class_name Card
extends RefCounted

const _DECK_GROUP_PREFIX: String = "card."

var id: String = ""
var deck_id: String = ""
var rarity: String = "comum"
var tier: int = 1            # power-tier band 1..5; orthogonal to rarity
var cost: int = 1            # resource cost to play / pick (Fibonacci default)
var name: Variant = ""       # String or i18n dict {pt, en}
var flavor: Variant = ""     # String or i18n dict
var art_id: String = ""
var payload: Dictionary = {}

# Flaw level — 0..5 commitment to pre-declared weaknesses. F0 =
# pristine, F5 = maximally compromised. Used by the game's
# CardEconomy to compute extra PP budget on COMUM/ELITE (zero on
# higher rarities). Engine just preserves the field; the math
# lives in `game/defs/card_economy.gd`.
var flaw_level: int = 0

# Edition tag — release identifier for cards. The current canonical
# Sugar Loaf cards (the alpha exploration set) are tagged "alpha";
# the 1st-edition canon set is "prime"; future expansions get their
# own slug ("reflorestamento", "trovao_verde", etc.). The game layer
# filters by active edition; engine just preserves the field.
var edition: String = "alpha"

# Fibonacci power-budget grid: cost[rarity][tier-1]. Legacy default
# for alpha-edition cards that don't carry an explicit `data.cost`
# field. The prime edition uses CardEconomy.omega_cost(rarity, tier)
# instead (base_cost + size_tax), but card.gd stays generic — the
# economy is a game-layer concern.
const _FIBONACCI_COST_GRID: Dictionary = {
	"comum":   [1, 2,  3,  5,  8],
	"elite":   [2, 3,  5,  8, 13],
	"super":   [3, 5,  8, 13, 21],
	"mito":    [5, 8, 13, 21, 34],
	"divino":  [8, 13, 21, 34, 55],
}

# Backward-compat aliases for the legacy English rarity strings
# used by the alpha-edition cards. Translated at parse time so the
# rest of the engine + game only ever sees the canonical PT-BR
# rarity slugs.
const _RARITY_ALIASES: Dictionary = {
	"common":    "comum",
	"uncommon":  "elite",
	"rare":      "super",
	"mythic":    "mito",
	"legendary": "divino",
	"divine":    "divino",
}

# Affinity tags — the card appears in any draw pool whose accepted
# affinities intersect this list. An empty list means UNIVERSAL —
# the card surfaces for every player regardless of class filter
# (Deck.filter_by_affinity treats `[]` as always-pass).
var class_affinity: Array[String] = []

# Optional flavor accent — when set, the card visually carries an
# emblem from this class even though it lives in a different deck.
# Used by EXSULES-tagged "atravessador" cards that were exiled from
# their original casta (e.g. an EXSULES mentor with origin_class
# = "domini" reads as "a DOMINI that was cuspido pelo cabal").
var origin_class: String = ""

# Meta-progression gate. `"starter"` cards are visible to everyone
# from day one; other values (`"achievement:<id>"`, `"campaign:<id>"`,
# `"event:<id>"`, `"secret"`) are unlocked over a long-running player
# session as the player progresses. Filtering by unlocks is the
# caller's responsibility — engine just preserves the field.
var unlock: String = "starter"

# Build a Card from a Thing JSON Dictionary as scanned by Drive. The
# Thing must declare `group: "card.<deck_id>"`; the deck id is
# derived by stripping the prefix.
static func from_thing(thing: Dictionary) -> Card:
	var c := Card.new()
	c.id = String(thing.get("id", ""))
	var group: String = String(thing.get("group", ""))
	if group.begins_with(_DECK_GROUP_PREFIX):
		c.deck_id = group.substr(_DECK_GROUP_PREFIX.length())
	var data: Variant = thing.get("data", {})
	if not data is Dictionary:
		return c
	var data_dict: Dictionary = data
	var raw_rarity: String = String(data_dict.get("rarity", "comum"))
	c.rarity = String(_RARITY_ALIASES.get(raw_rarity, raw_rarity))
	c.tier = int(data_dict.get("tier", 1))
	c.flaw_level = int(data_dict.get("flaw_level", 0))
	c.edition = String(data_dict.get("edition", "alpha"))
	c.cost = int(data_dict.get("cost", _fibonacci_cost(c.rarity, c.tier)))
	var card_meta: Variant = data_dict.get("card", {})
	if card_meta is Dictionary:
		var meta: Dictionary = card_meta
		c.name = meta.get("name", c.id)
		c.flavor = meta.get("flavor", "")
		c.art_id = String(meta.get("art_id", c.id))
	var payload_data: Variant = data_dict.get("payload", {})
	if payload_data is Dictionary:
		c.payload = payload_data
	var affinity_data: Variant = data_dict.get("class_affinity", [])
	if affinity_data is Array:
		for tag: Variant in (affinity_data as Array):
			c.class_affinity.append(String(tag))
	c.origin_class = String(data_dict.get("origin_class", ""))
	c.unlock = String(data_dict.get("unlock", "starter"))
	return c

func name_text() -> String:
	return I18n.text(name, id)

func flavor_text() -> String:
	return I18n.text(flavor, "")

# Look up the Fibonacci default cost for a given (rarity, tier). Used
# by `from_thing` when the Thing doesn't carry an explicit `cost` —
# the same grid is also referenced by gameplay code that needs to
# compute "what would this cost in HeP / mana / etc.".
static func _fibonacci_cost(card_rarity: String, card_tier: int) -> int:
	var grid: Array = _FIBONACCI_COST_GRID.get(card_rarity, [1])
	var idx: int = clampi(card_tier - 1, 0, grid.size() - 1)
	return int(grid[idx])
