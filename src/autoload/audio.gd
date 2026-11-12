## Music (layered stems played in sync) and sound effects. Missing files are silent.
## Files by convention: assets/audio/music/<track>_<layer>.ogg, stingers/<id>.ogg, sfx/<id>.ogg.
## All stems of a track play inside one AudioStreamSynchronized; layers fade by per-stream volume.
## Buses: Stems -> Music -> Master (stingers go to Music and duck Stems), SFX -> Master.
extends Node

const MUSIC_DIR: String = "res://assets/audio/music/"
const STINGER_DIR: String = "res://assets/audio/stingers/"
const SFX_DIR: String = "res://assets/audio/sfx/"
## Layers per track, and the layer that is on when the track starts.
const TRACKS: Dictionary = {
	&"sarmizegetusa": [&"explore", &"combat", &"lobizi"],
	&"saucer": [&"lobizi", &"combat"],
}
const BASE_LAYER: Dictionary = {&"sarmizegetusa": &"explore", &"saucer": &"lobizi"}
const OFF_DB: float = -60.0          # AudioStreamSynchronized's quietest volume
const SILENT_DB: float = -80.0
const CROSSFADE_S: float = 1.5
const SFX_POOL: int = 8
const DUCK_DB: float = -8.0

var current_track: StringName = &""
var _player: AudioStreamPlayer = null
var _sync: AudioStreamSynchronized = null
var _layer_index: Dictionary = {}    # layer -> stream index in _sync, current track only
var _layer_amp: Dictionary = {}      # layer -> linear 0..1 target
var _layer_tweens: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _stinger_player: AudioStreamPlayer
var _duck_tween: Tween
var _cache: Dictionary = {}

func _ready() -> void:
	_ensure_bus(&"Music", &"Master")
	_ensure_bus(&"Stems", &"Music")
	_ensure_bus(&"SFX", &"Master")
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_players.append(p)
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.bus = &"Music"
	_stinger_player.finished.connect(_unduck)
	add_child(_stinger_player)
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()

func _exit_tree() -> void:
	# Release streams before the engine's resource cache shuts down (no leak warnings at exit).
	for c in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()
			(c as AudioStreamPlayer).stream = null
	_sync = null
	_cache.clear()

