# RuleHub — exposes the active module's Codex resource. Today it's
# a single delegate; the Hub exists to be the home for rule queries
# as they appear (typed reads, flow/bindings shortcuts, derived
# values). Keeping it isolated now means future rule logic doesn't
# bloat God or get scattered.
extends RefCounted
class_name RuleHub

# Active rules for the loaded module. Returns an empty Codex when
# no module is active so callers can read defaults without nil
# checks.
func current() -> Codex:
	var rules_resource: Codex = Drive.rules()
	if rules_resource == null:
		return Codex.new()
	return rules_resource
