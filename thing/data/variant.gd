# ThingVariant: merges data with operator semantics.
# Operators are injectable via register_operator().
# Prefix "=" escapes literals: "=+courage" -> "+courage" (verbatim).
extends RefCounted
class_name ThingVariant

const OP_ADD := "+"
const OP_SUB := "-"
const OP_MUL := "*"
const OP_DIV := "/"

static var _op_registry: Dictionary = {}

# --- Leaf helpers ---

static func _parse_bool(text: String) -> bool:
	var lowered: String = text.strip_edges().to_lower()
	return lowered == "true" or lowered == "1"

static func _parse_number(text: String) -> Variant:
	var stripped: String = text.strip_edges()
	if stripped.is_valid_float():
		return float(stripped)
	return null

static func _apply_operator(base: Variant, op: String, operand_raw: String) -> Variant:
	var operand_text: String = operand_raw.strip_edges()
	if base is String:
		if op == OP_ADD:
			return String(base) + operand_text
		return operand_text
	if base is bool:
		var operand_bool: bool = _parse_bool(operand_text)
		if op == OP_MUL:
			return bool(base) and operand_bool
		if op == OP_ADD:
			return bool(base) or operand_bool
		return operand_bool
	if base is int or base is float:
		var parsed: Variant = _parse_number(operand_text)
		if parsed == null:
			return base
		var base_value: float = float(base)
		var operand_value: float = float(parsed)
		match op:
			OP_ADD:
				return base_value + operand_value
			OP_SUB:
				return base_value - operand_value
			OP_MUL:
				return base_value * operand_value
			OP_DIV:
				return base_value if operand_value == 0.0 else base_value / operand_value
		return base_value
	var parsed_bool: bool = _parse_bool(operand_text)
	if operand_text.to_lower() == "true" or operand_text.to_lower() == "false":
		return parsed_bool
	var parsed_number: Variant = _parse_number(operand_text)
	if parsed_number != null:
		return parsed_number
	return operand_text

# --- Registry ---

static func _ensure_defaults() -> void:
	if not _op_registry.has(OP_ADD):
		_op_registry[OP_ADD] = func(b: Variant, o: String) -> Variant: return _apply_operator(b, OP_ADD, o)
	if not _op_registry.has(OP_SUB):
		_op_registry[OP_SUB] = func(b: Variant, o: String) -> Variant: return _apply_operator(b, OP_SUB, o)
	if not _op_registry.has(OP_MUL):
		_op_registry[OP_MUL] = func(b: Variant, o: String) -> Variant: return _apply_operator(b, OP_MUL, o)
	if not _op_registry.has(OP_DIV):
		_op_registry[OP_DIV] = func(b: Variant, o: String) -> Variant: return _apply_operator(b, OP_DIV, o)

static func register_operator(op_char: String, fn: Callable) -> void:
	_op_registry[op_char] = fn

static func _operator_char(value: String) -> String:
	_ensure_defaults()
	if value.begins_with("="):
		return ""
	for op: String in _op_registry.keys():
		if value.begins_with(op) and value.length() > op.length():
			return op
	return ""

# --- Merge helpers ---

static func _array_operator(extra: Dictionary) -> String:
	if extra.size() != 1:
		return ""
	var keys: Array = extra.keys()
	if keys.is_empty():
		return ""
	var key: String = String(keys[0])
	if key != OP_ADD and key != OP_MUL:
		return ""
	if not extra.get(key, null) is Array:
		return ""
	return key

static func _merge_array(base: Array, extra: Array) -> Array:
	var merged: Array = []
	for item: Variant in base:
		merged.append(item)
	for item: Variant in extra:
		merged.append(item)
	return merged

static func _merge_array_by_index(base: Array, extra: Array) -> Array:
	var merged: Array = []
	var max_size: int = max(base.size(), extra.size())
	for index: int in range(max_size):
		var base_value: Variant = null
		var extra_value: Variant = null
		if index < base.size():
			base_value = base[index]
		if index < extra.size():
			extra_value = extra[index]
		if index < extra.size():
			merged.append(_merge_value(base_value, extra_value))
		else:
			merged.append(base_value)
	return merged

static func _merge_dict(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	for key: Variant in extra.keys():
		var base_value: Variant = merged.get(key, null)
		merged[key] = _merge_value(base_value, extra[key])
	return merged

static func _merge_value(base: Variant, extra: Variant) -> Variant:
	if extra == null:
		return base
	if extra is Dictionary:
		var op: String = _array_operator(extra as Dictionary)
		if op != "":
			var base_array: Array = [] if not base is Array else base as Array
			var op_values: Array = (extra as Dictionary).get(op, []) as Array
			if op == OP_MUL:
				return _merge_array_by_index(base_array, op_values)
			return _merge_array(base_array, op_values)
		if base is Dictionary:
			return _merge_dict(base as Dictionary, extra as Dictionary)
		return (extra as Dictionary).duplicate(true)
	if extra is Array:
		if base is Array:
			return _merge_array(base as Array, extra as Array)
		return (extra as Array).duplicate(true)
	if extra is String:
		var str_val: String = extra as String
		if str_val.begins_with("="):
			return str_val.substr(1)
		var op_char: String = _operator_char(str_val)
		if op_char != "":
			var operand: String = str_val.substr(op_char.length())
			return (_op_registry[op_char] as Callable).call(base, operand)
	return extra

static func merge(base: Variant, extra: Variant) -> Variant:
	return _merge_value(base, extra)
