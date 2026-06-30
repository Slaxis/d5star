# God — game-facing service locator. Autoload entry composed of
# three Hubs:
#
#   God.things  — ThingHub: Thing system (catalog, lifecycle, content)
#   God.rules   — RuleHub:  active Rules resource + future rule queries
#   God.media   — MediaHub: typed media facade (texture/shader/sound/scene/script/json)
#
# Game code calls God.<hub>.<method>; God itself holds zero domain
# logic, just constructs the three Hubs and forwards Drive's
# module-changed signal to ThingHub.
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
	Drive.active_module_changed.connect(_on_module_changed)

# R4 — forward module switch to Thing system (the only Hub with
# module-scoped state). Drive itself flushes ResourceManager cache.
func _on_module_changed(_module_id: String) -> void:
	things.on_module_changed()
