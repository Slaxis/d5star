# MediaHub — thin typed-media facade over Drive. Game code calls
# `God.media.texture(id)` (etc.) and never touches Drive directly.
#
# Stateless: Drive owns the cache, MediaHub just provides the
# game-facing surface. Single audit point for "everything game code
# asks the engine to load". Future home for preload strategies,
# cache policies, or per-type fallbacks if those become needs.
extends RefCounted
class_name MediaHub

# class_name → Script via the project class registry. Used for JSON
# entries like `"class": "GuanabaraMapGen"`.
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

# Bulk scan: every JSON across the active module's content roots.
# Used by ThingCatalog to build its group index; rare from game code.
func all_content() -> Array[Dictionary]:
	return Drive.list_all_content()
