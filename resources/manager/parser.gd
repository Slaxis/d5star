# Parser manager: registers parser scripts and caches parsed resources.
extends Manager
class_name ParserManager

const ID := "parsers"

func manager_id() -> String: return ID

var parsers: Dictionary = {}
var parsed: Dictionary = {}

func _parser_resource_id(asset_id: String) -> String:
	var normalized_id: String = String(asset_id).strip_edges().to_lower()
	if normalized_id == "":
		return ""
	if normalized_id.ends_with("_parser"):
		return normalized_id.substr(0, normalized_id.length() - "_parser".length())
	return normalized_id

func _instantiate_parser(asset: Asset) -> Parser:
	if asset.kind != "gd":
		return null
	var script: Script = load(asset.path)
	if script == null:
		return null
	var instance: Object = script.new()
	if instance is Parser:
		return instance as Parser
	return null

func register(id: String, parser_instance: Parser) -> void:
	var key: String = _key(id)
	if key == "" or parser_instance == null:
		return
	parsers[key] = parser_instance

func register_from_asset(asset: Asset) -> void:
	if asset == null:
		return
	var resource_id: String = _parser_resource_id(asset.id)
	if resource_id == "":
		return
	var parser_instance: Parser = _instantiate_parser(asset)
	if parser_instance == null:
		return
	register(resource_id, parser_instance)

func register_from_assets(asset_list: Array[Asset]) -> void:
	for asset in asset_list:
		register_from_asset(asset)

func parser(id: String) -> Parser:
	var key: String = _key(id)
	if key == "":
		return null
	return parsers.get(key, null)

func get_parser(id: String) -> Parser:
	return parser(id)

func get_parsed(id: String) -> Resource:
	var key: String = _key(id)
	if key == "":
		return null
	return parsed.get(key, null)

func set_parsed(id: String, value: Resource) -> void:
	var key: String = _key(id)
	if key == "":
		return
	if value == null:
		parsed.erase(key)
		return
	parsed[key] = value

func parse(resource_id: String, parser_instance: Parser, path: String) -> Resource:
	if parser_instance == null or path == "":
		return null
	var parsed_resource: Resource = parser_instance.parse(path)
	if parsed_resource != null:
		set_parsed(resource_id, parsed_resource)
	return parsed_resource

func get_or_parse(resource_id: String, parser_instance: Parser, path: String) -> Resource:
	var cached: Resource = get_parsed(resource_id)
	if cached == null:
		cached = parse(resource_id, parser_instance, path)
	return cached
