# ThingData — base for everything in the Thing trinity that carries
# data and reacts to thoughts.
#
# Subclasses:
#   - Thing       (an entity — owns parts, dispatches its own thoughts)
#   - ThingPart   (a behavior plugged into a Thing — reacts to its bus)
#
# Both have a `data: Dictionary` (the canonical payload), the
# `attr()` / `text()` helpers for typed reads, and a duck-typed
# `_on_thought(cmd)` hook that subclasses override to react.
#
# Pure RefCounted — never a Node. Materialising a Thing/ThingPart in
# the scene tree is an upstream concern (H3X4X has `Piece` for
# board-tile entities; game modules add concrete subclasses there).
extends RefCounted
class_name ThingData

var data: Dictionary = {}

# Normalise leaf values so consumers don't have to handle case /
# whitespace differences on every read. Kept static + on ThingData
# (not Thing) so ThingType + others can call without owning a Thing.
static func format_attr(value: Variant) -> Variant:
	if value is String:
		return String(value).strip_edges().to_lower()
	return value

# Typed read with default. The key is the JSON field name; the value
# is normalised through `format_attr` so callers can assume canonical
# form for strings.
func attr(key: String, default_value: Variant = null) -> Variant:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return format_attr(value)

# Bilingual text resolution — `data[key]` is expected to be either a
# raw string or an `{ "pt": ..., "en": ... }` dict; I18n picks the
# active language.
func text(key: String, default_value: String = "") -> String:
	if key == "":
		return default_value
	var value: Variant = data.get(key, default_value)
	return I18n.text(value, default_value)

# Duck-typed thought reaction. Subclasses override to do something
# useful; the base no-op lets ThingData stand in wherever the engine
# expects a "thinkable" object without forcing every subclass to
# declare an empty handler.
func _on_thought(_cmd: Cmd) -> void:
	pass
