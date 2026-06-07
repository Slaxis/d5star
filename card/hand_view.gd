# HandView — horizontal row of CardViews representing one Hand
# (typically 3 cards). Click any card to pick — re-clicking another
# card moves the selection. Emits `card_picked(card)` with the
# chosen Card; callers commit (or wait for a "continuar" button)
# before transitioning out of the step.
class_name HandView
extends HBoxContainer

signal card_picked(card: Card)

const _SEPARATION: int = 24

var _views: Array[CardView] = []
var _picked_idx: int = -1

func _ready() -> void:
	add_theme_constant_override("separation", _SEPARATION)
	alignment = BoxContainer.ALIGNMENT_CENTER

func set_hand(hand: Hand) -> void:
	_clear()
	for i: int in hand.cards.size():
		var view := CardView.new()
		view.set_card(hand.cards[i])
		view.clicked.connect(_on_card_clicked.bind(i))
		add_child(view)
		_views.append(view)

func picked_card() -> Card:
	if _picked_idx < 0 or _picked_idx >= _views.size():
		return null
	return _views[_picked_idx].card

func _on_card_clicked(idx: int) -> void:
	if _picked_idx >= 0 and _picked_idx < _views.size():
		_views[_picked_idx].picked = false
	_picked_idx = idx
	_views[idx].picked = true
	card_picked.emit(_views[idx].card)

func _clear() -> void:
	for v: CardView in _views:
		v.queue_free()
	_views.clear()
	_picked_idx = -1
