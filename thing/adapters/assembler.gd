# ThingAssembler — given an instance and its resolved ThingType,
# creates the mechanics declared by the type and plugs them in.
#
# Mechanics are Things (RefCounted) — wired via `mechanic.attach(owner)`
# which subscribes the mechanic's `_on_thought` into the owner's
# `mind`. No scene tree involvement.
#
# A mechanic is a Thing too, so it may carry mechanics of its own, and
# they are plugged into it the same way.
extends RefCounted
class_name ThingAssembler

func _attach_mechanics(owner: Thing, ids: Array[String], catalog: ThingCatalog) -> void:
	if owner == null:
		return
	for id: String in ids:
		var made: RefCounted = catalog.create(id)
		if made == null:
			continue
		if not made is Mechanic:
			Log.log(self, "warning",
				"ThingAssembler: type '%s' listed as a mechanic isn't a Mechanic." % id)
			continue
		owner.add_mechanic(made as Mechanic)

func assemble(instance: RefCounted, type: ThingType, catalog: ThingCatalog) -> RefCounted:
	if instance == null or type == null:
		return instance
	if instance is Thing:
		_attach_mechanics(instance as Thing, type.mechanics, catalog)
	return instance
