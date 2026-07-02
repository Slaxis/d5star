# CardView — traditional Magic-style card layout for a single Card.
#
# Layout (220×340):
#   • Header: name (left) + cost circle (right). Cost is derived from
#     the (rarity × tier) Fibonacci grid — character creation cards
#     all display their HP cost up-front. Rarity itself is NOT shown
#     on the card; it's a back-end weight, not player-facing info.
#   • Image plate — neutral placeholder (the card's **background**
#     carries the casta colour, not the image).
#   • Type bar, LEFT-aligned.
#   • Stats badges — `payload.stat_modifiers` rendered as pill-shaped
#     panels in an HFlowContainer (wraps on overflow). Each badge
#     wears its stat's colour; the label is centred and compact
#     ("+1FOR" / "-1INT").
#   • Flavor text inside a framed moldura panel (smaller font).
#
# The whole card panel is tinted with the **class colour** from
# `card.payload.class_id`, darkened for legibility. No class_id →
# neutral dark frame.
class_name CardView
extends Control

signal clicked

var card: Card = null

@export var picked: bool = false:
	set(value):
		picked = value
		_refresh_borders()

const _SIZE: Vector2 = Vector2(220, 340)

# HeP currency glyph. Greek capital Omega — ties to the Greek
# Command Point family (Ethos / Metis / Pathos / Logos / Pistis)
# and reads as "ultimate" / "heroic" without colliding with any
# of the per-CP glyphs (▲ ◆ ● ■ ★).
const _HEP_GLYPH: String        = "Ω"

# Card-wide neutral base — the dark colour the shader's tint_a maps
# to. White text reads on this regardless of which casta the card
# belongs to, because the casta colour appears ONLY in the pattern
# accent, never as the bulk fill.
const _CARD_DARK: Color         = Color(0.10, 0.09, 0.11)

# Border: thick rounded black, Magic-style.
const _BORDER: Color            = Color(0.0, 0.0, 0.0)
const _BORDER_PICKED: Color     = Color(0.95, 0.30, 0.20)
const _BORDER_HOVER: Color      = Color(0.40, 0.38, 0.34)
const _BORDER_WIDTH: int        = 4
const _BORDER_WIDTH_PICKED: int = 6
const _BORDER_RADIUS: int       = 10

# Font colour palette — neutral white/gray family. The old warm
# tan/gold readout was bleeding casta colour into text channels;
# clean whites make the colour identity belong to the shader alone.
const _TITLE_COLOR: Color       = Color(1.0, 1.0, 1.0)
const _COST_RING_COLOR: Color   = Color(0.92, 0.84, 0.40)
const _TYPE_COLOR: Color        = Color(0.78, 0.78, 0.78)
const _FLAVOR_COLOR: Color      = Color(0.85, 0.85, 0.85)
const _FLAVOR_FRAME_BG: Color   = Color(0.05, 0.05, 0.06, 0.65)
const _FLAVOR_FRAME_BORDER: Color = Color(0.20, 0.20, 0.22, 0.7)
const _NEUTRAL_IMAGE: Color     = Color(0.06, 0.05, 0.07)

# Sugar Loaf casta palette — each casta is monochromatic on its
# own hue (2 tones of the same colour), so the card reads as a
# tone-on-tone composition instead of one neutral background with
# a coloured accent. MILITES carries a 3rd tone because real camo
# needs a contrasting earth-brown beside the two greens. Optional
# `c` field is read only when the casta's pattern returns 0.5
# (currently camo's mid zone).
#
# a = primary / bulk fill
# b = secondary / pattern accent
# c = tertiary (camo only)
const _CLASS_TINTS: Dictionary = {
	"domini":  { "a": Color("#CDA52F"), "b": Color("#876614") },   # tarnished gold + dark tarnish
	"clerus":  { "a": Color("#E8E1CE"), "b": Color("#D0C5AA") },   # aged linen + weathered cream
	"milites": { "a": Color("#58683A"), "b": Color("#2D3520"), "c": Color("#3C2E1F") },   # dusty forest camo
	"subditi": { "a": Color("#3A5A8B"), "b": Color("#1E3460") },   # faded denim cobalt
	"captivi": { "a": Color("#A5342D"), "b": Color("#6A2422") },   # brick-rust red + dried brick
	"exsules": { "a": Color("#5F4078"), "b": Color("#341E44") },   # muted violet + dark mauve
}

