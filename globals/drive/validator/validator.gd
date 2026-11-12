# Validator — base for pluggable cross-ref validators. Each concrete
# subclass walks the content graph and flags broken id references
# (typos, missing files, wrong kind, etc.).
#
# ValidatorManager auto-discovers validators from the loaders-style
# folder at boot; adding a new check = drop a new subclass here.
#
# The validators of the library know `ancestor`, `parts`, `class` and the
# script of each Thing. The fields a game's Things use to name other Things,
# a biome, a stat, a class, the game declares in data, Things of the def
# `refs`, and RefsValidator checks them (see Refs).
#
# Runs at end of every module switch — output goes to Log as warnings
# so a broken ref doesn't fail boot but is impossible to miss.
@abstract
class_name Validator
extends RefCounted

# Return an array of issue messages (one per broken ref). Empty means
# the check passed. The `hub` gives access to ThingCatalog queries;
# Drive.list_all_content() gives the full raw JSON set.
@abstract func validate(hub: ThingHub) -> Array[String]
