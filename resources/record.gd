# Record — typed snapshot of player choices or system state that
# lives between systems (UI → UI handoff, UI → engine handoff, Memento
# save fields). It's the third tier alongside Def and Thing:
#
#   Def        (Resource) — catalogue / schema loaded from JSON.
#                            "What types exist in the game."
#   Record   (RefCounted) — typed choice or computed snapshot, lives
#                            in The.board and is passed between
#                            systems. "What was chosen / computed."
#   Thing      (Node)      — live game object in the SceneTree,
#                            receives Cmds via Air, has parts. "A
#                            piece of the game world."
#
# When to use Record:
#   • Maleta UI builds it, Board reads it
#   • Worldgen accepts Laser / MapSize Snapshots
#   • Save game stores typed snapshots instead of raw Dictionaries
#
# Subclasses declare their fields (typed vars, enums) and optionally
# carry a `_def: Def` reference. Override `to_snapshot()` / `from_snapshot()`
# to plug into The's snapshot/restore cycle.
#
# See docs/D5STAR.md §3-tier data architecture for the full picture.
extends RefCounted
class_name Record

# Optional reference to the Def that schemas this Record. Subclasses
# may ignore it when the snapshot is standalone (no underlying Def).
var _def: Def = null

# Returns the underlying Def, or null when the Record is standalone.
func def() -> Def:
	return _def

# i18n helper. Two modes:
#   • Pass a key (String): looked up in the Def's data when present,
#     then resolved through I18n with the locale-aware fallback.
#   • Pass a {pt, en, …} Dictionary directly: resolved through I18n.
# Returns `default_value` if nothing matches.
func text(key_or_dict: Variant, default_value: String = "") -> String:
	if key_or_dict is String and _def != null:
		var data: Variant = _def.get("data")
		if data is Dictionary:
			return I18n.text((data as Dictionary).get(key_or_dict, default_value), default_value)
	return I18n.text(key_or_dict, default_value)

# Memento serialise hook. Override in subclasses that need to survive
# save/load. Default is a no-op so simple Snapshots opt in only when
# needed. The returned Dictionary is what The.snapshot() will record.
func to_snapshot() -> Dictionary:
	return {}

# Memento restore hook. Override to rebuild the Record's typed
# fields from a Dictionary previously produced by to_snapshot(). The
# Def reference is restored by the system that loads the Record
# (typically the UI or the system that owns it).
func from_snapshot(_state: Dictionary) -> void:
	pass