# Per-class shader knobs — each casta gets its own dedicated
# pattern with its own dream visualisation:
#   DOMINI 🟡 honeycomb of gold (mode 6)        — colmeia que come ouro
#   CLERUS ⚪ fleur-de-lis (mode 7)              — lençol chique do alto clero
#   MILITES 🟢 3-tone camo (mode 8)              — preto/branco sobre verde
#   SUBDITI 🔵 carteira de trabalho weave (mode 9) — textura de capa
#   CAPTIVI 🔴 thin blood drops (mode 10)        — sangue magro terroso
#   EXSULES 🟣 mist (mode 11)                    — invisíveis
#
# Vignette is OFF across the board — the texture itself carries the
# casta identity; framing dimming was making the corners read as a
# smudge.
const _CLASS_TEXTURE: Dictionary = {
	"domini":  { "pattern_mode":  6, "pixel_size": 3.0 },
	"clerus":  { "pattern_mode":  7, "pixel_size": 2.0 },
	"milites": { "pattern_mode":  8, "pixel_size": 4.0 },
	"subditi": { "pattern_mode":  9, "pixel_size": 2.0 },
	"captivi": { "pattern_mode": 10, "pixel_size": 3.0 },
	"exsules": { "pattern_mode": 11, "pixel_size": 3.0 },
}

const _DEFAULT_TEXTURE: Dictionary = {
	"pattern_mode": 0, "pixel_size": 3.0,
}

# Arcano texture — Mario invincibility-star shimmer. Animated rainbow
# sweep, ignores tints entirely (the shader produces its own RGB on
# pattern_mode 12). Larger pixel_size for chunkier "pixel-art star"
# feel that matches the source inspiration.
const _ARCANO_TEXTURE: Dictionary = {
	"pattern_mode": 12, "pixel_size": 4.0,
}

const _TYPE_LABELS: Dictionary = {
	"ancestrais": "ANCESTRAL",
	"origem":     "ORIGEM",
	"mentor":     "MENTOR",
	"arcano":     "ARCANO",
	"start_tile": "ABRIGO",
}

# CLAUDE: stat lookups duplicated from game/defs/stats.gd because
# engine code can't depend on game layer (CardView lives in D5Star,
# Stats catalogue is Sugar Loaf-specific). Future refactor: hoist
# stat metadata as injectable via a Callable on CardView, then Sugar
# Loaf code plugs Stats.color / Stats.abbr. For now the duplication
# is small and tolerable; keep the two tables in sync.
const _STAT_ABBR: Dictionary = {
	"forca": "FOR", "vitalidade": "VIT",
	"agilidade": "AGI", "destreza": "DEX",
	"carisma": "CAR", "sabedoria": "SAB",
	"inteligencia": "INT", "percepcao": "PER",
	"vontade": "VON", "intuicao": "INU",
}

const _STAT_COLORS: Dictionary = {
	"forca":        Color("#C46B2C"),    # brutalidade active, lighter
	"vitalidade":   Color("#B23B2E"),    # brutalidade defensive, darker
	"agilidade":    Color("#B8722A"),    # finesse defensive, darker
	"destreza":     Color("#E0A82A"),    # finesse active, lighter
	"carisma":      Color("#5BAA52"),    # empatia active, lighter
	"sabedoria":    Color("#3B6F35"),    # empatia defensive, darker
	"inteligencia": Color("#6EA7C9"),    # cognição active, lighter
	"percepcao":    Color("#4570AA"),    # cognição defensive, darker
	"vontade":      Color("#9C7DC9"),    # psique active, lighter
	"intuicao":     Color("#6B3B95"),    # psique defensive, darker
}

