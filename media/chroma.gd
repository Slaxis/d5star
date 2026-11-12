# Chroma — the key colours a game draws its sprites with: how many, the name of
# each and its RGB. Painting swaps each key for the colour of its name, and a
# pixel that is no key stays as drawn. One game recolours with a single tone,
# another with three named `main`, `mid` and `hi`, another with eight for an
# artist of its own: the library knows none of them (J141).
#
# A chroma is a Thing of the game, in the list of whatever kind the game names:
#
#   { "id": "two_tone", "def": "chromas", "keys": { "main": "#ffffff", "second": "#808080" } }
#
# Its keys may come from a palette instead, `"keys": "nes_day"`, in the order of
# the palette, and painting with another palette then swaps them by position, as
# the indexed mode of Aseprite does. A chroma that names a `palette` takes only
# its colours, by name or by value, the way of Caves of Qud: a colour outside it
# is an error in the log, and paints all the same. With no palette any colour
# goes, as the RGB mode does. Any other key of its data is the game's.
#
# A module that brings `<id>.gd` beside it, extending Chroma, paints its own way:
# `paint` is the method to override. `God.media.chroma(id)` builds a chroma.
class_name Chroma
extends Thing

var _keys: Dictionary = {}
var _read: bool = false

# The keys, in order: each name with the colour the sprites are drawn with.
func keys() -> Dictionary:
	if not _read:
		_read = true
		_keys = _read_keys()
	return _keys

# The palette whose colours this chroma takes; null when it takes any colour.
func palette() -> Palette:
	var id: String = String(data.get("palette", ""))
	return God.media.palette(id) if id != "" else null

# The colour each key takes, from the colours given: a Dictionary of a key's name
# and its colour, a Color, a "#rrggbb" or the name of a colour of the chroma's
# palette; or the id of a palette, whose colours the keys take by position. A key
# given no colour, and a name that is no key, paint nothing.
func colors_for(given: Variant) -> Dictionary:
	var own: Palette = palette()
	var picked: Dictionary = {}
	if given is String or given is StringName:
		var names: Array = keys().keys()
		var other: Palette = God.media.palette(String(given))
		var by_place: Array = other.colors().values() if other != null else []
		for i: int in mini(names.size(), by_place.size()):
			picked[names[i]] = by_place[i]
	elif given is Dictionary:
		for name: Variant in given:
			if keys().has(String(name)):
				var color: Variant = _color(given[name], own)
				if color is Color:
					picked[String(name)] = color
	else:
		Log.log(self, "error", "Chroma '%s': the colours come as a Dictionary or as the id of a palette, not as %s"
			% [thing_id, type_string(typeof(given))])
	if own != null:
		for name: String in picked:
			if not own.holds(picked[name]):
				Log.log(self, "error", "Chroma '%s': the colour #%s of '%s' is outside its palette '%s'"
					% [thing_id, (picked[name] as Color).to_html(), name, own.thing_id])
	return picked

# The drawing painted, in a new image of its size: each pixel of a key's colour
# takes the colour given for its name, with the alpha it was drawn with, and any
# other pixel stays as drawn.
func paint(drawn: Image, given: Variant) -> Image:
	var image: Image = Chroma.as_rgba8(drawn)
	# A pixel is read as one int, its bytes R, G, B and A from the lowest, as they
	# sit in memory on the platforms Godot runs on.
	var swap: Dictionary = {}   # the RGB of a key -> the RGB and alpha of its colour
	var colors: Dictionary = colors_for(given)
	for name: String in colors:
		var color: Color = colors[name]
		swap[_rgb(keys()[name])] = _rgb(color) | (color.a8 << 24)
	var pixels: PackedInt32Array = image.get_data().to_int32_array()
	if not swap.is_empty():
		for i: int in pixels.size():
			var pixel: int = pixels[i]
			var alpha: int = (pixel >> 24) & 0xff
			if alpha == 0:
				continue
			var color: int = swap.get(pixel & 0xffffff, -1)
			if color < 0:
				continue
			pixels[i] = (color & 0xffffff) | ((((color >> 24) * alpha + 127) / 255) << 24)
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8,
		pixels.to_byte_array())

# An image as `paint` reads it, RGBA8 with no mipmaps: the image itself when it
# is one already, otherwise a copy made into one.
static func as_rgba8(image: Image) -> Image:
	if image.get_format() == Image.FORMAT_RGBA8 and not image.has_mipmaps():
		return image
	var copy: Image = image.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.clear_mipmaps()
	copy.convert(Image.FORMAT_RGBA8)
	return copy

func _read_keys() -> Dictionary:
	var raw: Variant = data.get("keys", {})
	if raw is String or raw is StringName:
		var source: Palette = God.media.palette(String(raw))
		return source.colors() if source != null else {}
	var found: Dictionary = {}
	if not raw is Dictionary:
		Log.log(self, "error", "Chroma '%s': its keys are a Dictionary of names and colours, or the id of a palette"
			% thing_id)
		return found
	for name: Variant in raw:
		var color: Variant = Palette.parse(raw[name])
		if color is Color:
			found[String(name)] = color
		else:
			Log.log(self, "error", "Chroma '%s': the key '%s' is no colour: %s" % [thing_id, name, str(raw[name])])
	return found

# A colour given: a Color, the name of a colour of the palette, or a "#rrggbb".
func _color(value: Variant, own: Palette) -> Variant:
	if value is Color:
		return value
	var text: String = str(value)
	if own != null and own.colors().has(text):
		return own.colors()[text]
	var parsed: Variant = Palette.parse(text)
	if parsed == null:
		Log.log(self, "error", "Chroma '%s': no colour '%s'" % [thing_id, text])
	return parsed

# The RGB of a colour as a pixel holds it in memory.
static func _rgb(color: Color) -> int:
	return color.r8 | (color.g8 << 8) | (color.b8 << 16)
