# AddOperator: "+". Adds to a number, appends to a text, and turns a no into
# a yes (or): "+1" over 2 is 3, and "+clad" over "iron" is "ironclad". A
# list, {"+": [...]}, goes after the inherited one.
extends ThingOperator
class_name AddOperator

func _init() -> void:
	on_number(_add)
	on(TYPE_STRING, _append)
	on(TYPE_BOOL, _either)
	on_list(_join)

func symbol() -> String:
	return "+"

func _add(base: float, operand: float) -> Variant:
	return base + operand

func _append(base: String, operand: String) -> Variant:
	return base + operand

func _either(base: bool, operand: String) -> Variant:
	return base or as_bool(operand)

func _join(base: Array, items: Array) -> Array:
	var joined: Array = []
	joined.append_array(base)
	joined.append_array(items)
	return joined
