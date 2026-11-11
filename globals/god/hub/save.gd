# SaveHub — what the player keeps between runs, in files of their own:
# the saved match, one slot; the hall of fame, across matches; and the
# settings, across installs. One of the Hubs that compose God; see god.gd.
#
# It knows nothing above God, so it never calls The. Whatever has
# something to save hears `save_requested` and hands its part in with
# `add_extras()`, and takes it back from `load_completed`, after the
# module and the language of the save are back. The is the first, with
# its session: the board and the Things. It keeps nothing of the module.
extends D5Hub
class_name SaveHub

const SAVE_VERSION := 2

signal save_requested()                     # every part hands its own in, with add_extras()
signal load_completed(extras: Dictionary)   # every part takes its own back, by its key

# Where the files live. A test points it at a folder of its own, so it
# never touches the player's.
var folder: String = "user://"

var _pending_extras: Dictionary = {}

func save_path() -> String:
	return folder.path_join("save.json")

func hall_path() -> String:
	return folder.path_join("hall_of_fame.json")

func settings_path() -> String:
	return folder.path_join("settings.json")

# --- Save / Load ---

func save_game() -> bool:
	_pending_extras.clear()
	save_requested.emit()
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"module_id": Drive.active_module(),
		"lang": I18n.lang,
		"extras": _pending_extras.duplicate(true),
	}
	var file: FileAccess = FileAccess.open(save_path(), FileAccess.WRITE)
	if file == null:
		Log.log(self, "error", "God.saves: failed to open save file for write")
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	Log.log(self, "info", "God.saves: game saved (" + save_path() + ")")
	return true

func add_extras(key: String, data: Variant) -> void:
	_pending_extras[key] = data

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file: FileAccess = FileAccess.open(save_path(), FileAccess.READ)
	if file == null:
		Log.log(self, "error", "God.saves: failed to open save file for read")
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		Log.log(self, "error", "God.saves: invalid save file format")
		return {}
	return parsed as Dictionary

# The module and the language of the save come back first, then every
# part takes its own back.
func apply_save(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var module_id: String = String(payload.get("module_id", ""))
	if module_id != "" and Drive.active_module() != module_id:
		Drive.set_module(module_id)
	var lang: String = String(payload.get("lang", I18n.lang))
	if lang != "":
		I18n.set_lang(lang)
	var extras: Variant = payload.get("extras", {})
	load_completed.emit(extras as Dictionary if extras is Dictionary else {})

func has_save() -> bool:
	return FileAccess.file_exists(save_path())

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()))
		Log.log(self, "info", "God.saves: save deleted")

# --- Hall of Fame (persists across playthroughs) ---

func load_hall_of_fame() -> Array:
	if not FileAccess.file_exists(hall_path()):
		return []
	var file: FileAccess = FileAccess.open(hall_path(), FileAccess.READ)
	if file == null:
		return []
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		return parsed as Array
	return []

func save_hall_of_fame(entries: Array) -> void:
	var file: FileAccess = FileAccess.open(hall_path(), FileAccess.WRITE)
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
	if not FileAccess.file_exists(settings_path()):
		return defaults
	var file: FileAccess = FileAccess.open(settings_path(), FileAccess.READ)
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
	var file: FileAccess = FileAccess.open(settings_path(), FileAccess.WRITE)
	if file == null:
		Log.log(self, "error", "God.saves: failed to write settings")
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()

# The settings, applied: the language, and the volume of each audio bus.
# A key that is not given takes its default. God has the saved ones
# applied when it builds its Hubs; an options screen applies them again
# after a change.
func apply_settings(data: Dictionary) -> void:
	var settings: Dictionary = default_settings()
	settings.merge(data, true)
	I18n.set_lang(String(settings["lang"]))
	_apply_bus_volume("Master", float(settings["volume_master"]))
	_apply_bus_volume("Music", float(settings["volume_music"]))
	_apply_bus_volume("SFX", float(settings["volume_sfx"]))

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