# stat → stat-group → Command Point, duplicated here for the same
# reason as the stat tables above (engine can't reach into game/).
const _STAT_TO_GROUP: Dictionary = {
	"forca": "brutalidade", "vitalidade": "brutalidade",
	"agilidade": "finesse", "destreza": "finesse",
	"carisma": "empatia", "sabedoria": "empatia",
	"inteligencia": "cognicao", "percepcao": "cognicao",
	"vontade": "psique", "intuicao": "psique",
}

const _GROUP_TO_CP: Dictionary = {
	"brutalidade": "ethos",
	"finesse":     "metis",
	"empatia":     "pathos",
	"cognicao":    "logos",
	"psique":      "pistis",
}

const _CP_GLYPHS: Dictionary = {
	"ethos":  "▲",
	"metis":  "◆",
	"pathos": "●",
	"logos":  "■",
	"pistis": "★",
}

# Per-group chip glyph — duplicated from game/defs/stats.gd's
# GROUP_ICONS for the same reason as the stat tables above (engine
# can't reach into game/). Each modifier on a card renders as N
# copies of this glyph: "+2 DEX" → ✋✋ in green; "-1 FOR" → 🔥
# in red. Colour comes from sign, not from stat colour.
const _GROUP_ICONS: Dictionary = {
	"brutalidade": "🔥",
	"finesse":     "✋",
	"empatia":     "♥",
	"cognicao":    "👁",
	"psique":      "★",
}

const _CHIP_GREEN: Color = Color(0.55, 0.85, 0.40)
const _CHIP_RED:   Color = Color(0.95, 0.30, 0.25)

const _CP_COLORS: Dictionary = {
	"ethos":  Color("#B23B2E"),
	"metis":  Color("#D4942A"),
	"pathos": Color("#4A8B43"),
	"logos":  Color("#4570AA"),
	"pistis": Color("#7B4FA8"),
}

const _TEXTURE_SHADER: Shader = preload("res://engine/d5star/card/card_texture.gdshader")

var _hover: bool = false

var _bg_rect: ColorRect          # textured fill (shader does the work)
var _bg_material: ShaderMaterial
var _bg: Panel                   # transparent panel — only carries the border + rounded corners
var _name_label: Label
var _cost_box: HBoxContainer
const _COIN_SIZE: int = 11
const _COIN_RADIUS: int = 6     # ceil(_COIN_SIZE / 2) — perfectly round corners
const _COIN_SEPARATION: int = 1
var _image_plate: ColorRect
var _type_label: Label
var _stats_flow: HFlowContainer
var _alignment_row: HFlowContainer   # morality + obedience chips, sits above _stats_flow
var _payload_box: VBoxContainer      # vertical wrapper: alignment on top, stats below
var _flavor_frame: Panel
var _flavor_label: Label

func _ready() -> void:
	custom_minimum_size = _SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh()

func set_card(c: Card) -> void:
	card = c
	_refresh()

# ─── UI construction ────────────────────────────────────────────

