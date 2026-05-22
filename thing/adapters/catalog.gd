# Thing catalog: loads types from JSON, resolves ancestors, and builds prototypes.
# Stripped of skin/visual logic — pure data-driven entity management.
extends Resource
class_name ThingCatalog

const KEY_ID := "id"
const KEY_ANCESTOR := "ancestor"
const KEY_PARTS := "parts"

var _assembler: ThingAssembler = null
var _types: Dictionary = {}
var _resolved: Dictionary = {}
var _prototypes: Dictionary = {}
var _index: Dictionary = {}
var _runtime_specs: Dictionary = {}
var _runtime_index: Dictionary = {}

func _init() -> void:
	_assembler = ThingAssembler.new()

func set_assembler(assembler: ThingAssembler) -> void:
	if assembler != null:
		_assembler = assembler

# R4 — clears every cached type, prototype, and index. Called on a module
# switch so entities from one module never leak into the next. Orphan
# prototype nodes are freed.
func reset() -> void:
	for proto: Variant in _prototypes.values():
		if proto is Node and is_instance_valid(proto):
			(proto as Node).queue_free()
	_types.clear()
	_resolved.clear()
	_prototypes.clear()
	_index.clear()
	_runtime_specs.clear()
	_runtime_index.clear()

func _is_thing_payload(raw: Dictionary) -> bool:
	if not raw.has(KEY_ID):
		return false
	return raw.size() > 1

