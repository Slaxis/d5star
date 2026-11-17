# ThingType — the static type/template for a Thing or a Mechanic.
# Resolved from JSON by the ThingCatalog, with `ancestor`-chain
# inheritance applied via ThingVariant.merge before storage.
#
# `kind` decides the base the catalog falls back to when the type has
# no script of its own nor one up its chain:
#   "thing" (default) → Thing
#   "part"            → Mechanic
#
# Both share this Type definition; the difference is solely the
# subclass that materialises an instance from it.
#
# Its mechanics go by id (J204): a Thing plugs each one once, by its name, and
# may give it fields of its own, `"mechanics": {"work": {"dc": 12}}`, which
# merge over the mechanic's data when it plugs in. `plug()` reads one writing
# of `mechanics`, or of `parts`, the key of before, over the ones before it.
extends Resource
class_name ThingType

var type_id: String = ""
var ancestor: String = ""
var script_id: String = ""
var kind: String = "thing"          # "thing" | "part"
var is_abstract: bool = false        # true = template, cannot be instantiated (see ThingCatalog.create)
var data: Dictionary = {}
var mechanics: Array[String] = []    # the ids of the mechanics the catalog plugs into an instance, each once
# The fields the Thing gives each mechanic, by the mechanic's name (J204): the
# writings in order, the ancestors' first, each merged over the mechanic's own
# data when it plugs in, so "+2" works on the mechanic's number.
var parameters: Dictionary = {}      # name -> Array[Dictionary]
# What the Thing's own layers write in `parts` and `mechanics`, in order: the
# catalog plugs them over what the Thing inherits (J204).
var plugs: Array = []
# The data of the Thing's later layers, which a mod writes over it, each
# merged over the data before it when the type is resolved (Mesclar, J188).
var layers: Array[Dictionary] = []

## Plugs over its mechanics what one writing of `mechanics`, or of `parts`,
## says (J204). A list names mechanics, each plugged once, where it first came.
## A map names each with the fields the Thing gives it, `{"work": {"dc": 12}}`:
## a writing over a mechanic already there changes those fields and no other.
## In a map, the symbol of an operation of lists over a list works on the
## names: `{"-": ["work"]}` takes work out, with its fields.
func plug(written: Variant) -> void:
	if written is Array:
		for one: Variant in (written as Array):
			_plug_one(one, null)
	elif written is Dictionary:
		for key: Variant in (written as Dictionary):
			var value: Variant = (written as Dictionary)[key]
			var op: ThingOperator = ThingVariant.operator(String(key))
			if op != null and op.handles_lists() and value is Array:
				_operate(op, value as Array)
			else:
				_plug_one(key, value)

## Starts from the mechanics of `other`, and the fields it gives them: where an
## heir stands before it plugs its own writings.
func plug_from(other: ThingType) -> void:
	mechanics = other.mechanics.duplicate()
	parameters = other.parameters.duplicate(true)

# One mechanic, by its id, plugged unless one of its name is there, and the
# fields given to it, a writing after those before.
func _plug_one(one: Variant, fields: Variant) -> void:
	var id: String = String(one).strip_edges().to_lower()
	if id == "":
		return
	var name: String = Thing.name_of(id)
	if _at(name) < 0:
		mechanics.append(id)
	if fields is Dictionary and not (fields as Dictionary).is_empty():
		var written: Array = parameters.get(name, [])
		written.append((fields as Dictionary).duplicate(true))
		parameters[name] = written

# An operation of lists on the names of the mechanics: what is left plugs in
# the order the operation gives, each once; a name it takes out takes its
# fields with it.
func _operate(op: ThingOperator, items: Array) -> void:
	var names: Array = []
	for id: String in mechanics:
		names.append(Thing.name_of(id))
	var given: Array = []
	var spelled: Dictionary = {}    # name -> the id as the operation wrote it
	for one: Variant in items:
		var id: String = String(one).strip_edges().to_lower()
		if id != "":
			given.append(Thing.name_of(id))
			spelled[Thing.name_of(id)] = id
	var result: Variant = op.join(names, given)
	var kept: Array[String] = []
	var seen: Dictionary = {}
	for one: Variant in (result as Array if result is Array else []):
		var name: String = Thing.name_of(String(one))
		if name == "" or seen.has(name):
			continue
		seen[name] = true
		var at: int = _at(name)
		kept.append(mechanics[at] if at >= 0 else String(spelled.get(name, name)))
	for name: Variant in parameters.keys():
		if not seen.has(name):
			parameters.erase(name)
	mechanics = kept

# Where the mechanic of a name plugs, or -1.
func _at(name: String) -> int:
	for i: int in range(mechanics.size()):
		if Thing.name_of(mechanics[i]) == name:
			return i
	return -1

func attr(key: String, default_value: Variant = null) -> Variant:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return Thing.format_attr(value)

func text(key: String, default_value: String = "") -> String:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return I18n.text(value, default_value)
