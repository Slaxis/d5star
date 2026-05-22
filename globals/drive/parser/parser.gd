# Base JSON parser: builds Resources via hooks and attribute injection.
class_name Parser
extends RefCounted

func _create_resource() -> Resource:
	return null

func _post_process(_resource: Resource, _data: Dictionary) -> void:
	pass

func _allow_list() -> Array[String]:
	return []

func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.log(self, "error", "Failed to open JSON: " + path)
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		Log.log(self, "error", "Failed to parse JSON: " + path)
		return {}
	if parsed is Dictionary:
		return parsed
	Log.log(self, "error", "JSON root must be an object: " + path)
	return {}

func _extract_attributes(data: Dictionary) -> Dictionary:
	return data

func _property_info(target: Object) -> Dictionary:
	var info: Dictionary = {}
	for entry: Dictionary in target.get_property_list():
		var prop_name: String = String(entry.get("name", ""))
		if prop_name != "":
			info[prop_name] = {
				"type": int(entry.get("type", TYPE_NIL)),
				"hint": int(entry.get("hint", 0)),
				"hint_string": String(entry.get("hint_string", ""))
			}
	return info

func _coerce(value: Variant, type_id: int, _hint: int, _hint_string: String) -> Variant:
	match type_id:
		TYPE_FLOAT:
			if value is int:
				return float(value)
		TYPE_INT:
			if value is float:
				return int(value)
		TYPE_VECTOR2:
			if value is Array and (value as Array).size() >= 2:
				return Vector2(float((value as Array)[0]), float((value as Array)[1]))
			elif value is Dictionary:
				var d: Dictionary = value
				return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
		TYPE_COLOR:
			if value is String:
				return Color.from_string(value, Color.WHITE)
	return value

func _apply_attrs(target: Object, attrs_dict: Dictionary, allowed_keys: Array[String] = []) -> void:
	if target == null or attrs_dict.is_empty():
		return
	var allowed: Dictionary = {}
	for key: String in allowed_keys:
		allowed[key] = true
	var prop_info: Dictionary = _property_info(target)
	for key: Variant in attrs_dict.keys():
		var key_str: String = String(key)
		if not allowed.is_empty() and not allowed.has(key_str):
			continue
		if not prop_info.has(key_str):
			continue
		var info: Dictionary = prop_info[key_str]
		var type_id: int = int(info.get("type", TYPE_NIL))
		var hint: int = int(info.get("hint", 0))
		var hint_string: String = String(info.get("hint_string", ""))
		var value: Variant = attrs_dict[key]
		if type_id == TYPE_STRING and value is String:
			value = (value as String).strip_edges()
		else:
			value = _coerce(value, type_id, hint, hint_string)
		target.set(key_str, value)

func parse(path: String) -> Resource:
	var data: Dictionary = _read_json(path)
	var attrs: Dictionary = _extract_attributes(data)
	var resource: Resource = _create_resource()
	if resource == null:
		return null
	_apply_attrs(resource, attrs, _allow_list())
	_post_process(resource, data)
	return resource
