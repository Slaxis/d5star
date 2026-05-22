# ThingAssembler: handles part attachment for Thing instances.
# Stripped of skin/visual logic — parts only.
extends RefCounted
class_name ThingAssembler

func _attach_parts(owner: Node, part_ids: Array[String], catalog: ThingCatalog) -> void:
	if owner == null or not owner.has_method("add_part"):
		return
	for part_id: String in part_ids:
		var part: Node = catalog.create(part_id)
		if part == null:
			continue
		owner.call("add_part", part)

func assemble(instance: Node, type: ThingType, catalog: ThingCatalog) -> Node:
	if instance == null or type == null:
		return instance
	_attach_parts(instance, type.parts, catalog)
	return instance