func _build_ui() -> void:
	# Textured background — ColorRect carries a ShaderMaterial that
	# does the actual painting (tint + noise + vignette + gradient).
	# Inset a couple of pixels so the Panel's border drawn on top of
	# it reads as a frame around the texture rather than overlapping.
	_bg_rect = ColorRect.new()
	_bg_rect.color = Color.WHITE
	_bg_rect.anchor_left = 0.0
	_bg_rect.anchor_top = 0.0
	_bg_rect.anchor_right = 1.0
	_bg_rect.anchor_bottom = 1.0
	_bg_rect.offset_left = 2
	_bg_rect.offset_top = 2
	_bg_rect.offset_right = -2
	_bg_rect.offset_bottom = -2
	# Match the project-wide pixel-art aesthetic — NEAREST sampling
	# keeps the shader's discrete patterns crispy instead of letting
	# the canvas pipeline blur them.
	_bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg_material = ShaderMaterial.new()
	_bg_material.shader = _TEXTURE_SHADER
	_bg_rect.material = _bg_material
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	# Border-only Panel on top of the textured fill — the StyleBoxFlat
	# has transparent bg_color so only the border + rounded corners
	# show.
	_bg = Panel.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Name (top, full width) — Magic-4ed style: pure white with a
	# black outline so the text reads on any casta tint (light cream
	# CLERUS, dark violet EXSULES, gold DOMINI…). No panel behind.
	# Title gets its OWN row (the cost coins now live in a separate
	# row below) so even long names like "PASTOR TELEVANGELISTA"
	# breathe full-width without competing with the cost token.
	_name_label = Label.new()
	_name_label.position = Vector2(12, 8)
	_name_label.size = Vector2(_SIZE.x - 24, 22)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", _TITLE_COLOR)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	# Cost row — left-aligned under the title (not top-right). N
	# small Ω coins; one per HeP. Coins are tiny (11×11) status
	# tokens, sized small on purpose to leave the title room to
	# breathe. The actual coin Panels are built inside
	# `_rebuild_cost_coins(n)` so the count tracks the card.
	_cost_box = HBoxContainer.new()
	_cost_box.position = Vector2(12, 32)
	_cost_box.size = Vector2((_COIN_SIZE + _COIN_SEPARATION) * 5, _COIN_SIZE)
	_cost_box.add_theme_constant_override("separation", _COIN_SEPARATION)
	_cost_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_box)

	# Image plate — placeholder until art ships. The plate is set
	# slightly inset relative to the casta-tinted bg, and four thin
	# bevel rects on its edges sell the "recessed" / window-into-
	# the-card feel (dark shadow on top + left where light would
	# fall onto the inset, lighter highlight on bottom + right
	# where the bottom of the inset catches reflected light).
	var img_pos := Vector2(14, 48)
	var img_size := Vector2(_SIZE.x - 28, 66)
	_image_plate = ColorRect.new()
	_image_plate.position = img_pos
	_image_plate.size = img_size
	_image_plate.color = _NEUTRAL_IMAGE
	_image_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image_plate)
	# Recessed bevel: 2 dark edges on top + left, 1 lighter on
	# bottom + right.
	var top_shadow := ColorRect.new()
	top_shadow.position = img_pos
	top_shadow.size = Vector2(img_size.x, 2)
	top_shadow.color = Color(0.0, 0.0, 0.0, 0.5)
	top_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_shadow)
	var left_shadow := ColorRect.new()
	left_shadow.position = img_pos
	left_shadow.size = Vector2(2, img_size.y)
	left_shadow.color = Color(0.0, 0.0, 0.0, 0.5)
	left_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_shadow)
	var bottom_hl := ColorRect.new()
	bottom_hl.position = Vector2(img_pos.x, img_pos.y + img_size.y - 1)
	bottom_hl.size = Vector2(img_size.x, 1)
	bottom_hl.color = Color(1.0, 1.0, 1.0, 0.18)
	bottom_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_hl)
	var right_hl := ColorRect.new()
	right_hl.position = Vector2(img_pos.x + img_size.x - 1, img_pos.y)
	right_hl.size = Vector2(1, img_size.y)
	right_hl.color = Color(1.0, 1.0, 1.0, 0.18)
	right_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_hl)

	# Type bar — LEFT-aligned, Magic-4ed style outline like the
	# title so the type reads on any casta tint without a panel.
	_type_label = Label.new()
	_type_label.position = Vector2(12, 120)
	_type_label.size = Vector2(_SIZE.x - 24, 16)
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_type_label.add_theme_font_size_override("font_size", 10)
	_type_label.add_theme_color_override("font_color", _TYPE_COLOR)
	_type_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_type_label.add_theme_constant_override("outline_size", 3)
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_type_label)

	# Payload badges — VBox with alignment row on TOP (moral/obed
	# shifts) and stats HFlow on BOTTOM. Reading order matches the
	# ficha's payload summary: identity axes (moral/obed) frame the
	# stat gains that describe what the character DOES.
	_payload_box = VBoxContainer.new()
	_payload_box.position = Vector2(10, 140)
	_payload_box.size = Vector2(_SIZE.x - 20, 50)
	_payload_box.add_theme_constant_override("separation", 3)
	_payload_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_payload_box)

	_alignment_row = HFlowContainer.new()
	_alignment_row.add_theme_constant_override("h_separation", 6)
	_alignment_row.add_theme_constant_override("v_separation", 2)
	_alignment_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_payload_box.add_child(_alignment_row)

	_stats_flow = HFlowContainer.new()
	_stats_flow.add_theme_constant_override("h_separation", 4)
	_stats_flow.add_theme_constant_override("v_separation", 4)
	_stats_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_payload_box.add_child(_stats_flow)

	# Flavor frame (moldura) — a RAISED panel sitting on the card
	# surface (opposite of the inset image plate): light highlight
	# on top + left where light hits the top of the bump, dark
	# shadow on bottom + right where the bump casts its own shadow
	# onto the card. The interior is a dark translucent overlay so
	# white flavor text reads regardless of casta tint underneath.
	var flv_pos := Vector2(12, 196)
	var flv_size := Vector2(_SIZE.x - 24, _SIZE.y - 196 - 12)
	_flavor_frame = Panel.new()
	_flavor_frame.position = flv_pos
	_flavor_frame.size = flv_size
	_flavor_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flavor_frame)
	# Raised bevel: 1 light edge on top + left, 1-2 darker edges on
	# bottom + right.
	var top_hl := ColorRect.new()
	top_hl.position = flv_pos
	top_hl.size = Vector2(flv_size.x, 1)
	top_hl.color = Color(1.0, 1.0, 1.0, 0.30)
	top_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_hl)
	var left_hl := ColorRect.new()
	left_hl.position = flv_pos
	left_hl.size = Vector2(1, flv_size.y)
	left_hl.color = Color(1.0, 1.0, 1.0, 0.30)
	left_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_hl)
	var bottom_sh := ColorRect.new()
	bottom_sh.position = Vector2(flv_pos.x, flv_pos.y + flv_size.y - 2)
	bottom_sh.size = Vector2(flv_size.x, 2)
	bottom_sh.color = Color(0.0, 0.0, 0.0, 0.55)
	bottom_sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_sh)
	var right_sh := ColorRect.new()
	right_sh.position = Vector2(flv_pos.x + flv_size.x - 2, flv_pos.y)
	right_sh.size = Vector2(2, flv_size.y)
	right_sh.color = Color(0.0, 0.0, 0.0, 0.55)
	right_sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_sh)

	_flavor_label = Label.new()
	_flavor_label.position = Vector2(8, 6)
	_flavor_label.size = Vector2(_flavor_frame.size.x - 16, _flavor_frame.size.y - 12)
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_flavor_label.add_theme_font_size_override("font_size", 9)
	_flavor_label.add_theme_color_override("font_color", _FLAVOR_COLOR)
	_flavor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flavor_frame.add_child(_flavor_label)

	_refresh_flavor_frame()

