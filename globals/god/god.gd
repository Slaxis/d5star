# God — game-facing service locator. Autoload entry composed of
# three Hubs, each a D5Hub:
#
#   God.things  — ThingHub: Thing system (catalog, lifecycle, content)
#   God.rules   — RuleHub:  active Codex resource + future rule queries
#   God.media   — MediaHub: typed media facade (texture/shader/sound/scene/script/json)
#
# Game code calls God.<hub>.<method>; God itself holds zero domain
# logic: it builds the Hubs and connects each to Drive's module
# change, without knowing which of them keeps something of the module.
#
# Layer rule: game code → God; engine plumbing → Drive. The Hubs
# call Drive for resolution; only Loaders touch Godot's resource
# APIs.
extends Node

var things: ThingHub
var rules: RuleHub
var media: MediaHub

func _ready() -> void:
	things = ThingHub.new()
	rules = RuleHub.new()
	media = MediaHub.new()
	for hub: D5Hub in hubs():
		Drive.active_module_changed.connect(hub.on_module_changed)

# Every Hub of God, in the order they hear the module change.
func hubs() -> Array[D5Hub]:
	var all: Array[D5Hub] = [things, rules, media]
	return all
