extends Loader
class_name ScriptLoader

func extensions() -> Array[String]:
	return ["gd"]

func load_resource(path: String) -> Variant:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Script
