extends Loader
class_name SceneLoader

func extensions() -> Array[String]:
	return ["tscn", "scn"]

func load_resource(path: String) -> Variant:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene
