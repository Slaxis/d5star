# Palette — a list of colours with names, in order:
#
#   { "id": "nes_day", "def": "palettes", "colors": { "sky": "#5c94fc", "brick": "#c84c0c" } }
#
# A chroma may take its keys from a palette, in its order, and painting with
# another palette then swaps them by position, as the indexed mode of Aseprite
# does; a chroma that names a palette takes only its colours, the way of Caves of
# Qud. A game has as many palettes as it wants, or none (J141).
#
# A module that brings `<id>.gd` beside it, extending Palette, makes its colours
# its own way: `colors` is the method to override. `God.media.palette(id)` builds
# a palette.
class_name Palette
extends Thing

var _colors: Dictionary = {}
var _values: Dictionary = {}   # the RGBA of each colour, to know one
var _read: bool = false

# The colours, in order: each name with its colour.
func colors() -> Dictionary:
	if not _read:
		_read = true
		_colors = _read_colors()
	return _colors

# Whether a colour of the palette is this one.
func holds(color: Color) -> bool:
	if _values.is_empty():
		for each: Color in colors().values():
			_values[each.to_rgba32()] = true
	return _values.has(color.to_rgba32())

# A colour as the data writes it, "#rrggbb", "rrggbb" or either with its alpha,
# or a Color; null when it is none.
static func parse(value: Variant) -> Variant:
	if value is Color:
		return value
	if value is String or value is StringName:
		var text: String = String(value)
		if Color.html_is_valid(text):
			return Color.html(text)
	return null

func _read_colors() -> Dictionary:
	var raw: Variant = data.get("colors", {})
	var found: Dictionary = {}
	if not raw is Dictionary:
		Log.log(self, "error", "Palette '%s': its colours are a Dictionary of names and colours" % thing_id)
		return found
	for name: Variant in raw:
		var color: Variant = parse(raw[name])
		if color is Color:
			found[String(name)] = color
		else:
			Log.log(self, "error", "Palette '%s': '%s' is no colour: %s" % [thing_id, name, str(raw[name])])
	return found
