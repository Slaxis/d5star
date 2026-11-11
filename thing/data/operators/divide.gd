# DivideOperator: "/". Divides a number: "/2" over 3 is 1.5, and "/0" leaves
# it as it was. Over a text or a yes or no, the operand stands in.
extends ThingOperator
class_name DivideOperator

func _init() -> void:
	on_number(_divide)
	on(TYPE_STRING, operand_as_text)
	on(TYPE_BOOL, operand_as_bool)

func symbol() -> String:
	return "/"

func _divide(base: float, operand: float) -> Variant:
	return base if operand == 0.0 else base / operand
