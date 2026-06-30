# JSON returns Dictionary (not a Resource). Godot's load() doesn't
# parse .json into a Dictionary, so this loader reads + parses
# directly — the only Loader that bypasses load(). Kept here so the
# bypass is encapsulated in one place.
extends Loader
class_name JsonLoader

func extensions() -> Array[String]:
	return ["json"]

func load_resource(path: String) -> Variant:
	if path == "":
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.log(self, "error", "JsonLoader: failed to open " + path)
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		Log.log(self, "error", "JsonLoader: failed to parse " + path)
		return {}
	if parsed is Dictionary:
		return parsed
	Log.log(self, "error", "JsonLoader: root must be an object: " + path)
	return {}
