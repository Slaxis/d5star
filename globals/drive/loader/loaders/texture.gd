extends Loader
class_name TextureLoader

func extensions() -> Array[String]:
	return ["png", "jpg", "jpeg", "webp"]

func load_resource(path: String) -> Variant:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# A mod's image sits in the user's folder, where Godot imports nothing, and
	# Godot loads no image it did not import: it is read as an image file. The
	# game's own images are always imported, so none of res:// is read here.
	if path.begins_with("res://") or not FileAccess.file_exists(path):
		return null
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
