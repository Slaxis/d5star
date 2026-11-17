# SubtractOperator: "-". Takes from a number: "-0.5" over 2 is 1.5. Over a
# text or a yes or no, the operand stands in. With nothing inherited, "-5" is
# 5, not -5: the sign is read as the operation. A list, {"-": [...]}, loses
# each item given, every time it comes, and keeps the rest in its order
# (J204): `"parts": {"-": ["shelter"]}` takes one part out and leaves the others.
extends ThingOperator
class_name SubtractOperator

func _init() -> void:
	on_number(_subtract)
	on(TYPE_STRING, operand_as_text)
	on(TYPE_BOOL, operand_as_bool)
	on_list(_without)

func symbol() -> String:
	return "-"

func _subtract(base: float, operand: float) -> Variant:
	return base - operand

func _without(base: Array, items: Array) -> Array:
	var kept: Array = []
	for one: Variant in base:
		if not items.has(one):
			kept.append(one)
	return kept
