# ThingPart — a behavior plugged into a Thing. Holds its own data,
# reacts to the Thing's thoughts (dispatched via `Thing.think`) via
# a duck-typed `_on_thought` override, and can be inherited just
# like a Thing (same catalog, same ancestor chain, same ThingVariant
# merge).
#
# Lightweight RefCounted. Unlike the Thing-as-Node approach this
# replaced, a Part is NOT in the scene tree, has no _process, no
# signals beyond what it subscribes to. Many parts per Thing is
# cheap. Attach wires the part into the Thing's local `mind` bus.
#
# The Thing owns its parts and a part only points back weakly, so
# dropping the last reference to a Thing frees the Thing and its
# parts with no detach. A part someone else still holds can outlive
# its Thing: `big_thing` just reads null from then on.
extends ThingData
class_name ThingPart

var part_id: String = ""
var ancestor: String = ""
var big_thing: Thing:
	get:
		return null if _big_thing == null else _big_thing.get_ref() as Thing
	set(value):
		_big_thing = null if value == null else weakref(value)

var _big_thing: WeakRef = null

func _apply_data(new_id: String, new_ancestor: String, new_data: Dictionary) -> void:
	part_id = new_id
	ancestor = new_ancestor
	data = new_data.duplicate(true)

# Wire this part into a Thing's bus. After attach the part's
# `_on_thought` runs every time the Thing dispatches a thought.
# Rejects re-attaching to a different Thing — caller should detach()
# first.
func attach(t: Thing) -> void:
	if t == null or big_thing == t:
		return
	if big_thing != null:
		push_warning("ThingPart.attach: part %s already attached to %s; detach first." % [part_id, big_thing.thing_id])
		return
	big_thing = t
	if t.mind != null and not t.mind.on_command.is_connected(_on_thought):
		t.mind.on_command.connect(_on_thought)

func detach() -> void:
	if big_thing == null:
		return
	if big_thing.mind != null and big_thing.mind.on_command.is_connected(_on_thought):
		big_thing.mind.on_command.disconnect(_on_thought)
	big_thing = null

# Shallow clone — same contract as Thing.clone(). The new part has
# the same data but no `big_thing` link; the caller (assembler)
# attaches it fresh.
func clone() -> ThingPart:
	var copy: ThingPart = (get_script() as Script).new()
	if copy == null:
		return null
	copy._apply_data(part_id, ancestor, data)
	return copy