# ─── State sync ─────────────────────────────────────────────────

func _refresh() -> void:
	if _name_label == null:
		return
	if card == null:
		_name_label.text = ""
		_type_label.text = ""
		_flavor_label.text = ""
		_rebuild_cost_coins(0)
		_clear_stats()
		return
	_name_label.text = card.name_text()
	_resize_name_for(card.name_text())
	# All ancestrais (and char-creation cards in general) cost HeP —
	# rendered as N literal Ω coins. CP-tagged costs are reserved
	# for in-game gameplay cards (minor arcana / trunfo plays).
	_rebuild_cost_coins(card.cost)
	_type_label.text = String(_TYPE_LABELS.get(card.deck_id, card.deck_id.to_upper()))
	_flavor_label.text = card.flavor_text()
	_refresh_bg(card)
	_refresh_flavor_frame()
	_rebuild_stats(card.payload.get("stat_modifiers", {}))
	_rebuild_alignment(card.payload)
	_refresh_borders()

# Derives the dominant Command Point family from the card's stat
# modifiers — sums the positive modifiers by CP family (each stat
# belongs to one group, each group generates one CP), returns the
# CP with the highest total. Negative modifiers are ignored on this
# pass (an ancestral that hurts a stat still doesn't "thematise"
# around that CP). Ties are broken by iteration order, which is
# stable for a given JSON layout. Empty / all-zero / no-positive
# stat blocks return "" — caller hides the glyph.
func _primary_cp(mods: Variant) -> String:
	if not mods is Dictionary:
		return ""
	var totals: Dictionary = {}
	for stat_id_v: Variant in (mods as Dictionary).keys():
		var stat_id: String = String(stat_id_v)
		var value: int = int((mods as Dictionary)[stat_id_v])
		if value <= 0:
			continue
		var group: String = String(_STAT_TO_GROUP.get(stat_id, ""))
		if group == "":
			continue
		var cp: String = String(_GROUP_TO_CP.get(group, ""))
		if cp == "":
			continue
		totals[cp] = int(totals.get(cp, 0)) + value
	var best_cp: String = ""
	var best_total: int = 0
	for cp_id_v: Variant in totals.keys():
		var t: int = int(totals[cp_id_v])
		if t > best_total:
			best_total = t
			best_cp = String(cp_id_v)
	return best_cp

