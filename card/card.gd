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
	return c

func name_text() -> String:
	return I18n.text(name, id)

func flavor_text() -> String:
	return I18n.text(flavor, "")
