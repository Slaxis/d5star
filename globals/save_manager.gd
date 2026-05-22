# Save/Load manager. Single slot at user://save.json.
# Wraps The's Memento snapshot/restore with metadata; modules may attach
# extra data through the save_requested signal and add_extras().
extends Node

const SAVE_PATH := "user://save.json"
const HALL_PATH := "user://hall_of_fame.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 1

signal save_requested()   # emit point for modules to inject extras
signal load_completed()   # emitted after state is restored

var _pending_extras: Dictionary = {}

func _ready() -> void:
	var settings: Dictionary = load_settings()
	apply_audio_settings(settings)
	var lang_pref: String = String(settings.get("lang", "pt"))
	if lang_pref != "" and lang_pref != I18n.lang:
		I18n.set_lang(lang_pref)

# --- Save / Load ---

func save_game() -> bool:
	_pending_extras.clear()
	save_requested.emit()
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"module_id": Drive.active_module(),
		"lang": I18n.lang,
		"state": The.snapshot(),
		"extras": _pending_extras.duplicate(true),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		Log.log(self, "error", "SaveManager: failed to open save file for write")
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	Log.log(self, "info", "SaveManager: game saved (" + SAVE_PATH + ")")
	return true

func add_extras(key: String, data: Variant) -> void:
	_pending_extras[key] = data

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		Log.log(self, "error", "SaveManager: failed to open save file for read")
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		Log.log(self, "error", "SaveManager: invalid save file format")
		return {}
	return parsed as Dictionary

func apply_save(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var module_id: String = String(payload.get("module_id", ""))
	if module_id != "" and Drive.active_module() != module_id:
		Drive.set_module(module_id)
	var lang: String = String(payload.get("lang", I18n.lang))
	if lang != "":
		I18n.set_lang(lang)
	var state: Variant = payload.get("state", {})
	if state is Dictionary:
		The.restore(state as Dictionary)
	load_completed.emit()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		Log.log(self, "info", "SaveManager: save deleted")

# --- Hall of Fame (persists across playthroughs) ---

func load_hall_of_fame() -> Array:
	if not FileAccess.file_exists(HALL_PATH):
		return []
	var file: FileAccess = FileAccess.open(HALL_PATH, FileAccess.READ)
	if file == null:
		return []
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		return parsed as Array
	return []

func save_hall_of_fame(entries: Array) -> void:
	var file: FileAccess = FileAccess.open(HALL_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(entries, "  "))
	file.close()

func add_hall_entry(entry: Dictionary) -> void:
	var entries: Array = load_hall_of_fame()
	entries.append(entry)
	save_hall_of_fame(entries)

# --- Settings (persist across playthroughs and installs) ---

func default_settings() -> Dictionary:
	return {
		"volume_master": 1.0,
		"volume_music": 0.8,
		"volume_sfx": 1.0,
		"lang": "pt",
	}

func load_settings() -> Dictionary:
	var defaults: Dictionary = default_settings()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return defaults
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return defaults
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return defaults
	var data: Dictionary = parsed as Dictionary
	for key: String in defaults.keys():
		if not data.has(key):
			data[key] = defaults[key]
	return data

func save_settings(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		Log.log(self, "error", "SaveManager: failed to write settings")
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()

func apply_audio_settings(data: Dictionary) -> void:
	_apply_bus_volume("Master", float(data.get("volume_master", 1.0)))
	_apply_bus_volume("Music", float(data.get("volume_music", 0.8)))
	_apply_bus_volume("SFX", float(data.get("volume_sfx", 1.0)))

func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	if clamped <= 0.0001:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))