func _merge_data(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged: Variant = ThingVariant.merge(base, extra)
	if merged is Dictionary:
		return merged
	return {}

func _merge_parts(base: Array[String], extra: Array[String]) -> Array[String]:
	var merged: Variant = ThingVariant.merge(base, extra)
	if not merged is Array:
		return []
	var results: Array[String] = []
	for entry in merged:
		var part_id: String = String(entry).strip_edges().to_lower()
		if part_id != "":
			results.append(part_id)
	return results

func _script(script_id: String) -> Script:
	return God.thing_script(script_id)

func _has_script(script_id: String) -> bool:
	if script_id == "":
		return false
	return _script(script_id) != null

func _resolve_script_id(base: ThingType, parent: ThingType) -> String:
	if base == null:
		return ""
	if base.ancestor != "" and _has_script(base.ancestor):
		return base.ancestor
	if parent != null and parent.script_id != "":
		return parent.script_id
	if _has_script("thing"):
		return "thing"
	Log.log(self, "error", "ThingCatalog: base script 'thing' not found.")
	return ""

func _parse_type(raw: Dictionary) -> ThingType:
	var type: ThingType = ThingType.new()
	type.type_id = String(raw.get(KEY_ID, "")).strip_edges().to_lower()
	type.ancestor = String(raw.get(KEY_ANCESTOR, "")).strip_edges().to_lower()
	var parts_raw: Variant = raw.get(KEY_PARTS, [])
	if parts_raw is Array:
		for part in parts_raw:
			var part_id: String = String(part).strip_edges().to_lower()
			if part_id != "":
				type.parts.append(part_id)
	var data: Dictionary = {}
	var reserved: Dictionary = {
		KEY_ID: true,
		KEY_ANCESTOR: true,
		KEY_PARTS: true,
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
	if _has_script(key):
		Log.log(self, "error", "ThingCatalog: type id conflicts with script id: " + key)
		return null
	if _types.has(key):
		return _types[key]
	var raw: Dictionary = God.thing_content(key)
	if raw.is_empty() or not _is_thing_payload(raw):
		return null
	var parsed: ThingType = _parse_type(raw)
	if parsed.type_id == "":
		return null
	_types[key] = parsed
	return parsed

func _resolve_type(type_id: String) -> ThingType:
	var key: String = String(type_id).strip_edges().to_lower()
	if key == "":
		return null
	if _resolved.has(key):
		return _resolved[key]
	var base: ThingType = _get_type(key)
	if base == null:
		return null
	var parent: ThingType = null
	if base.ancestor != "" and not _has_script(base.ancestor):
		parent = _resolve_type(base.ancestor)
		if parent == null:
			Log.log(self, "error", "ThingCatalog: ancestor type not found: " + base.ancestor)
			return null
	var merged: ThingType = ThingType.new()
	var script_id: String = _resolve_script_id(base, parent)
	if script_id == "":
		return null
	if parent == null:
		base.script_id = script_id
		_resolved[key] = base
		return base
	merged.type_id = base.type_id
	merged.ancestor = base.ancestor
	merged.script_id = script_id
	merged.data = _merge_data(parent.data, base.data)
	merged.parts = _merge_parts(parent.parts, base.parts)
	_resolved[key] = merged
	return merged

func _instantiate(script_id: String) -> Node:
	var script: Script = _script(script_id)
	if script == null:
		return null
	return script.new()

func _build_prototype(type: ThingType) -> Node:
	var instance: Node = _instantiate(type.script_id)
	if instance == null:
		return null
	if instance.has_method("_apply_data"):
		instance.call("_apply_data", type.type_id, type.ancestor, type.data)
	return instance

func _build_index() -> void:
	if not _index.is_empty():
		return
	var all: Array[Dictionary] = God.all_content()
	for raw: Dictionary in all:
		if not _is_thing_payload(raw):
			continue
		var group: String = String(raw.get("group", "")).strip_edges().to_lower()
		if group == "":
			continue
		var id: String = String(raw.get(KEY_ID, "")).strip_edges().to_lower()
		if id == "":
			continue
		if _has_script(id):
			continue
		if not _index.has(group):
			_index[group] = []
		_index[group].append(id)

func _register_runtime_index(type_id: String, group_id: String) -> void:
	var group: String = String(group_id).strip_edges().to_lower()
	if group == "":
		return
	if not _runtime_index.has(group):
		_runtime_index[group] = []
	var list: Array = _runtime_index[group] as Array
	if not list.has(type_id):
		list.append(type_id)
	_runtime_index[group] = list

func _remove_runtime_index(type_id: String) -> void:
	for group_key in _runtime_index.keys():
		var list: Array = _runtime_index[group_key] as Array
		if list.has(type_id):
			list.erase(type_id)
			_runtime_index[group_key] = list

func register_runtime_type(spec: Dictionary, replace: bool = true) -> ThingType:
	if spec.is_empty():
		return null
	var raw: Dictionary = spec.duplicate(true)
	var type_id: String = String(raw.get(KEY_ID, "")).strip_edges().to_lower()
	if type_id == "":
		return null
	raw[KEY_ID] = type_id
	if raw.has(KEY_ANCESTOR):
		raw[KEY_ANCESTOR] = String(raw.get(KEY_ANCESTOR, "")).strip_edges().to_lower()
	if _has_script(type_id):
		Log.log(self, "error", "ThingCatalog: type id conflicts with script id: " + type_id)
		return null
	if _runtime_specs.has(type_id):
		if not replace:
			return _resolved.get(type_id, null) as ThingType
		_runtime_specs.erase(type_id)
		_resolved.erase(type_id)
		_types.erase(type_id)
		_prototypes.erase(type_id)
		_remove_runtime_index(type_id)
	_runtime_specs[type_id] = raw
	var base: ThingType = _parse_type(raw)
	if base.type_id == "":
		return null
	var parent: ThingType = null
	if base.ancestor != "" and not _has_script(base.ancestor):
		parent = _resolve_type(base.ancestor)
		if parent == null:
			Log.log(self, "error", "ThingCatalog: ancestor type not found: " + base.ancestor)
			return null
	var script_id: String = _resolve_script_id(base, parent)
	if script_id == "":
		return null
	var resolved: ThingType = base
	if parent != null:
		resolved = ThingType.new()
		resolved.type_id = base.type_id
		resolved.ancestor = base.ancestor
		resolved.script_id = script_id
		resolved.data = _merge_data(parent.data, base.data)
		resolved.parts = _merge_parts(parent.parts, base.parts)
	else:
		base.script_id = script_id
	_resolved[type_id] = resolved
	_register_runtime_index(type_id, raw.get("group", ""))
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
	_runtime_index.clear()

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

func create(type_id: String) -> Node:
	var type: ThingType = _resolve_type(type_id)
	if type == null:
		return null
	if _prototypes.has(type.type_id):
		var proto: Node = _prototypes[type.type_id]
		if proto and proto.has_method("clone"):
			var clone: Node = proto.call("clone") as Node
			if clone:
				(_assembler as ThingAssembler).assemble(clone, type, self)
				return clone
	var prototype: Node = _build_prototype(type)
	if prototype == null:
		return null
	_prototypes[type.type_id] = prototype
	if prototype.has_method("clone"):
		var cloned: Node = prototype.call("clone") as Node
		if cloned:
			(_assembler as ThingAssembler).assemble(cloned, type, self)
			return cloned
	(_assembler as ThingAssembler).assemble(prototype, type, self)
	return prototype

func build_instance(thing_id: String, script_id: String, data: Dictionary, parts: Array[String]) -> Node:
	var instance: Node = _instantiate(script_id)
	if instance == null:
		return null
	if instance.has_method("_apply_data"):
		instance.call("_apply_data", thing_id, "", data)
	var type: ThingType = ThingType.new()
	type.type_id = thing_id
	type.data = data
	type.parts = parts
	(_assembler as ThingAssembler).assemble(instance, type, self)
	return instance

func list_ids_by_group(group_id: String) -> Array[String]:
	var group: String = String(group_id).strip_edges().to_lower()
	_build_index()
	var ids: Array[String] = []
	if _index.has(group):
		for entry in _index[group]:
			var value: String = String(entry)
			if value != "" and not ids.has(value):
				ids.append(value)
	if _runtime_index.has(group):
		for entry in _runtime_index[group]:
			var value: String = String(entry)
			if value != "" and not ids.has(value):
				ids.append(value)
	return ids