# Auto-shrink the name font when a title is too long to fit on the
# 2-line header in the default 13 px size. Three buckets — long names
# drop to 11 px, ultra-long to 10 px. Anything past 28 chars is on
# the author to shorten.
func _resize_name_for(text: String) -> void:
	if _name_label == null:
		return
	var fs: int = 13
	var n: int = text.length()
	if n > 16:
		fs = 11
	if n > 22:
		fs = 10
	_name_label.add_theme_font_size_override("font_size", fs)

func _rebuild_stats(mods: Variant) -> void:
	_clear_stats()
	if not mods is Dictionary:
		return
	var dict: Dictionary = mods
	for key_v: Variant in dict.keys():
		var key: String = String(key_v)
		var value: int = int(dict[key_v])
		if value == 0:
			continue
		_stats_flow.add_child(_make_chip_strip(key, value))

# Chip strip — `magnitude` copies of the stat's pixel-art icon
# (10×10 native, crisp NEAREST). Positive modifiers render in the
# stat's canonical colour (FOR red, DEX amber, INT cobalt …);
# negative modifiers render in a universal penalty red so a `-1 FOR`
# reads as "penalty" at a glance even though it shares the colour
# slot with brutalidade-positive icons.
#
# StatIcons lives in game/defs/ but is class_name-registered globally
# so the engine layer can reference it. This breaks the strict
# "engine doesn't know about Sugar Loaf" rule for visual consistency
# — refactor when another game module needs different icons.
func _make_chip_strip(stat_id: String, value: int) -> Control:
	var box := HBoxContainer.new()
	# PASS lets the tooltip fire on hover while click events still
	# bubble up to CardView (so the card stays clickable).
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.tooltip_text = "%s %s" % [
		Alignment.sign_str(value),
		String(Stats.NAMES_PT.get(stat_id, stat_id)),
	]
	box.add_theme_constant_override("separation", 2)
	var is_negative: bool = value < 0
	for i: int in absi(value):
		# make_stat_chip wraps the icon in a 1px drop shadow + (when
		# negative) dims it to gray with a red minus bar overlaid.
		# Without this wrapper the negative variant rendered in
		# brutalidade-red and was indistinguishable from positive
		# brutalidade chips.
		box.add_child(StatIcons.make_stat_chip(stat_id, is_negative, 1))
	return box

