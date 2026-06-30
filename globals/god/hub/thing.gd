# ThingHub — owns the Thing system end-to-end: the ThingCatalog
# (types + prototypes + runtime registrations), Thing instantiation,
# and Thing-specific content lookup. One of three Hubs that compose
# God; see god.gd for the coordinator.
#
# Module-scoped state — God forwards `active_module_changed` to us
# via `on_module_changed()` so we can flush the catalog.
extends RefCounted
class_name ThingHub

var _catalog: ThingCatalog = null

func _init() -> void:
	_catalog = ThingCatalog.new()

# R4 — wipe types/prototypes/indices on module switch so entities
# from one module don't leak into the next.
func on_module_changed() -> void:
	if _catalog != null:
		_catalog.reset()

# --- Lifecycle ---

func create(type_id: String) -> RefCounted:
	return _catalog.create(type_id)

func build_instance(thing_id: String, script_id: String, data: Dictionary, parts: Array[String]) -> RefCounted:
	return _catalog.build_instance(thing_id, script_id, data, parts)

# --- Type registry ---

func register_type(spec: Dictionary, replace: bool = true) -> ThingType:
	return _catalog.register_runtime_type(spec, replace)

func load_types(specs: Array) -> void:
	_catalog.load_runtime_types(specs)

func list_by_group(group_id: String) -> Array[String]:
	return _catalog.list_ids_by_group(group_id)

func resolve_type(type_id: String) -> ThingType:
	return _catalog.resolve_type(type_id)

# --- Script lookup (Thing-specific) ---
#
# Returns the GDScript backing a Thing type id ("card", "creature",
# …). Note this is different from `God.media.script(class_name)`
# which resolves a Godot class_name; ThingHub.script resolves a Thing
# type id via the AssetManager scan of `things_path()`.
func script(script_id: String) -> Script:
	return Drive.script_by_id(script_id, Drive.things_path())

# --- Content lookup (Thing-specific) ---

# Raw JSON payload for a Thing id, straight off disk.
func content(thing_id: String) -> Dictionary:
	return Drive.read_content(Drive.content_path(thing_id))

# Unified lookup: runtime-registered spec first, then disk JSON.
# Use this when displaying arbitrary Thing data that may have been
# injected at runtime by a generator rather than shipped as a file.
func data(thing_id: String) -> Dictionary:
	var runtime: Dictionary = _catalog.get_runtime_spec(thing_id)
	if not runtime.is_empty():
		return runtime
	return Drive.read_content(Drive.content_path(thing_id))
