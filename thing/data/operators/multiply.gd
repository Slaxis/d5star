# MultiplyOperator: "*". Multiplies a number, and keeps a yes only if the
# operand is a yes too (and): "*3" over 2 is 6. Over a text, the operand
# stands in. A list, {"*": [...]}, merges place by place: each place given
# merges over the inherited one, and the places it does not give stay.
extends ThingOperator
class_name MultiplyOperator

func _init() -> void:
	on_number(_multiply)
	on(TYPE_STRING, operand_as_text)
	on(TYPE_BOOL, _both)
	on_list(_place_by_place)

func symbol() -> String:
	return "*"

func _multiply(base: float, operand: float) -> Variant:
	return base * operand

func _both(base: bool, operand: String) -> Variant:
	return base and as_bool(operand)

func _place_by_place(base: Array, items: Array) -> Array:
	var merged: Array = []
	for index: int in range(maxi(base.size(), items.size())):
		var inherited: Variant = base[index] if index < base.size() else null
		if index < items.size():
			merged.append(ThingVariant.merge(inherited, items[index]))
		else:
			merged.append(inherited)
	return merged
