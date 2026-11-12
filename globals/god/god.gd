# God — game-facing service locator. Autoload entry composed of
# four Hubs, each a D5Hub:
#
#   God.things  — ThingHub: Thing system (catalog, lifecycle, content)
#   God.rules   — RuleHub:  active Codex resource + future rule queries
#   God.media   — MediaHub: typed media (texture/shader/sound/scene/script/json)
#                 and the painted sprites (paint/chroma/palette)
#   God.saves   — SaveHub:  the player's files (saved match, hall of fame, settings)
#
# Game code calls God.<hub>.<method>; God itself holds no domain
# logic: it builds the Hubs and connects each to Drive's module
# change, without knowing which of them keeps something of the module,
# and has the saves apply the player's settings, once.
#
# Layer rule: game code → God; engine plumbing → Drive. The Hubs
# call Drive for resolution, never The above them; only Loaders touch
# Godot's resource APIs.
extends Node

var things: ThingHub
var rules: RuleHub
var media: MediaHub
var saves: SaveHub

func _ready() -> void:
	things = ThingHub.new()
	rules = RuleHub.new()
	media = MediaHub.new()
	saves = SaveHub.new()
	for hub: D5Hub in hubs():
		Drive.active_module_changed.connect(hub.on_module_changed)
	saves.apply_settings(saves.load_settings())

# Every Hub of God, in the order they hear the module change.
func hubs() -> Array[D5Hub]:
	var all: Array[D5Hub] = [things, rules, media, saves]
	return all
