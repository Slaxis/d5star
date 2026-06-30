extends Loader
class_name TextureLoader

func extensions() -> Array[String]:
	return ["png", "jpg", "jpeg", "webp"]

func load_resource(path: String) -> Variant:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
