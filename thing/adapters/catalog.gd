# ThingCatalog — loads ThingTypes from JSON, resolves the
# `ancestor` chain via ThingVariant merge, caches prototypes, and
# clones fresh instances on demand.
#
# A Thing whose id says its parent, `<parent>.<name>` (J188), comes from
# DefManager with its id split in its name and its ancestor, and is found
# by either; its mechanics, the ones it plugs in, are its `mechanics`, and
# a Thing of the format of before names them in `parts`. A Thing a mod
# changes comes in layers, the lowest priority first, and each merges over
# the one before, over what the Thing inherits (Mesclar, J188). The mechanics
# merge by id (J204): each plugs once, a writing changes the fields the Thing
# gives one, and `{"-": [...]}` takes one out (`ThingType.plug`).
#
# Instances are pure RefCounted Things, a Mechanic among them, never Nodes —
# materialising in the scene tree is an upstream concern.
extends Resource
class_name ThingCatalog

const KEY_ID := "id"
const KEY_DEF := "def"
const KEY_ANCESTOR := "ancestor"
const KEY_PARTS := "parts"
const KEY_MECHANICS := "mechanics"
const KEY_KIND := "kind"
const KEY_ABSTRACT := "abstract"

const KIND_THING := "thing"
const KIND_PART := "part"

var _assembler: ThingAssembler = null
var _types: Dictionary = {}
var _resolved: Dictionary = {}
var _prototypes: Dictionary = {}
var _runtime_specs: Dictionary = {}

func _init() -> void:
	_assembler = ThingAssembler.new()

func set_assembler(assembler: ThingAssembler) -> void:
	if assembler != null:
		_assembler = assembler

# R4 — clears every cached type and prototype. Called on a module switch
# so entities from one module never leak into the next.
func reset() -> void:
	_types.clear()
	_resolved.clear()
	_prototypes.clear()
	_runtime_specs.clear()

func _is_thing_payload(raw: Dictionary) -> bool:
	if not raw.has(KEY_ID):
		return false
	return raw.size() > 1

