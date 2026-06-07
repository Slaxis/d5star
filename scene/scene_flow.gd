# Lifecycle + Flow contract shared by every Scene adapter (Menu, World).
# The adapter (Control / Node2D / …) holds a SceneFlow via composition
# and exposes its API through thin wrappers — the underlying Godot node
# type stays free to do its own thing, the brain centralises the bits
# that talk to the Flow runtime and to The.session.
class_name SceneFlow
extends RefCounted

# Step metadata — Flow injects these before the adapter's _on_enter runs.
var flow_step: Dictionary = {}
var flow_id: String = ""

func consumes() -> Array:
	return flow_step.get("consumes", [])

func produces() -> Array:
	return flow_step.get("produces", [])

func transitions() -> Dictionary:
	return flow_step.get("transitions", {})

# --- Session helpers ---
# Typed read/write against The.session. Selection is the engine's
# cargo type — see docs/D5STAR.md §5.

func read(key: String) -> Selection:
	return The.session.get(key, null) as Selection

func write(key: String, sel: Selection) -> void:
	The.session[key] = sel