func play_music(track: StringName) -> void:
	if track == current_track and _player != null: return
	if not TRACKS.has(track): return
	var sync := AudioStreamSynchronized.new()
	var index: Dictionary = {}
	var streams: Array[AudioStream] = []
	for layer: StringName in TRACKS[track]:
		var s: AudioStream = _load(MUSIC_DIR + "%s_%s.ogg" % [track, layer], true)
		if s == null: continue
		index[layer] = streams.size()
		streams.append(s)
	sync.stream_count = streams.size()
	_layer_amp.clear()
	for layer: StringName in TRACKS[track]:
		_layer_amp[layer] = 1.0 if layer == BASE_LAYER[track] else 0.0
	for i in streams.size():
		sync.set_sync_stream(i, streams[i])
	for layer: StringName in index:
		sync.set_sync_stream_volume(index[layer], _amp_db(_layer_amp[layer]))
	_fade_out_player(_player, CROSSFADE_S)
	for l: StringName in _layer_tweens:
		(_layer_tweens[l] as Tween).kill()
	_layer_tweens.clear()
	current_track = track
	_sync = sync
	_layer_index = index
	_player = null
	if streams.is_empty(): return
	_player = AudioStreamPlayer.new()
	_player.bus = &"Stems"
	_player.stream = sync
	_player.volume_db = SILENT_DB
	add_child(_player)
	_player.play()
	create_tween().tween_property(_player, "volume_db", 0.0, CROSSFADE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Layers: "explore", "combat", "lobizi".
func set_layer(layer: StringName, on: bool, fade_s: float = 1.0) -> void:
	if not _layer_amp.has(layer): return
	var target: float = 1.0 if on else 0.0
	if _layer_tweens.has(layer): (_layer_tweens[layer] as Tween).kill()
	_layer_tweens.erase(layer)
	var from: float = _layer_amp[layer]
	if not _layer_index.has(layer) or fade_s <= 0.0 or is_equal_approx(from, target):
		_set_layer_amp(target, layer)
		return
	var tw := create_tween()
	tw.tween_method(_set_layer_amp.bind(layer), from, target, fade_s)
	_layer_tweens[layer] = tw

func sfx(id: StringName) -> void:
	var s: AudioStream = _load(SFX_DIR + String(id) + ".ogg", false)
	if s == null: return
	var p: AudioStreamPlayer = null
	for q in _sfx_players:
		if not q.playing:
			p = q
			break
	if p == null:   # all busy: steal round-robin
		p = _sfx_players[_sfx_next]
		_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = s
	p.pitch_scale = randf_range(0.96, 1.04) if id == &"step" or id == &"hit" else 1.0
	p.play()

func stinger(id: StringName) -> void:
	var s: AudioStream = _load(STINGER_DIR + String(id) + ".ogg", false)
	if s == null: return
	_stinger_player.stream = s
	_stinger_player.play()
	_duck(DUCK_DB, 0.15)

func stop_music(fade_s: float = 1.0) -> void:
	_fade_out_player(_player, fade_s)
	for l: StringName in _layer_tweens:
		(_layer_tweens[l] as Tween).kill()
	_layer_tweens.clear()
	_player = null
	_sync = null
	_layer_index.clear()
	_layer_amp.clear()
	current_track = &""

# ---------------------------------------------------------------- queries (tests, debug UI)

func is_playing() -> bool:
	return _player != null and _player.playing

func has_layer(layer: StringName) -> bool:
	return _layer_amp.has(layer)

## Current layer volume, 0..1 (follows fades).
func layer_level(layer: StringName) -> float:
	return float(_layer_amp.get(layer, 0.0))

func music_player() -> AudioStreamPlayer:
	return _player

## The stream for an id, or null. kind: "music" (id = track_layer), "stinger", "sfx".
func stream_for(kind: StringName, id: StringName) -> AudioStream:
	match kind:
		&"music": return _load(MUSIC_DIR + String(id) + ".ogg", true)
		&"stinger": return _load(STINGER_DIR + String(id) + ".ogg", false)
		&"sfx": return _load(SFX_DIR + String(id) + ".ogg", false)
	return null

# ---------------------------------------------------------------- internals

func _set_layer_amp(amp: float, layer: StringName) -> void:
	_layer_amp[layer] = amp
	if _sync != null and _layer_index.has(layer):
		_sync.set_sync_stream_volume(_layer_index[layer], _amp_db(amp))

func _amp_db(amp: float) -> float:
	return maxf(OFF_DB, linear_to_db(maxf(amp, 0.0001)))

func _fade_out_player(p: AudioStreamPlayer, fade_s: float) -> void:
	if p == null: return
	if fade_s <= 0.0 or not p.is_inside_tree():
		_free_player(p)
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", SILENT_DB, fade_s).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(_free_player.bind(p))

func _free_player(p: AudioStreamPlayer) -> void:
	if not is_instance_valid(p): return
	p.stop()
	p.stream = null
	p.queue_free()

func _duck(db: float, t: float) -> void:
	var bus: int = AudioServer.get_bus_index(&"Stems")
	if bus < 0: return
	if _duck_tween != null: _duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(bus, v),
		AudioServer.get_bus_volume_db(bus), db, t)

func _unduck() -> void:
	_duck(0.0, 0.8)

## Imported resource when available (export-safe), raw OGG for files generated since the last
## import, null (silence) when missing. Never logs an error.
func _load(path: String, loop: bool) -> AudioStream:
	if _cache.has(path): return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	elif FileAccess.file_exists(path):
		s = AudioStreamOggVorbis.load_from_file(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	_cache[path] = s
	return s

func _ensure_bus(bus_name: StringName, send: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0: return
	AudioServer.add_bus()
	var i: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, send)

func _apply_volumes() -> void:
	_set_bus_volume(&"Music", Settings.music_volume)
	_set_bus_volume(&"SFX", Settings.sfx_volume)

func _set_bus_volume(bus_name: StringName, v: float) -> void:
	var i: int = AudioServer.get_bus_index(bus_name)
	if i < 0: return
	AudioServer.set_bus_mute(i, v <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(v, 0.0001, 1.0)))
