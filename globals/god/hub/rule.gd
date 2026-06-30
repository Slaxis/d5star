# RuleHub — exposes the active module's Rules resource. Today it's
# a single delegate; the Hub exists to be the home for rule queries
# as they appear (typed reads, flow/bindings shortcuts, derived
# values). Keeping it isolated now means future rule logic doesn't
# bloat God or get scattered.
extends RefCounted
class_name RuleHub

# Active rules for the loaded module. Returns an empty Rules when
# no module is active so callers can read defaults without nil
# checks.
func current() -> Rules:
	var rules_resource: Rules = Drive.rules()
	if rules_resource == null:
		return Rules.new()
	return rules_resource
