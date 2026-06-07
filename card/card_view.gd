# CardView — clickable visual of a single Card. MVP styling: dark
# panel + colored rarity bar at top + name + flavor text + rarity
# tag at bottom. Hover lightens the border; `picked = true` paints
# the border in the "active" colour so the player sees their
# selection. Subclasses / modders can replace this with art-driven
# cards later — the contract is just `set_card(c)` + the `clicked`
# signal.
class_name CardView
extends Control

signal clicked

var card: Card = null

@export var picked: bool = false:
	set(value):
		picked = value
		_refresh_borders()

const _SIZE: Vector2 = Vector2(200, 280)

const _BG_COLOR: Color     = Color(0.12, 0.10, 0.13)
const _BORDER:    Color    = Color(0.55, 0.50, 0.42)
const _BORDER_PICKED: Color = Color(0.95, 0.30, 0.20)
const _BORDER_HOVER:  Color = Color(0.78, 0.72, 0.58)
const _TITLE_COLOR: Color  = Color(0.86, 0.78, 0.55)
const _FLAVOR_COLOR: Color = Color(0.66, 0.62, 0.55)

const _RARITY_COLORS: Dictionary = {
	"common":   Color(0.55, 0.50, 0.42),
	"uncommon": Color(0.30, 0.65, 0.45),
	"rare":     Color(0.30, 0.50, 0.95),
	"mythic":   Color(0.85, 0.30, 0.20),
}

var _hover: bool = false
var _bg: Panel
var _rarity_bar: ColorRect
var _name_label: Label
var _flavor_label: Label
var _rarity_label: Label

func _ready() -> void:
	custom_minimum_size = _SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh()

func set_card(c: Card) -> void:
	card = c
	_refresh()

func _build_ui() -> void:
	_bg = Panel.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_rarity_bar = ColorRect.new()
	_rarity_bar.position = Vector2.ZERO
	_rarity_bar.size = Vector2(_SIZE.x, 6)
	_rarity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rarity_bar)

	_name_label = Label.new()
	_name_label.position = Vector2(12, 16)
	_name_label.size = Vector2(_SIZE.x - 24, 60)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", _TITLE_COLOR)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_flavor_label = Label.new()
	_flavor_label.position = Vector2(12, 86)
	_flavor_label.size = Vector2(_SIZE.x - 24, 160)
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_flavor_label.add_theme_font_size_override("font_size", 11)
	_flavor_label.add_theme_color_override("font_color", _FLAVOR_COLOR)
	_flavor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flavor_label)

	_rarity_label = Label.new()
	_rarity_label.position = Vector2(12, _SIZE.y - 22)
	_rarity_label.size = Vector2(_SIZE.x - 24, 14)
	_rarity_label.add_theme_font_size_override("font_size", 9)
	_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rarity_label)

func _refresh() -> void:
	if _name_label == null:
		return
	if card == null:
		_name_label.text = ""
		_flavor_label.text = ""
		_rarity_label.text = ""
		return
	_name_label.text = card.name_text()
	_flavor_label.text = card.flavor_text()
	_rarity_label.text = card.rarity.to_upper()
	var rarity_color: Color = _RARITY_COLORS.get(card.rarity, _BORDER)
	_rarity_bar.color = rarity_color
	_rarity_label.add_theme_color_override("font_color", rarity_color)
	_refresh_borders()

func _refresh_borders() -> void:
	if _bg == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = _BG_COLOR
	var border_color: Color = _BORDER_PICKED if picked else (_BORDER_HOVER if _hover else _BORDER)
	sb.border_color = border_color
	sb.set_border_width_all(3 if picked else 2)
	sb.set_corner_radius_all(4)
	_bg.add_theme_stylebox_override("panel", sb)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		_refresh_borders()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		_refresh_borders()
