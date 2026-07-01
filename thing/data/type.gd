# ThingType — the static type/template for a Thing or ThingPart.
# Resolved from JSON by the ThingCatalog, with `ancestor`-chain
# inheritance applied via ThingVariant.merge before storage.
#
# `kind` decides what the catalog instantiates:
#   "thing" (default) → Thing (RefCounted)
#   "part"            → ThingPart (RefCounted)
#
# Both share this Type definition; the difference is solely the
# subclass that materialises an instance from it.
extends Resource
class_name ThingType

var type_id: String = ""
var ancestor: String = ""
var script_id: String = ""
var kind: String = "thing"          # "thing" | "part"
var is_abstract: bool = false        # true = template, cannot be instantiated (see ThingCatalog.create)
var data: Dictionary = {}
var parts: Array[String] = []        # list of part type_ids (only meaningful when kind == "thing")

func attr(key: String, default_value: Variant = null) -> Variant:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return ThingData.format_attr(value)

func text(key: String, default_value: String = "") -> String:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return I18n.text(value, default_value)
