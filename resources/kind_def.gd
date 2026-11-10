# KindDef — a kind of thing, as one table. D5Star infers one for every def a
# Thing names that no script provides, and a script may extend it to give a
# kind more, as the provided Def of that id. Its Things come back as one
# table, id -> row, in the order they were read; a row is the Thing without
# its `id`. A module overrides a thing by shipping one with the same id, which
# keeps its place, and adds one with a new id, which goes at the end.
class_name KindDef
extends Def

var _things: Dictionary = {}    # id -> the Thing as read, in the order read

# A KindDef holds Things only, so it keeps Def's `load_data`, which complains:
# a JSON beside a script that extends it is a mistake.

func add_thing(thing: Dictionary) -> void:
	_things[String(thing["id"])] = thing

# The ids, in the order of the list.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _things:
		out.append(id)
	return out

# One Thing as read, with its `id`; empty when there is none.
func get_thing(id: String) -> Dictionary:
	return _things.get(id, {})

# The table a game reads: id -> row, in order. `renamed` maps a field of the
# Things to the name the game reads it by, Thing field -> table field, for a
# game that spells a field differently from its Things.
func table(renamed: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for id: String in ids():
		var thing: Dictionary = _things[id]
		var row: Dictionary = {}
		for key: String in thing:
			if key != "id":
				row[String(renamed.get(key, key))] = thing[key]
		out[id] = row.duplicate(true)
	return out
