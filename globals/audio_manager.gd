# CLAUDE: this class name is so boring
# We should lorefy it better
extends Node

const CROSSFADE_SECONDS: float = 0.8
const SFX_POOL_SIZE: int = 8

var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _music_active: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _current_music_id: String = ""
var _active_tween: Tween = null

func _ready() -> void:
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_music_active = _music_a
	for i: int in SFX_POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

func _make_music_player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p

func _audio_def() -> Def:
	if Drive == null:
		return null
	return Drive.def("audio")

func play_music(id: String) -> void:
	if id == _current_music_id:
		return
	var audio: Def = _audio_def()
	if audio == null:
		return
	var entry: Dictionary = audio.call("get_music", id)
	if entry.is_empty():
		return
	var path: String = String(entry.get("path", ""))
	if not ResourceLoader.exists(path):
		_current_music_id = id
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	_apply_loop(stream, bool(entry.get("loop", false)))
	var next_player: AudioStreamPlayer = _music_b if _music_active == _music_a else _music_a
	next_player.stream = stream
	next_player.bus = String(entry.get("bus", "Music"))
	next_player.volume_db = -80.0
	next_player.play()
	_crossfade_to(next_player)
	_current_music_id = id

func _crossfade_to(next_player: AudioStreamPlayer) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	var prev: AudioStreamPlayer = _music_active
	_music_active = next_player
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(prev, "volume_db", -80.0, CROSSFADE_SECONDS)
	_active_tween.tween_property(next_player, "volume_db", 0.0, CROSSFADE_SECONDS)
	_active_tween.chain().tween_callback(func() -> void:
		prev.stop()
	)

func stop_music() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_music_a.stop()
	_music_b.stop()
	_music_a.volume_db = -80.0
	_music_b.volume_db = -80.0
	_current_music_id = ""

func play_sfx(id: String) -> void:
	var audio: Def = _audio_def()
	if audio == null:
		return
	var entry: Dictionary = audio.call("get_sfx", id)
	if entry.is_empty():
		return
	var path: String = String(entry.get("path", ""))
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = _next_free_sfx_player()
	player.stream = stream
	player.bus = String(entry.get("bus", "SFX"))
	player.volume_db = 0.0
	player.play()

func _next_free_sfx_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0]

func _apply_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = should_loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = should_loop
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
