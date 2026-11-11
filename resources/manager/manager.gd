# D5Manager: base class for all Drive managers.
@abstract
extends Resource
class_name D5Manager

# Its key in the Drive: each manager returns its own `ID`.
@abstract func manager_id() -> String

# The active module changed: its id, the content roots of it and of the
# modules it requires, highest priority first, and its own folder. The
# ModuleManager tells every manager of the Drive; one that keeps something of
# the module overrides this, and the others keep nothing.
func on_module_changed(_module_id: String, _content_roots: Array[String], _module_root: String) -> void:
	pass

func _key(id: String) -> String:
	return String(id).strip_edges().to_lower()
