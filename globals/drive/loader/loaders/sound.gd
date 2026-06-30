extends Loader
class_name SoundLoader

func extensions() -> Array[String]:
	return ["ogg", "mp3", "wav"]

func load_resource(path: String) -> Variant:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
