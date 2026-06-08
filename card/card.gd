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
var rarity: String = "common"
var name: Variant = ""       # String or i18n dict {pt, en}
var flavor: Variant = ""     # String or i18n dict
var art_id: String = ""
var payload: Dictionary = {}

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
	c.rarity = String(data_dict.get("rarity", "common"))
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
