# Def: abstract base for all game definitions.
# A Def knows how to interpret raw JSON into typed, query-ready data.
extends Resource
class_name Def

var def_id: String = ""

func load_data(_raw: Dictionary) -> void:
	push_error("Def.load_data() not overridden in " + get_script().resource_path)

func merge_data(raw: Dictionary) -> void:
	load_data(raw)

func _key(value: String) -> String:
	return String(value).strip_edges().to_lower()