func _clear_stats() -> void:
	if _stats_flow != null:
		for child: Node in _stats_flow.get_children():
			child.queue_free()
	if _alignment_row != null:
		for child: Node in _alignment_row.get_children():
			child.queue_free()

# Alignment shift chips — one icon per magnitude, tinted green
# (positive shift) or red (negative). Mirrors the ficha's morality
# / obedience row (heart / skull for morality, circle / triangle
# for obedience). Rendered INSIDE `_stats_flow` right after the
# stat chips so the whole payload effect reads as one inline row.
# Zero shifts are skipped to keep the flow compact.
func _rebuild_alignment(payload: Variant) -> void:
	if not payload is Dictionary:
		return
	var payload_dict: Dictionary = payload
	var mor: int = Alignment.parse_shift(payload_dict.get("morality_shift", 0))
	var obd: int = Alignment.parse_shift(payload_dict.get("obedience_shift", 0))
	if mor != 0:
		_alignment_row.add_child(_make_alignment_strip("morality", mor))
	if obd != 0:
		_alignment_row.add_child(_make_alignment_strip("obedience", obd))

# One HBox of `|value|` alignment icons for a single axis. Icon
# name + color follow the ficha convention so both surfaces read
# identically to the player.
func _make_alignment_strip(axis: String, value: int) -> Control:
	var box := HBoxContainer.new()
	# PASS: tooltip fires but clicks still reach the card.
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 2)
	var icon_name: String
	var axis_label: String
	var band_label: String
	if axis == "morality":
		icon_name = "heart" if value > 0 else "skull"
		axis_label = "Moralidade"
		band_label = Alignment.morality_label(value)
	else:
		icon_name = "circle" if value > 0 else "triangle"
		axis_label = "Obediência"
		band_label = Alignment.obedience_label(value)
	box.tooltip_text = "%s %s (%s)" % [
		axis_label, Alignment.sign_str(value), band_label,
	]
	var color: Color = _CHIP_GREEN if value > 0 else _CHIP_RED
	for i: int in absi(value):
		box.add_child(StatIcons.make_alignment_chip(icon_name, color, 1))
	return box

# Build N small Ω coins inside the cost HBox. Each coin is a tiny
# circular Panel (StyleBoxFlat with corner_radius = _COIN_SIZE / 2)
# with a small Ω label centred inside. Re-emitted on every refresh
# so the count tracks the card.
func _rebuild_cost_coins(n: int) -> void:
	if _cost_box == null:
		return
	for child: Node in _cost_box.get_children():
		child.queue_free()
	for i: int in n:
		var coin := Panel.new()
		coin.custom_minimum_size = Vector2(_COIN_SIZE, _COIN_SIZE)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.03, 0.04, 0.9)
		sb.border_color = _COST_RING_COLOR
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(_COIN_RADIUS)
		coin.add_theme_stylebox_override("panel", sb)
		var label := Label.new()
		label.text = _HEP_GLYPH
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", _COST_RING_COLOR)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.add_child(label)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cost_box.add_child(coin)

func _refresh_flavor_frame() -> void:
	if _flavor_frame == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = _FLAVOR_FRAME_BG
	sb.border_color = _FLAVOR_FRAME_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	_flavor_frame.add_theme_stylebox_override("panel", sb)

