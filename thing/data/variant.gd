# ThingVariant: the merge of data over the data it inherits, a Thing's over
# its ancestor's and a part's over its own. ThingCatalog and DefManager call
# it before the data is stored.
#
# It walks the data: a dictionary over a dictionary merges key by key, a list
# over a list joins it, and any other value stands in for the inherited one,
# unless it is a text that opens with the symbol of an operation, which works
# on the inherited value: "+1" over 2 is 3. A dictionary of one key, the
# symbol of an operation that takes lists, over a list is that operation:
# {"+": [...]}. A text that opens with "=" is the text after it, verbatim:
# "=+10" is "+10".
#
# The operations are ThingOperators, kept by their symbol, and ThingVariant
# names none: Drive registers the scripts of their folder at boot, and a mod
# may register one of its own. A text takes the longest symbol it opens with
# that leaves an operand after it, so a "+>" is never read as a "+".
extends RefCounted
class_name ThingVariant

const ESCAPE := "="

static var _operators: Dictionary = {}  # symbol -> ThingOperator

# The operation joins the merge, or takes the place of the one with its symbol.
static func register_operator(op: ThingOperator) -> void:
	if op == null or op.symbol() == "":
		return
	_operators[op.symbol()] = op

# The operation leaves the merge, and its symbol is text again.
static func unregister_operator(symbol: String) -> void:
	_operators.erase(symbol)

# The operation of a symbol, or null.
static func operator(symbol: String) -> ThingOperator:
	return _operators.get(symbol, null)

# The symbols of the operations, in the order they were registered.
static func symbols() -> Array[String]:
	var out: Array[String] = []
	for symbol: String in _operators.keys():
		out.append(symbol)
	return out

# The data given over the data inherited.
static func merge(base: Variant, extra: Variant) -> Variant:
	if extra == null:
		return base
	if extra is Dictionary:
		var list_op: ThingOperator = _list_operator(extra as Dictionary)
		if list_op != null:
			var items: Array = (extra as Dictionary).get(list_op.symbol(), []) as Array
			return list_op.join(base as Array if base is Array else [], items)
		if base is Dictionary:
			return _merge_dict(base as Dictionary, extra as Dictionary)
		return (extra as Dictionary).duplicate(true)
	if extra is Array:
		if base is Array:
			return _join(base as Array, extra as Array)
		return (extra as Array).duplicate(true)
	if extra is String:
		var text: String = extra as String
		if text.begins_with(ESCAPE):
			return text.substr(ESCAPE.length())
		var op: ThingOperator = _operator_of(text)
		if op != null:
			return op.apply(base, text.substr(op.symbol().length()))
	return extra

# The operation a text opens with: of the symbols it opens with that leave an
# operand after them, the longest. Null if there is none.
static func _operator_of(text: String) -> ThingOperator:
	var best: String = ""
	for symbol: String in _operators.keys():
		if symbol.length() > best.length() and text.length() > symbol.length() and text.begins_with(symbol):
			best = symbol
	if best == "":
		return null
	return _operators[best]

# A dictionary of one key, the symbol of an operation that takes lists, over
# a list: {"+": [...]}. Null for any other dictionary.
static func _list_operator(extra: Dictionary) -> ThingOperator:
	if extra.size() != 1:
		return null
	var key: String = String(extra.keys()[0])
	if not extra.get(key, null) is Array:
		return null
	var op: ThingOperator = operator(key)
	if op == null or not op.handles_lists():
		return null
	return op

static func _merge_dict(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	for key: Variant in extra.keys():
		merged[key] = merge(merged.get(key, null), extra[key])
	return merged

static func _join(base: Array, items: Array) -> Array:
	var joined: Array = []
	joined.append_array(base)
	joined.append_array(items)
	return joined
