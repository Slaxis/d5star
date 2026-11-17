# ThingAssembler — given an instance and its resolved ThingType,
# creates the mechanics declared by the type and plugs them in.
#
# Mechanics are Things (RefCounted) — wired via `mechanic.attach(owner)`
# which subscribes the mechanic's `_on_thought` into the owner's
# `mind`. No scene tree involvement.
#
# A mechanic is a Thing too, so it may carry mechanics of its own, and
# they are plugged into it the same way.
#
# The fields the Thing gives a mechanic (J204), `"mechanics": {"work":
# {"dc": 12}}`, merge over the mechanic's own data before it plugs in, each
# writing over the one before, as a layer of the Mesclar does: so its
# `priority`, `hears` and `watches` may come from the Thing too.
extends RefCounted
class_name ThingAssembler

func _attach_mechanics(owner: Thing, type: ThingType, catalog: ThingCatalog) -> void:
	if owner == null:
		return
	for id: String in type.mechanics:
		var made: RefCounted = catalog.create(id)
		if made == null:
			continue
		if not made is Mechanic:
			Log.log(self, "warning",
				"ThingAssembler: type '%s' listed as a mechanic isn't a Mechanic." % id)
			continue
		var mechanic: Mechanic = made as Mechanic
		for fields: Variant in type.parameters.get(Thing.name_of(id), []):
			mechanic.data = ThingVariant.merge(mechanic.data, fields) as Dictionary
		owner.add_mechanic(mechanic)

func assemble(instance: RefCounted, type: ThingType, catalog: ThingCatalog) -> RefCounted:
	if instance == null or type == null:
		return instance
	if instance is Thing:
		_attach_mechanics(instance as Thing, type, catalog)
	return instance
