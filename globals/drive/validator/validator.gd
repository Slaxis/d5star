# Validator — base for pluggable cross-ref validators. Each concrete
# subclass walks the content graph and flags broken id references
# (typos, missing files, wrong kind, etc.).
#
# ValidatorManager auto-discovers validators from the loaders-style
# folder at boot; adding a new check = drop a new subclass here.
#
# The validators of the library know `ancestor`, `parts`, `class` and the
# script of each Thing. The fields a game's Things use to name other Things,
# a biome, a stat, a class, the game declares in data, Things of the def
# `ref`, and RefsValidator checks them (see Refs).
#
# Runs at end of every module switch — output goes to Log as warnings
# so a broken ref doesn't fail boot but is impossible to miss.
@abstract
class_name Validator
extends RefCounted

# Return an array of issue messages (one per broken ref). Empty means
# the check passed. The `hub` gives access to ThingCatalog queries;
# Drive.list_all_content() gives the full raw JSON set.
@abstract func validate(hub: ThingHub) -> Array[String]

# The Things of the content by name, the last read of each: the id of a Thing
# of the format of before, or the name in an id of the format of J188,
# `<parent>.<name>`. A Thing that is only an id counts when its id says its
# parent, as DefManager reads it, and a patch only when no other Thing has its
# name: it changes a Thing, it does not say what the Thing is.
static func things_by_name(all_content: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for raw: Dictionary in all_content:
		var id: String = String(raw.get("id", "")).strip_edges().to_lower()
		if id == "" or (raw.size() < 2 and not id.contains(Thing.ID_DOT)):
			continue
		var own_name: String = Thing.name_of(id)
		if is_patch(raw) and out.has(own_name):
			continue
		out[own_name] = raw
	return out

# A patch: a Thing that writes no def, no ancestor nor parent, only its name and
# what it changes, a layer of the Thing of its name (Mesclar, J188).
static func is_patch(raw: Dictionary) -> bool:
	var id: String = String(raw.get("id", ""))
	return not id.contains(Thing.ID_DOT) and not raw.has("def") and not raw.has("ancestor")

# What a Thing of the content inherits from: the parent its id says, or its
# `ancestor`; "" when none.
static func parent_of(raw: Dictionary) -> String:
	var parent: String = Thing.parent_of(String(raw.get("id", "")))
	if parent != "":
		return parent
	return String(raw.get("ancestor", "")).strip_edges().to_lower()

# Whether `script` is `base` or extends it.
static func extends_script(script: Script, base: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == base:
			return true
		var next: Script = current.get_base_script()
		if next == current:
			return false
		current = next
	return false
