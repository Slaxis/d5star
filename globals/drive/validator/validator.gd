# Validator — base for pluggable cross-ref validators. Each concrete
# subclass walks the content graph and flags broken id references
# (typos, missing files, wrong kind, etc.).
#
# ValidatorManager auto-discovers validators from the loaders-style
# folder at boot; adding a new check = drop a new subclass here.
#
# Validators are engine-level for the MVP: they know about `ancestor`,
# `parts`, and `class` fields. Game-specific validation (class_affinity,
# biome refs, etc.) is a future extension via module-supplied
# validators.
#
# Runs at end of every module switch — output goes to Log as warnings
# so a broken ref doesn't fail boot but is impossible to miss.
class_name Validator
extends RefCounted

# Return an array of issue messages (one per broken ref). Empty means
# the check passed. The `hub` gives access to ThingCatalog queries;
# Drive.list_all_content() gives the full raw JSON set.
func validate(_hub: ThingHub) -> Array[String]:
	return []
