extends Loader
class_name ShaderLoader

func extensions() -> Array[String]:
	return ["gdshader"]

func load_resource(path: String) -> Variant:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Shader
