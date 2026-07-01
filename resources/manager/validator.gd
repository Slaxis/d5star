# ValidatorManager — owns the list of pluggable Validators discovered
# from `engine/d5star/globals/drive/validator/validators/`. Auto-
# discovery uses the same AssetManager scan as ParserManager and
# ResourceManager.
#
# `validate(hub)` runs every registered Validator in order and
# aggregates their issue messages into one array. The caller
# (Drive.validate_content → ThingHub.on_module_changed) decides how
# to report — the MVP logs warnings.
extends Manager
class_name ValidatorManager

const ID := "validators"

func manager_id() -> String: return ID

var _validators: Array[Validator] = []

func register(validator: Validator) -> void:
	if validator == null:
		return
	_validators.append(validator)

func register_from_assets(asset_list: Array[Asset]) -> void:
	for asset in asset_list:
		register_from_asset(asset)

func register_from_asset(asset: Asset) -> void:
	if asset == null or asset.kind != "gd":
		return
	var script: Script = load(asset.path)
	if script == null:
		return
	var instance: Object = script.new()
	if instance is Validator:
		register(instance as Validator)

func validate(hub: ThingHub) -> Array[String]:
	var issues: Array[String] = []
	for v: Validator in _validators:
		issues.append_array(v.validate(hub))
	return issues
