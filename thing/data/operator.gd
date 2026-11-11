# ThingOperator: one operation of the merge, by its symbol, such as "+" in
# "+1", which adds 1 to an inherited 2. ThingVariant finds the operation a
# text opens with and calls it, and names none: each operation is a script of
# its own, in the folder Drive reads at boot (`operators` in engine.json), so
# a new operation is a new script there, or one a mod hands to
# `ThingVariant.register_operator`.
#
# What an operation does depends on the type of the inherited value, not of
# the Thing: a table of one function per type, `on(type, fn)`, each taking
# the inherited value and the operand, the text after the symbol, stripped. A
# type missing from the table takes the operand as a value of its own
# (`read`). So a new type enters from outside,
# `ThingVariant.operator("+").on(TYPE_X, fn)`, without touching the
# operation. An operation may also take a list, {"+": [...]}: `on_list(fn)`.
@abstract
extends RefCounted
class_name ThingOperator

var _on_type: Dictionary = {}  # Variant.Type -> Callable(base: Variant, operand: String) -> Variant
var _on_list: Callable = Callable()

# The symbol that opens a text: "+" in "+1".
@abstract func symbol() -> String

# What the operation does to an inherited value of this type.
func on(type: Variant.Type, fn: Callable) -> ThingOperator:
	_on_type[type] = fn
	return self

# The type leaves the table, and its values take the operand as it reads.
func off(type: Variant.Type) -> ThingOperator:
	_on_type.erase(type)
	return self

# What the operation does to a number, an int or a float: fn(base: float,
# operand: float). An operand that is no number leaves the value as it was.
func on_number(fn: Callable) -> ThingOperator:
	var number: Callable = func(base: Variant, operand: String) -> Variant:
		if not operand.is_valid_float():
			return base
		return fn.call(float(base), float(operand))
	on(TYPE_INT, number)
	on(TYPE_FLOAT, number)
	return self

# What the operation does to a list, {"+": [...]}: fn(base: Array,
# items: Array) -> Array, a new list.
func on_list(fn: Callable) -> ThingOperator:
	_on_list = fn
	return self

func handles_lists() -> bool:
	return _on_list.is_valid()

# The operation on an inherited value, with the text after its symbol.
func apply(base: Variant, operand: String) -> Variant:
	var text: String = operand.strip_edges()
	var fn: Callable = _on_type.get(typeof(base), Callable())
	if fn.is_valid():
		return fn.call(base, text)
	return read(text)

# The operation on an inherited list, with the list given.
func join(base: Array, items: Array) -> Array:
	return _on_list.call(base, items)

# For the tables of the operations: the operand stands in for the inherited
# value, as a text, or as a yes or no.
func operand_as_text(_base: Variant, operand: String) -> Variant:
	return operand

func operand_as_bool(_base: Variant, operand: String) -> Variant:
	return as_bool(operand)

# An operand as a value of its own: a yes or no, a number, or the text.
static func read(operand: String) -> Variant:
	var lowered: String = operand.to_lower()
	if lowered == "true" or lowered == "false":
		return lowered == "true"
	if operand.is_valid_float():
		return float(operand)
	return operand

# An operand as a yes or no: "true" and "1" are yes.
static func as_bool(operand: String) -> bool:
	var lowered: String = operand.to_lower()
	return lowered == "true" or lowered == "1"
