# ThingHub — owns the Thing system end-to-end: the ThingCatalog
# (types + prototypes + runtime registrations), Thing instantiation,
# and Thing-specific content lookup. One of the three Hubs that compose
# God; see god.gd for the coordinator.
#
# Module-scoped state: it keeps the catalog of the module, so it overrides
# `D5Hub.on_module_changed`, and hears the change first, before MediaHub,
# which builds its chromas and palettes from the catalog.
extends D5Hub
class_name ThingHub

var _catalog: ThingCatalog = null

func _init() -> void:
	_catalog = ThingCatalog.new()

# R4 — wipe types/prototypes/indices on module switch so entities
# from one module don't leak into the next. Then run the cross-ref
# validation pass so broken references (typos, missing base types,
# unknown class_names) surface immediately as warnings.
func on_module_changed(_module_id: String) -> void:
	if _catalog != null:
		_catalog.reset()
	_run_validation()

func _run_validation() -> void:
	var issues: Array[String] = Drive.validate_content(self)
	for issue: String in issues:
		Log.log(self, "warning", "[CrossRef] " + issue)

# --- Lifecycle ---

func create(type_id: String) -> RefCounted:
	return _catalog.create(type_id)

func build_instance(thing_id: String, script_id: String, payload: Dictionary, parts: Array[String]) -> RefCounted:
	return _catalog.build_instance(thing_id, script_id, payload, parts)

# --- Type registry ---

func register_type(spec: Dictionary, replace: bool = true) -> ThingType:
	return _catalog.register_runtime_type(spec, replace)

func load_types(specs: Array) -> void:
	_catalog.load_runtime_types(specs)

func resolve_type(type_id: String) -> ThingType:
	return _catalog.resolve_type(type_id)

# --- Script lookup (Thing-specific) ---
#
# The script a Thing is born from, by its id: the `<id>.gd` of the content of
# the active modules, a mod's before the game's (`Drive.script_by_id`). Not the
# same as `God.media.script(class_name)`, which resolves a Godot class_name,
# for a `"class"` field of the data.
func script(script_id: String) -> Script:
	return Drive.script_by_id(script_id)

# --- Content lookup (Thing-specific) ---

# A Thing as the active modules give it, with every key it was written with,
# from a list or from a file of its own.
func content(thing_id: String) -> Dictionary:
	return Drive.thing(thing_id)

# Unified lookup: runtime-registered spec first, then the modules' Thing.
# Use this when displaying arbitrary Thing data that may have been
# injected at runtime by a generator rather than shipped as a file.
func data(thing_id: String) -> Dictionary:
	var runtime: Dictionary = _catalog.get_runtime_spec(thing_id)
	if not runtime.is_empty():
		return runtime
	return Drive.thing(thing_id)
