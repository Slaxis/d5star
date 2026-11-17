# Bus — a space where events happen (J189). The same primitive backs three
# scopes:
#
#   - the `mind` of a Thing, where its mechanics hear what it thinks;
#   - a channel, the space a group of Things shares, such as the Things of one
#     match, so two groups alive at once never hear each other; whoever makes
#     it tunes each Thing to it, `thing.channel = channel`;
#   - the Air, the world, where a Thing on no channel manifests (the autoload
#     `Air` wraps one).
#
# Two ways to hear. `on_event`, the signal, gives every event, before anyone
# else, to whoever only reads: a log, a record, a screen. An ear, `subscribe`,
# hears the events of one id and of its heirs, in the order of its priority,
# the lowest first, and the same priority in the order the ears came; an ear
# may change the marks of the event, or hold it, `e.hold()`, and nobody after
# it hears it, as a handler of Caves of Qud that returns false.
#
# A bus holds its ears, and a lambda holds what it uses: a lambda that uses a
# Thing, subscribed on that Thing's mind or channel, keeps both alive for good.
# Subscribe a method instead (`mechanic._on_event`), which lets its object go:
# the ear of an object gone is dropped the next time its id happens.
extends RefCounted
class_name Bus

# --- Data ---

## Every event that happens here, before any ear: who only reads hears it
## first, and hears it whole, held or not.
signal on_event(e: Event)

## The id of the ear of every event, whatever its id.
const ANY := &"*"

# The ears of each id, a StringName, each list by priority, then by arrival.
# A list is never changed in place: a new ear, or one that leaves, makes a new
# list, so an event that is happening goes on with the ears it found.
var _ears: Dictionary = {}
var _arrivals: int = 0

# One ear: what it calls, its priority and when it came.
class Ear extends RefCounted:
	var callback: Callable
	var priority: int
	var arrival: int

	func _init(to_call: Callable, order: int, came: int) -> void:
		callback = to_call
		priority = order
		arrival = came

# --- Tools ---

## Hears the events of `id` and of its heirs, `callback(e: Event)`: an ear of
## `attack` hears `attack.melee`. `ANY` hears every event. The lower the
## priority, the sooner it hears; the same priority, in the order the ears
## came. A whole id, `event.attack`, is heard by its name.
func subscribe(id: StringName, callback: Callable, priority: int = 0) -> void:
	var key: StringName = _key(id)
	var ears: Array = (_ears.get(key, []) as Array).duplicate()
	var at: int = ears.size()
	while at > 0 and (ears[at - 1] as Ear).priority > priority:
		at -= 1
	ears.insert(at, Ear.new(callback, priority, _arrivals))
	_arrivals += 1
	_ears[key] = ears

## The ear of `callback` stops hearing `id`.
func unsubscribe(id: StringName, callback: Callable) -> void:
	var key: StringName = _key(id)
	if not _ears.has(key):
		return
	var kept: Array = []
	for ear: Ear in _ears[key]:
		if ear.callback != callback:
			kept.append(ear)
	if kept.is_empty():
		_ears.erase(key)
	else:
		_ears[key] = kept

## Makes `e` happen here: `on_event` first, then each ear of its id, of the ids
## it inherits and of `ANY`, by priority, until one holds it.
func dispatch(e: Event) -> void:
	if e == null or e.thing_id == "":
		return
	on_event.emit(e)
	if _ears.is_empty():
		return
	var gone: Array[Ear] = []
	for ear: Ear in _ears_of(e):
		if not ear.callback.is_valid():
			gone.append(ear)
			continue
		ear.callback.call(e)
		if e.held:
			break
	for ear: Ear in gone:
		_drop(ear)

# --- Library ---

# The ears that hear `e`, by priority, then by arrival. One list, as it is
# kept; several, the lists of its lineage and of `ANY`, merged.
func _ears_of(e: Event) -> Array:
	var any: Variant = _ears.get(ANY)
	if any != null and _ears.size() == 1:
		return any as Array
	var found: Array = []
	var lists: int = 0
	for id: StringName in e.lineage():
		var ears: Variant = _ears.get(id)
		if ears != null:
			found = ears as Array if lists == 0 else found + (ears as Array)
			lists += 1
	if any != null:
		found = any as Array if lists == 0 else found + (any as Array)
		lists += 1
	if lists > 1:
		found.sort_custom(_sooner)
	return found

static func _sooner(a: Ear, b: Ear) -> bool:
	return a.priority < b.priority or (a.priority == b.priority and a.arrival < b.arrival)

# An ear whose object is gone leaves every list it is in.
func _drop(ear: Ear) -> void:
	for key: StringName in _ears.keys():
		if (_ears[key] as Array).has(ear):
			var kept: Array = (_ears[key] as Array).duplicate()
			kept.erase(ear)
			if kept.is_empty():
				_ears.erase(key)
			else:
				_ears[key] = kept

static func _key(id: StringName) -> StringName:
	return id if id == ANY else StringName(Thing.name_of(String(id)))
