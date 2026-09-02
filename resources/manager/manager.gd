# D5Manager: base class for all Drive managers.
extends Resource
class_name D5Manager

func manager_id() -> String:
	push_error("D5Manager.manager_id() not overridden in " + get_script().resource_path)
	return ""

func _key(id: String) -> String:
	return String(id).strip_edges().to_lower()
