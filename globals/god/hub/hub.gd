# D5Hub: base class for the Hubs of God, as D5Manager is for the managers
# of Drive. A Hub is one face of God for game code, over Drive.
#
# God tells every Hub when the module changed, after Drive's managers heard
# it, so a Hub that reads the module in its hook already reads the new one. A
# Hub that keeps something of the module overrides `on_module_changed`; the
# others keep nothing. A Hub hears only the module's id: God never sees paths.
@abstract
extends RefCounted
class_name D5Hub

# The active module changed: its id.
func on_module_changed(_module_id: String) -> void:
	pass
