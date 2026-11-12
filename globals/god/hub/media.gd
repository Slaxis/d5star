# MediaHub — typed media for game code, over Drive. Game code calls
# `God.media.texture(id)` (etc.) and never touches Drive directly: the single
# audit point for "everything game code asks the engine to load". Drive owns the
# cache of what it loads.
#
# The hub also paints the sprites (J141). `paint(id, colours)` swaps each key of
# the sprite's chroma for the colour of its name, on the CPU, with the API ready
# for a shader later. A sprite's chroma is the one its Thing names in `chroma`,
# its own or its ancestor's, or else the game's, `chroma` in d5star.json; a game
# with no chroma paints the image as drawn. The chromas and the palettes are
# Things of the game, each born from the `<id>.gd` of a module when it brings
# one, and everything the hub painted or built is kept until the module changes.
extends D5Hub
class_name MediaHub

var _drawn: Dictionary = {}      # sprite id -> its image as drawn, RGBA8
var _painted: Dictionary = {}    # sprite id and colours -> its texture
var _chromas: Dictionary = {}    # id -> Chroma, or null when no module has it
var _palettes: Dictionary = {}   # id -> Palette, or null when no module has it

func on_module_changed(_module_id: String) -> void:
	forget()

# Lets go of everything painted and built: the module changed, or the game is
# leaving and the textures go before the renderer does.
func forget() -> void:
	_drawn.clear()
	_painted.clear()
	_chromas.clear()
	_palettes.clear()

# class_name → Script via the project class registry. Used for JSON
# entries like `"class": "CoastStep"`.
func script(class_name_str: String) -> Script:
	return Drive.script(class_name_str)

func texture(asset_id: String, extension: String = "png") -> Texture2D:
	return Drive.texture(asset_id, extension)

func shader(asset_id: String, extension: String = "gdshader") -> Shader:
	return Drive.shader(asset_id, extension)

func sound(asset_id: String, extension: String = "ogg") -> AudioStream:
	return Drive.sound(asset_id, extension)

func scene(scene_id: String) -> PackedScene:
	return Drive.scene(scene_id)

func json(asset_id: String) -> Dictionary:
	return Drive.json(asset_id)

# --- Painting ---

# The texture of a sprite painted: each key of its chroma takes the colour given
# for its name, `{ "main": colour, ... }`, or the colour of a palette in the key's
# place, by the palette's id. Kept until the module changes; null when the sprite
# has no image.
func paint(asset_id: String, colors: Variant = {}) -> Texture2D:
	var key: String = asset_id + "|" + var_to_str(colors)
	if not _painted.has(key):
		var image: Image = painted(asset_id, colors)
		_painted[key] = ImageTexture.create_from_image(image) if not image.is_empty() else null
	return _painted[key]

# The image of a sprite painted as `paint` paints it, a new one for whoever puts
# it together with others; empty when the sprite has no image.
func painted(asset_id: String, colors: Variant = {}) -> Image:
	var drawn: Image = _drawing(asset_id)
	if drawn.is_empty():
		return Image.new()
	var chroma: Chroma = chroma_of(asset_id)
	if chroma == null:
		return drawn.duplicate() as Image
	return chroma.paint(drawn, colors)

# The chroma a sprite is painted with: the one its Thing names in `chroma`, its
# own or its ancestor's, or else the game's; null when it has none.
func chroma_of(asset_id: String) -> Chroma:
	var type: ThingType = God.things.resolve_type(asset_id) if asset_id != "" else null
	if type != null and type.data.has("chroma"):
		var id: String = String(type.data["chroma"])
		return chroma(id) if id != "" else null
	return game_chroma()

# The game's chroma, the one `chroma` names in d5star.json; null when the game
# has none.
func game_chroma() -> Chroma:
	var id: String = String(Drive.setting("chroma", ""))
	return chroma(id) if id != "" else null

# A chroma by its id, born once per module from the script of its Thing, the
# `<id>.gd` of a module, which extends Chroma, or else from Chroma, with the data
# of its Thing and of its ancestors; null, with an error, when no module has it.
func chroma(chroma_id: String) -> Chroma:
	if not _chromas.has(chroma_id):
		var made: Chroma = null
		var type: ThingType = _type(chroma_id, "chroma")
		if type != null:
			var own: Script = _script_of(type, Chroma)
			made = own.new() if own != null else Chroma.new()
			made._apply_data(type.type_id, type.ancestor, type.data)
		_chromas[chroma_id] = made
	return _chromas[chroma_id]

# A palette by its id, born as a chroma is, from its own script or from Palette;
# null, with an error, when no module has it.
func palette(palette_id: String) -> Palette:
	if not _palettes.has(palette_id):
		var made: Palette = null
		var type: ThingType = _type(palette_id, "palette")
		if type != null:
			var own: Script = _script_of(type, Palette)
			made = own.new() if own != null else Palette.new()
			made._apply_data(type.type_id, type.ancestor, type.data)
		_palettes[palette_id] = made
	return _palettes[palette_id]

# The Thing of a chroma or a palette, with the data of its ancestors; null, with
# an error, when no module has it.
func _type(id: String, what: String) -> ThingType:
	var type: ThingType = God.things.resolve_type(id)
	if type == null:
		Log.log(self, "error", "MediaHub: no %s '%s' in the active modules" % [what, id])
	return type

# The script a Thing has of its own, the one the catalog would build it from,
# when it extends the library's class; null when it has none.
func _script_of(type: ThingType, base: Script) -> Script:
	if type.script_id == "thing" or type.script_id == "thing_part":
		return null
	var own: Script = God.things.script(type.script_id)
	if own != null and _extends(own, base):
		return own
	Log.log(self, "error", "MediaHub: the script of '%s' is no %s" % [type.type_id, base.get_global_name()])
	return null

func _extends(script: Script, base: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == base:
			return true
		var next: Script = current.get_base_script()
		if next == current:
			return false
		current = next
	return false

# The image of a sprite as drawn, RGBA8, kept until the module changes; empty,
# with an error, when no module has it.
func _drawing(asset_id: String) -> Image:
	if not _drawn.has(asset_id):
		var texture: Texture2D = Drive.texture(asset_id)
		var image: Image = texture.get_image() if texture != null else null
		if image == null or image.is_empty():
			Log.log(self, "error", "MediaHub: no image of '%s' in the active modules" % asset_id)
			image = Image.new()
		else:
			image = Chroma.as_rgba8(image)
		_drawn[asset_id] = image
	return _drawn[asset_id]
