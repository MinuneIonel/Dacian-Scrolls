## The Audio autoload headless: music with layers, crossfades, sfx, stingers, settings volume.
## Any engine error fails a test, so these also prove unknown ids are silent.
extends TestCase

func after_each() -> void:
	Audio.stop_music(0.0)

## Headless frames are very fast; give the audio thread time to drop stopped playbacks so
## nothing is still registered with the AudioServer at exit.
func after_all() -> void:
	for c in Audio.get_children():
		if c is AudioStreamPlayer: (c as AudioStreamPlayer).stop()
	await get_tree().create_timer(0.3).timeout

func test_play_music_starts_all_stems_with_base_layer() -> void:
	Audio.play_music(&"sarmizegetusa")
	assert_eq(Audio.current_track, &"sarmizegetusa")
	assert_true(Audio.is_playing())
	var sync: AudioStreamSynchronized = Audio.music_player().stream
	assert_eq(sync.stream_count, 3)
	assert_eq(Audio.layer_level(&"explore"), 1.0)
	assert_eq(Audio.layer_level(&"combat"), 0.0)
	assert_eq(Audio.layer_level(&"lobizi"), 0.0)
	await wait_frames(3)
	assert_true(Audio.is_playing())

func test_play_music_on_current_track_does_nothing() -> void:
	Audio.play_music(&"sarmizegetusa")
	var p: AudioStreamPlayer = Audio.music_player()
	Audio.set_layer(&"combat", true, 0.0)
	Audio.play_music(&"sarmizegetusa")
	assert_eq(Audio.music_player(), p)
	assert_eq(Audio.layer_level(&"combat"), 1.0)

func test_set_layer_fades_and_ignores_unknown() -> void:
	Audio.play_music(&"sarmizegetusa")
	Audio.set_layer(&"combat", true, 0.0)
	var sync: AudioStreamSynchronized = Audio.music_player().stream
	assert_almost_eq(sync.get_sync_stream_volume(1), 0.0, 0.01)
	Audio.set_layer(&"lobizi", true, 0.1)
	await get_tree().create_timer(0.3).timeout
	assert_almost_eq(Audio.layer_level(&"lobizi"), 1.0, 0.001)
	Audio.set_layer(&"combat", false, 0.0)
	assert_almost_eq(sync.get_sync_stream_volume(1), -60.0, 0.01)
	Audio.set_layer(&"bagpipes", true)
	assert_false(Audio.has_layer(&"bagpipes"))

func test_switching_track_crossfades_and_resets_layers() -> void:
	Audio.play_music(&"sarmizegetusa")
	Audio.set_layer(&"combat", true, 0.0)
	var old: AudioStreamPlayer = Audio.music_player()
	Audio.play_music(&"saucer")
	assert_eq(Audio.current_track, &"saucer")
	assert_ne(Audio.music_player(), old)
	assert_true(is_instance_valid(old), "old track keeps playing while it fades out")
	assert_eq(Audio.layer_level(&"lobizi"), 1.0)
	assert_eq(Audio.layer_level(&"combat"), 0.0)
	Audio.set_layer(&"explore", true)   # no folk layer inside the saucer
	assert_false(Audio.has_layer(&"explore"))

func test_unknown_track_is_ignored() -> void:
	Audio.play_music(&"no_such_track")
	assert_eq(Audio.current_track, &"")
	assert_false(Audio.is_playing())

func test_sfx_and_stingers_play_and_unknown_ids_are_silent() -> void:
	for id in ["step", "hit", "miss", "crit", "gib", "heal", "summon", "ui_click", "ui_back",
			"coin", "door", "beam", "alarm"]:
		Audio.sfx(StringName(id))
	Audio.sfx(&"kazoo")
	Audio.sfx(&"")
	for id in ["abduction", "page_found", "level_up", "defeat"]:
		Audio.stinger(StringName(id))
	Audio.stinger(&"kazoo_solo")
	await wait_frames(3)
	assert_true(true)

func test_settings_drive_bus_volumes() -> void:
	var old_m: float = Settings.music_volume
	var old_s: float = Settings.sfx_volume
	Settings.music_volume = 0.5
	Settings.sfx_volume = 0.0
	Settings.changed.emit()
	var mb: int = AudioServer.get_bus_index(&"Music")
	var sb: int = AudioServer.get_bus_index(&"SFX")
	assert_almost_eq(AudioServer.get_bus_volume_db(mb), linear_to_db(0.5), 0.01)
	assert_true(AudioServer.is_bus_mute(sb))
	Settings.music_volume = old_m
	Settings.sfx_volume = old_s
	Settings.changed.emit()
	assert_false(AudioServer.is_bus_mute(sb))

func test_stop_music() -> void:
	Audio.play_music(&"saucer")
	Audio.stop_music(0.0)
	assert_eq(Audio.current_track, &"")
	assert_false(Audio.is_playing())
	Audio.set_layer(&"combat", true)   # nothing playing: no-op
	assert_false(Audio.has_layer(&"combat"))
