# Type Object for Things: resolved data + parts, independent of runtime.
extends Resource
class_name ThingType

var type_id: String = ""
var ancestor: String = ""
var script_id: String = ""
var data: Dictionary = {}
var parts: Array[String] = []

func attr(key: String, default_value: Variant = null) -> Variant:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return ThingCore.format_attr(value)

func text(key: String, default_value: String = "") -> String:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return I18n.text(value, default_value)
