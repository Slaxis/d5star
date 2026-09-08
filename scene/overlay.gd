# Overlay — modal sub-UI plugged into a host Scene (Menu or World).
# Does NOT participate in the Flow — it is opened and closed by the
# host scene itself, lives above it on its own CanvasLayer, and
# preserves its state between opens by default.
#
# Lifetime policy:
#  PERSISTENT (default) — close() hides; reopens are cheap and the
#                         overlay's internal state survives.
#  ONE_SHOT             — close() queue_free()s; reopens require a
#                         fresh instantiate. Use for confirmation
#                         popups where stale state would be wrong.
class_name Overlay
extends CanvasLayer

enum Lifetime { PERSISTENT, ONE_SHOT }

@export var lifetime: Lifetime = Lifetime.PERSISTENT

signal closed

var host: Node = null

func open_on(host_scene: Node) -> void:
	host = host_scene
	if get_parent() == null:
		host.add_child(self)
	show()
	_on_opened()

func close() -> void:
	_on_closed()
	closed.emit()
	match lifetime:
		Lifetime.PERSISTENT:
			hide()
		Lifetime.ONE_SHOT:
			queue_free()

func read(key: String) -> Record:
	return The.board.get(key, null) as Record

func write(key: String, sel: Record) -> void:
	The.board[key] = sel

# Subclass hooks — default no-ops.
func _on_opened() -> void: pass
func _on_closed() -> void: pass