func _refresh_bg(c: Card) -> void:
	if _bg == null:
		return
	# Tone-on-tone texture: tint_a is the casta's primary fill, tint_b
	# the casta's secondary accent (same hue, slightly different
	# value). MILITES carries an optional tint_c (earth-brown) the
	# camo pattern uses for its mid zone — for every other casta
	# tint_c stays equal to tint_b and the shader's 3-tone path
	# collapses to 2-tone.
	# Arcanos are class-agnostic — they get the Mario-star shimmer
	# instead of a casta-bound pattern. The shader ignores tints in
	# mode 12, but we still set them to neutral dark so any leftover
	# values from a previous card don't bleed through.
	var category: String = String(c.payload.get("category", ""))
	var is_arcano: bool = category == "arcano"
	var class_id: String = String(c.payload.get("class_id", ""))
	# Single-casta decks (travessia today, potentially others in the
	# future) don't set `payload.class_id` — they live in their own
	# deck and only declare their casta via top-level `class_affinity`.
	# Fall back to the first affinity tag so the card picks up the
	# casta's tint + pattern (DOMINI honeycomb gold, CLERUS fleur, etc.).
	# Gated by category so multi-affinity decks (governanca, doutrina,
	# economia) don't arbitrarily pick their first tag as color.
	if class_id == "" and category == "travessia" and c.class_affinity.size() > 0:
		class_id = String(c.class_affinity[0])
	var tints: Dictionary = _CLASS_TINTS.get(class_id, {
		"a": _CARD_DARK, "b": _CARD_DARK,
	})
	if _bg_material != null:
		_bg_material.set_shader_parameter("tint_a", tints.get("a", _CARD_DARK))
		_bg_material.set_shader_parameter("tint_b", tints.get("b", _CARD_DARK))
		_bg_material.set_shader_parameter("tint_c", tints.get("c", tints.get("b", _CARD_DARK)))
		var tex: Dictionary = _ARCANO_TEXTURE if is_arcano else _CLASS_TEXTURE.get(class_id, _DEFAULT_TEXTURE)
		_bg_material.set_shader_parameter("pattern_mode", int(tex.get("pattern_mode", 0)))
		_bg_material.set_shader_parameter("pixel_size", float(tex.get("pixel_size", 3.0)))
		_bg_material.set_shader_parameter("card_size", _SIZE)
	# Magic-style outer border — thick rounded black, with a
	# crimson accent when picked and a subtle grey on hover.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var border_color: Color = _BORDER_PICKED if picked else (_BORDER_HOVER if _hover else _BORDER)
	sb.border_color = border_color
	sb.set_border_width_all(_BORDER_WIDTH_PICKED if picked else _BORDER_WIDTH)
	sb.set_corner_radius_all(_BORDER_RADIUS)
	_bg.add_theme_stylebox_override("panel", sb)

func _refresh_borders() -> void:
	# Border state changes on hover/picked; the textured fill stays
	# put and only the Panel-border restyles.
	if card != null:
		_refresh_bg(card)
		return
	if _bg == null:
		return
	# Empty card slot — both tints to the dark neutral so the rect
	# reads as a uniform dark placeholder.
	if _bg_material != null:
		_bg_material.set_shader_parameter("tint_a", _CARD_DARK)
		_bg_material.set_shader_parameter("tint_b", _CARD_DARK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var border_color: Color = _BORDER_PICKED if picked else (_BORDER_HOVER if _hover else _BORDER)
	sb.border_color = border_color
	sb.set_border_width_all(_BORDER_WIDTH_PICKED if picked else _BORDER_WIDTH)
	sb.set_corner_radius_all(_BORDER_RADIUS)
	_bg.add_theme_stylebox_override("panel", sb)

func _label_color_on(bg: Color) -> Color:
	# Per WCAG-ish luminance — dark text on light, white text on dark.
	var luma: float = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color.BLACK if luma > 0.55 else Color.WHITE

# ─── Input ───────────────────────────────────────────────────────

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
