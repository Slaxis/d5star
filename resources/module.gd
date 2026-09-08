# ModuleInfo: manifest for a module read from module.json.
extends Resource
class_name ModuleInfo

var id: String = ""
var name: String = ""
var description: String = ""
var order: int = 0
var requires: Array[String] = []
var native_path: String = ""
var user_path: String = ""

# module.json carries `name` and `description` either as a plain string or
# as an `{"pt": ..., "en": ...}` dict; both resolve through I18n here so the
# consumer never has to care which form the manifest used.
static func _resolve_text(value: Variant, fallback: String) -> String:
	if value is String:
		return value
	if value is Dictionary:
		return I18n.text(value, fallback)
	return fallback

static func from_dict(data: Dictionary, base_path: String) -> ModuleInfo:
	var info := ModuleInfo.new()
	info.id          = String(data.get("id", "")).strip_edges().to_lower()
	info.name        = _resolve_text(data.get("name", null), info.id)
	info.description = _resolve_text(data.get("description", null), "")
	info.order       = int(data.get("order", 0))
	info.native_path = base_path
	var req: Variant = data.get("requires", [])
	if req is Array:
		for entry: Variant in (req as Array):
			var s: String = String(entry).strip_edges().to_lower()
			if s != "":
				info.requires.append(s)
	return info
