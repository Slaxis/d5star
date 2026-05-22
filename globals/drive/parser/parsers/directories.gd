# Directories parser: reads "directories" map into Directories.
extends Parser
class_name DirectoriesParser

func _create_resource() -> Resource:
	return Directories.new()

func _post_process(resource: Resource, data: Dictionary) -> void:
	var dirs: Directories = resource as Directories
	if dirs == null:
		return
	var entries: Variant = data.get("directories", {})
	if not entries is Dictionary:
		return
	for dir_id: Variant in (entries as Dictionary).keys():
		var key: String = String(dir_id).strip_edges().to_lower()
		if key == "":
			continue
		var path: String = String((entries as Dictionary).get(dir_id, "")).strip_edges()
		if path == "":
			path = key
		dirs.set_dir(key, path)
