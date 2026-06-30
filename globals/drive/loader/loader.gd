# Loader — base for pluggable resource loaders dispatched by file
# extension. Each concrete loader handles one or more extensions
# and wraps the actual `load()` call so the engine never reaches
# into Godot's resource APIs from outside this folder.
#
# ResourceManager discovers loaders at boot (auto-scans the loaders
# directory the same way ParserManager scans parsers) and routes
# every `load_resource(path)` to the loader whose `extensions()`
# claim the path's extension.
#
# Adding a new type = drop a new subclass here, declare its
# extensions, return the typed resource. Zero touch on the Manager.
class_name Loader
extends RefCounted

# File extensions this loader handles, lowercase, no leading dot
# (e.g. `["png", "jpg"]`). One loader can claim several when the
# underlying Godot resource type is the same.
func extensions() -> Array[String]:
	return []

# Load the resource from a resolved path. Subclasses encapsulate
# the Godot `load()` (or FileAccess) call here. Return null on
# failure — ResourceManager logs and propagates.
func load_resource(_path: String) -> Variant:
	return null
