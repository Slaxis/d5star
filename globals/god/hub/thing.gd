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
# The lineages worked out, by the native they must reach ("" for any), then by
# the id asked (J189).
var _lineages: Dictionary = {}
# The definitions of the events of the content, by name, built once (J189);
# null for a name that defines none.
var _definitions: Dictionary = {}

func _init() -> void:
	_catalog = ThingCatalog.new()

# R4 — wipe types/prototypes/indices on module switch so entities
# from one module don't leak into the next. Then run the cross-ref
# validation pass so broken references (typos, missing base types,
# unknown class_names) surface immediately as warnings.
func on_module_changed(_module_id: String) -> void:
	if _catalog != null:
		_catalog.reset()
	_lineages.clear()
	_definitions.clear()
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
	_lineages.clear()
	_definitions.clear()
	return _catalog.register_runtime_type(spec, replace)

func load_types(specs: Array) -> void:
	_lineages.clear()
	_definitions.clear()
	_catalog.load_runtime_types(specs)

func resolve_type(type_id: String) -> ThingType:
	return _catalog.resolve_type(type_id)

# The name of a Thing and the names it inherits, the closest first, up to the
# native at the root of its chain: `[&"melee", &"attack", &"event"]` for
# `attack.melee` (J189). A whole id gives the parent of a Thing no module
# wrote. With `root`, a chain that does not reach that native is only its name:
# an event of before, `pain`, is heard only as itself. Worked out once per id;
# the array is shared, so read it and never change it.
func lineage(id: String, root: String = "") -> Array[StringName]:
	var of_root: Dictionary = _lineages.get(root, {})
	if of_root.has(id):
		return of_root[id]
	var chain: Array[StringName] = []
	var name: String = Thing.name_of(id)
	var parent: String = Thing.parent_of(id)
	while name != "" and not chain.has(StringName(name)):
		chain.append(StringName(name))
		if Drive.is_native(name):
			break
		var type: ThingType = _catalog.get_type(name)
		if type == null:
			type = _catalog.resolve_type(name)   # a type registered at runtime
		var up: String = type.ancestor if type != null and type.ancestor != "" else parent
		parent = ""
		name = Thing.name_of(up)
	if root != "" and (chain.is_empty() or chain.back() != StringName(root)):
		chain = [StringName(Thing.name_of(id))] as Array[StringName]
	of_root[id] = chain
	_lineages[root] = of_root
	return chain

# The Thing that defines an event of the content, by its lineage, built once
# with its mechanics and shared by every time it happens; null when the
# lineage does not reach `event` or no module wrote its name (J189).
func definition(lineage: Array[StringName]) -> Thing:
	if lineage.size() < 2 or lineage.back() != StringName(Event.NATIVE):
		return null
	var name: StringName = lineage[0]
	if not _definitions.has(name):
		var defined: Thing = null
		if _catalog.resolve_type(String(name)) != null:
			defined = create(String(name)) as Thing
		_definitions[name] = defined
	return _definitions[name]

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

# The layers of a Thing, each as a module wrote it, the lowest priority
# first, which the catalog merges over what the Thing inherits (Mesclar, J188).
func layers(thing_id: String) -> Array[Dictionary]:
	return Drive.layers(thing_id)

# Unified lookup: runtime-registered spec first, then the modules' Thing.
# Use this when displaying arbitrary Thing data that may have been
# injected at runtime by a generator rather than shipped as a file.
func data(thing_id: String) -> Dictionary:
	var runtime: Dictionary = _catalog.get_runtime_spec(thing_id)
	if not runtime.is_empty():
		return runtime
	return Drive.thing(thing_id)
