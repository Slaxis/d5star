# ThingType — the static type/template for a Thing or a Mechanic.
# Resolved from JSON by the ThingCatalog, with `ancestor`-chain
# inheritance applied via ThingVariant.merge before storage.
#
# `kind` decides the base the catalog falls back to when the type has
# no script of its own nor one up its chain:
#   "thing" (default) → Thing
#   "part"            → Mechanic
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
var mechanics: Array[String] = []    # the ids of the mechanics the catalog plugs into an instance
# The data of the Thing's later layers, which a mod writes over it, each
# merged over the data before it when the type is resolved (Mesclar, J188).
var layers: Array[Dictionary] = []

func attr(key: String, default_value: Variant = null) -> Variant:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return Thing.format_attr(value)

func text(key: String, default_value: String = "") -> String:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return I18n.text(value, default_value)
