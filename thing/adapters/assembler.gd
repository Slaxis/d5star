# ThingAssembler — given an instance and its resolved ThingType,
# creates the parts declared by the type and wires them in.
#
# Parts are ThingParts (RefCounted) — wired via `part.attach(owner)`
# which subscribes the part's `_on_thought` into the owner's
# ThingAir. No scene tree involvement.
#
# Parts only get assembled onto Things; if the resolved type isn't a
# Thing (e.g. it's itself a Part being instantiated standalone for
# inspection), assemble is a no-op on the parts list.
extends RefCounted
class_name ThingAssembler

func _attach_parts(owner: Thing, part_ids: Array[String], catalog: ThingCatalog) -> void:
	if owner == null:
		return
	for part_id: String in part_ids:
		var part_obj: RefCounted = catalog.create(part_id)
		if part_obj == null:
			continue
		if not part_obj is ThingPart:
			Log.log(self, "warning",
				"ThingAssembler: type '%s' listed in parts isn't a ThingPart (kind != 'part')." % part_id)
			continue
		owner.add_part(part_obj as ThingPart)

func assemble(instance: RefCounted, type: ThingType, catalog: ThingCatalog) -> RefCounted:
	if instance == null or type == null:
		return instance
	if instance is Thing:
		_attach_parts(instance as Thing, type.parts, catalog)
	return instance
