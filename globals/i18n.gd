# Global language resolver (no Godot localization for now).
extends Node

signal lang_changed(new_lang: String)

var lang: String = "pt"
var fallbacks: Array[String] = ["pt", "en"]

func _normalize_lang(value: String) -> String:
	return String(value).strip_edges().to_lower()

func _lang_chain(value: String) -> Array[String]:
	var normalized: String = _normalize_lang(value)
	var chain: Array[String] = []
	if normalized != "":
		chain.append(normalized)
		var split_idx: int = max(normalized.find("-"), normalized.find("_"))
		if split_idx > 0:
			var base: String = normalized.substr(0, split_idx)
			if base != "" and not chain.has(base):
				chain.append(base)
	for fallback in fallbacks:
		var fallback_key: String = _normalize_lang(String(fallback))
		if fallback_key != "" and not chain.has(fallback_key):
			chain.append(fallback_key)
	return chain

func _text_from_dict(data: Dictionary, default_value: String) -> String:
	var chain: Array[String] = _lang_chain(lang)
	for key in chain:
		if data.has(key):
			var entry: Variant = data.get(key, null)
			if entry == null:
				continue
			if entry is String:
				var text_value: String = String(entry)
				if text_value != "":
					return text_value
			else:
				return String(entry)
	if data.has("default"):
		var default_entry: Variant = data.get("default", default_value)
		if default_entry != null:
			return String(default_entry)
	if default_value != "":
		return default_value
	for entry in data.values():
		if entry == null:
			continue
		if entry is String:
			var text_value: String = String(entry)
			if text_value != "":
				return text_value
		else:
			return String(entry)
	return ""

func set_lang(new_lang: String) -> void:
	var normalized: String = _normalize_lang(new_lang)
	if normalized == "" or normalized == lang:
		return
	lang = normalized
	lang_changed.emit(lang)

func get_lang() -> String:
	return lang

func text(value: Variant, default_value: String = "") -> String:
	if value == null:
		return default_value
	if value is String:
		return String(value)
	if value is Dictionary:
		return _text_from_dict(value as Dictionary, default_value)
	return String(value)

func format(template: String, vars: Dictionary) -> String:
	var result: String = template
	for key: Variant in vars.keys():
		var placeholder: String = "{" + str(key) + "}"
		result = result.replace(placeholder, str(vars[key]))
	return result

func plural(singular: Variant, plural_form: Variant, count: int, default_text: String = "") -> String:
	var source: Variant = singular if count == 1 else plural_form
	if source == null:
		return default_text
	var resolved: String = text(source, default_text)
	return resolved if resolved != "" else default_text