func _merge_data(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged: Variant = ThingVariant.merge(base, extra)
	if merged is Dictionary:
		return merged
	return {}

func _script(script_id: String) -> Script:
	return God.things.script(script_id)

func _has_script(script_id: String) -> bool:
	if script_id == "":
		return false
	return _script(script_id) != null

# Resolves which Script the instance should `script.new()` from.
# Order (J188): its own script → its ancestor's, the script of the type it
# inherits from, or the ancestor itself when it is only a script, a native
# among them → the native of its kind.
#
# Its own script: the `<id>.gd` of the content of the active modules
# (`God.things.script`), the model of Caves of Qud — a Thing with
# `"id": "lamp"` is born from the `lamp.gd` its module brings, a script
# that extends Thing, and a mod's `lamp.gd` takes the place of the game's.
# A heir with no script of its own is born from its ancestor's.
func _resolve_script_id(base: ThingType, parent: ThingType) -> String:
	if base == null:
		return ""
	if _has_script(base.type_id):
		return base.type_id
	if parent != null and parent.script_id != "":
		return parent.script_id
	if base.ancestor != "" and _has_script(base.ancestor):
		return base.ancestor
	# Fallback to the kind-specific base script.
	var base_name: String = "mechanic" if base.kind == KIND_PART else "thing"
	if _has_script(base_name):
		return base_name
	Log.log(self, "error", "ThingCatalog: base script '%s' not found." % base_name)
	return ""

func _parse_type(raw: Dictionary) -> ThingType:
	var type: ThingType = ThingType.new()
	type.type_id = String(raw.get(KEY_ID, "")).strip_edges().to_lower()
	type.ancestor = String(raw.get(KEY_ANCESTOR, "")).strip_edges().to_lower()
	type.kind = String(raw.get(KEY_KIND, KIND_THING)).strip_edges().to_lower()
	if type.kind != KIND_PART:
		type.kind = KIND_THING
	type.is_abstract = bool(raw.get(KEY_ABSTRACT, false))
	_plug(type, raw)
	var data: Dictionary = {}
	var reserved: Dictionary = {
		KEY_ID: true,
		KEY_DEF: true,
		KEY_ANCESTOR: true,
		KEY_PARTS: true,
		KEY_MECHANICS: true,
		KEY_KIND: true,
		KEY_ABSTRACT: true,
	}
	for key in raw.keys():
		if reserved.has(key):
			continue
		data[String(key)] = raw[key]
	type.data = data
	return type

func _get_type(type_id: String) -> ThingType:
	var key: String = String(type_id).strip_edges().to_lower()
	if key == "":
		return null
	if _types.has(key):
		return _types[key]
	var written: Array[Dictionary] = God.things.layers(key)
	if written.is_empty() or (written.size() == 1 and not _is_thing_payload(written[0])):
		return null
	var parsed: ThingType = _parse_type(written[0])
	if parsed.type_id == "":
		return null
	for i: int in range(1, written.size()):
		_layer(parsed, written[i])
	_types[key] = parsed
	return parsed

# What one layer writes in `parts` and in `mechanics`, plugged over the
# mechanics before it and kept, for the catalog to plug again over what the
# Thing inherits (J204).
func _plug(type: ThingType, raw: Dictionary) -> void:
	for key: String in [KEY_PARTS, KEY_MECHANICS]:
		if raw.has(key):
			type.plugs.append(raw[key])
			type.plug(raw[key])

# A later layer of a Thing over its type (Mesclar, J188): its data merges
# over the data before it when the type is resolved, its mechanics plug over
# the ones before by id (J204), and an ancestor, a kind or a flag of template
# it writes takes the place of the one before.
func _layer(type: ThingType, raw: Dictionary) -> void:
	var layer: ThingType = _parse_type(raw)
	if layer.ancestor != "":
		type.ancestor = layer.ancestor
	if raw.has(KEY_KIND):
		type.kind = layer.kind
	if raw.has(KEY_ABSTRACT):
		type.is_abstract = layer.is_abstract
	_plug(type, raw)
	type.layers.append(layer.data)

func _resolve_type(type_id: String) -> ThingType:
	var key: String = String(type_id).strip_edges().to_lower()
	if key == "":
		return null
	if _resolved.has(key):
		return _resolved[key]
	var base: ThingType = _get_type(key)
	if base == null:
		return null
	if base.type_id != key:
		# Asked by its whole id, `<parent>.<name>` (J188): the type of its name.
		var named: ThingType = _resolve_type(base.type_id)
		if named != null:
			_resolved[key] = named
		return named
	var resolved: ThingType = _resolve(base)
	if resolved != null:
		_resolved[key] = resolved
	return resolved

# A type with its ancestor's data under its own, then each of its later
# layers, and the script it is born from. The ancestor is a type when one
# has its id, and gives its data, its mechanics and its script; or only a
# script, a native among them (J188). Its own writings of mechanics plug over
# the ancestor's, so it changes a field of one it inherits, or takes one out
# (J204). Null, after saying so, when it is neither.
func _resolve(base: ThingType) -> ThingType:
	var parent: ThingType = null
	if base.ancestor != "":
		parent = _resolve_type(base.ancestor)
		if parent == null and not _has_script(base.ancestor):
			Log.log(self, "error", "ThingCatalog: ancestor type not found: " + base.ancestor)
			return null
	var script_id: String = _resolve_script_id(base, parent)
	if script_id == "":
		return null
	if parent == null and base.layers.is_empty():
		base.script_id = script_id
		return base
	var merged: ThingType = ThingType.new()
	merged.type_id = base.type_id
	merged.ancestor = base.ancestor
	merged.kind = base.kind
	# `abstract` is per-Thing — RimWorld semantics: a concrete child
	# does NOT inherit the flag from its abstract parent. Take only
	# the base's own value.
	merged.is_abstract = base.is_abstract
	merged.script_id = script_id
	merged.data = base.data.duplicate(true) if parent == null else _merge_data(parent.data, base.data)
	for layer: Dictionary in base.layers:
		merged.data = _merge_data(merged.data, layer)
	if parent == null:
		merged.plug_from(base)
	else:
		merged.plug_from(parent)
		for written: Variant in base.plugs:
			merged.plug(written)
	return merged

# Instantiates a Thing (or a Mechanic) via `script.new()`. Returns
# the typed base (RefCounted) — callers should check kind via the
# resolved ThingType, not via Variant inspection.
func _instantiate(script_id: String) -> RefCounted:
	var script: Script = _script(script_id)
	if script == null:
		return null
	return script.new()

func _build_prototype(type: ThingType) -> RefCounted:
	var instance: RefCounted = _instantiate(type.script_id)
	if instance == null:
		return null
	if instance.has_method("_apply_data"):
		instance.call("_apply_data", type.type_id, type.ancestor, type.data)
	return instance

func register_runtime_type(spec: Dictionary, replace: bool = true) -> ThingType:
	if spec.is_empty():
		return null
	var raw: Dictionary = spec.duplicate(true)
	var type_id: String = String(raw.get(KEY_ID, "")).strip_edges().to_lower()
	if type_id == "":
		return null
	if type_id.contains(Thing.ID_DOT):
		# An id that says its parent, `<parent>.<name>` (J188).
		raw[KEY_ANCESTOR] = Thing.parent_of(type_id)
		type_id = Thing.name_of(type_id)
	raw[KEY_ID] = type_id
	if raw.has(KEY_ANCESTOR):
		raw[KEY_ANCESTOR] = String(raw.get(KEY_ANCESTOR, "")).strip_edges().to_lower()
	if _runtime_specs.has(type_id):
		if not replace:
			return _resolved.get(type_id, null) as ThingType
		_runtime_specs.erase(type_id)
		_resolved.erase(type_id)
		_types.erase(type_id)
		_prototypes.erase(type_id)
	_runtime_specs[type_id] = raw
	var base: ThingType = _parse_type(raw)
	if base.type_id == "":
		return null
	var resolved: ThingType = _resolve(base)
	if resolved == null:
		return null
	_resolved[type_id] = resolved
	return resolved

func load_runtime_types(specs: Array, replace: bool = true) -> void:
	for entry in specs:
		if entry is Dictionary:
			register_runtime_type(entry as Dictionary, replace)

func runtime_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var keys: Array = _runtime_specs.keys()
	keys.sort()
	for key in keys:
		var entry: Variant = _runtime_specs.get(key, null)
		if entry is Dictionary:
			specs.append((entry as Dictionary).duplicate(true))
	return specs

func clear_runtime_types() -> void:
	for key in _runtime_specs.keys():
		var type_id: String = String(key)
		_resolved.erase(type_id)
		_types.erase(type_id)
		_prototypes.erase(type_id)
	_runtime_specs.clear()

func has_runtime_type(type_id: String) -> bool:
	var key: String = String(type_id).strip_edges().to_lower()
	if key == "":
		return false
	return _runtime_specs.has(key)

func get_runtime_spec(type_id: String) -> Dictionary:
	var key: String = String(type_id).strip_edges().to_lower()
	if key == "":
		return {}
	var entry: Variant = _runtime_specs.get(key, null)
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}

