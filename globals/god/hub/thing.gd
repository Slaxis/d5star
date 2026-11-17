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

## The key of a draw that names a template: `{ "from": "event.weather" }` (J205).
const DRAW_FROM := "from"
## The field of what a Thing weighs in a draw (J205).
const WEIGHT := "weight"

var _catalog: ThingCatalog = null
# The lineages worked out, by the native they must reach ("" for any), then by
# the id asked (J189).
var _lineages: Dictionary = {}
# The definitions of the events of the content, by name, built once (J189);
# null for a name that defines none.
var _definitions: Dictionary = {}
# The families worked out, by the name of their template (J205).
var _families: Dictionary = {}

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
	_families.clear()
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
	_families.clear()
	return _catalog.register_runtime_type(spec, replace)

func load_types(specs: Array) -> void:
	_lineages.clear()
	_definitions.clear()
	_families.clear()
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

# --- Draws (J205) ---
#
# A draw names a template, not a list, as the population tables of Caves of
# Qud do: `{ "from": "event.weather" }` is one of the Things of the family of
# `weather`, so a new climate, arena or card joins the draw by existing, a
# mod's too, and nobody edits a list.

# The family of a template: the names of the Things of the active modules, and
# of the types registered at runtime, whose lineage passes through `id`,
# sorted, so a draw does not hang on the file or the module a Thing comes
# from. A Thing written `abstract` is never one of them, and the Thing `id`
# names is, when it is not. Worked out once per name; the array is shared, so
# read it and never change it.
func family(id: String) -> Array[StringName]:
	var name: StringName = StringName(Thing.name_of(id))
	if _families.has(name):
		return _families[name]
	var out: Array[StringName] = []
	if name != &"":
		for candidate: String in _names():
			if not lineage(candidate).has(name):
				continue
			var type: ThingType = _catalog.resolve_type(candidate)
			if type != null and not type.is_abstract:
				out.append(StringName(candidate))
	_families[name] = out
	return out

# One Thing drawn from `draw` with `rng`, by what each weighs: its name, or ""
# when nothing weighs. `{ "from": "<template>" }` draws from the family of the
# template, a list from the Things it names, and a name is that Thing. A Thing
# weighs its `weight`, as written over its ancestors', 1 when it writes none,
# and one that weighs 0 is never drawn. It takes the rng it is given, as a die
# does, the seeded rng of a match, so the same seed draws the same.
func pick(draw: Variant, rng: RandomNumberGenerator) -> String:
	if rng == null:
		Log.log(self, "warning", "ThingHub.pick: no rng to draw %s with" % str(draw))
		return ""
	var names: Array[StringName] = _drawn_from(draw)
	var weights: Array[float] = []
	var total: float = 0.0
	for name: StringName in names:
		var weight: float = _weight(name)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return ""
	var roll: float = rng.randf() * total
	var drawn: String = ""
	for i: int in names.size():
		if weights[i] <= 0.0:
			continue
		drawn = String(names[i])
		roll -= weights[i]
		if roll < 0.0:
			break
	return drawn

# The Things a draw draws from: the family of `{ "from": id }`, the Things a
# list names, once each, or the Thing a name names; a template never.
func _drawn_from(draw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if draw is Dictionary:
		var from: Variant = (draw as Dictionary).get(DRAW_FROM, null)
		return family(String(from)) if from is String or from is StringName else out
	for one: Variant in (draw as Array if draw is Array else [draw]):
		if not (one is String or one is StringName):
			continue
		var name: StringName = StringName(Thing.name_of(String(one)))
		var type: ThingType = _catalog.resolve_type(String(name))
		if type != null and not type.is_abstract and not out.has(name):
			out.append(name)
	return out

# What a Thing weighs in a draw: its `weight`, as written over its ancestors',
# never less than 0; 1 when it writes none, or writes no number.
func _weight(name: StringName) -> float:
	var type: ThingType = _catalog.resolve_type(String(name))
	if type == null:
		return 0.0
	var weight: Variant = type.data.get(WEIGHT, 1.0)
	return maxf(0.0, float(weight)) if weight is int or weight is float else 1.0

# The names of the Things of the active modules, each Thing a Def holds, and of
# the types registered at runtime: once each, sorted.
func _names() -> Array[String]:
	var seen: Dictionary = {}
	for def_id: String in Drive.defs():
		var kind: KindDef = Drive.def(def_id) as KindDef
		if kind != null:
			for id: String in kind.ids():
				seen[Thing.name_of(id)] = true
	for spec: Dictionary in _catalog.runtime_specs():
		seen[Thing.name_of(String(spec.get("id", "")))] = true
	seen.erase("")
	var out: Array[String] = []
	out.assign(seen.keys())
	out.sort()
	return out

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