func get_type(type_id: String) -> ThingType:
	return _get_type(type_id)

func resolve_type(type_id: String) -> ThingType:
	return _resolve_type(type_id)

# Public factory. Returns a Thing (the typical case) or a Mechanic
# (when the resolved type's `kind` is "part"). Returns null for
# abstract types (template-only; only their descendants can be
# instantiated — RimWorld-style Abstract flag). The caller decides
# what to do with each — assembler.assemble() handles part attach.
func create(type_id: String) -> RefCounted:
	var type: ThingType = _resolve_type(type_id)
	if type == null:
		return null
	if type.is_abstract:
		Log.log(self, "warning",
			"ThingCatalog: cannot instantiate abstract type '%s' (template only)" % type.type_id)
		return null
	if _prototypes.has(type.type_id):
		var proto: RefCounted = _prototypes[type.type_id]
		if proto and proto.has_method("clone"):
			var copy: RefCounted = proto.call("clone") as RefCounted
			if copy:
				(_assembler as ThingAssembler).assemble(copy, type, self)
				return copy
	var prototype: RefCounted = _build_prototype(type)
	if prototype == null:
		return null
	_prototypes[type.type_id] = prototype
	if prototype.has_method("clone"):
		var cloned: RefCounted = prototype.call("clone") as RefCounted
		if cloned:
			(_assembler as ThingAssembler).assemble(cloned, type, self)
			return cloned
	(_assembler as ThingAssembler).assemble(prototype, type, self)
	return prototype

func build_instance(thing_id: String, script_id: String, data: Dictionary, parts: Array[String]) -> RefCounted:
	var instance: RefCounted = _instantiate(script_id)
	if instance == null:
		return null
	if instance.has_method("_apply_data"):
		instance.call("_apply_data", thing_id, "", data)
	var type: ThingType = ThingType.new()
	type.type_id = thing_id
	type.data = data
	type.mechanics = parts
	(_assembler as ThingAssembler).assemble(instance, type, self)
	return instance
