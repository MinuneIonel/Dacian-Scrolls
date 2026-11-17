## The audio files WP-15 promises exist, load, and stems of a track line up to the sample.
extends TestCase

const TRACKS: Dictionary = {
	"sarmizegetusa": ["explore", "combat", "lobizi"],
	"saucer": ["lobizi", "combat"],
}
const STINGERS: Array[String] = ["abduction", "page_found", "level_up", "defeat"]
const SFX: Array[String] = ["step", "hit", "miss", "crit", "gib", "heal", "summon", "ui_click",
	"ui_back", "coin", "door", "beam", "alarm"]

func test_every_id_exists_on_disk() -> void:
	for t: String in TRACKS:
		for l: String in TRACKS[t]:
			var p: String = "res://assets/audio/music/%s_%s.ogg" % [t, l]
			assert_true(FileAccess.file_exists(p), p)
	for id in STINGERS:
		assert_true(FileAccess.file_exists("res://assets/audio/stingers/%s.ogg" % id), id)
	for id in SFX:
		assert_true(FileAccess.file_exists("res://assets/audio/sfx/%s.ogg" % id), id)

func test_every_file_loads() -> void:
	for id in STINGERS:
		assert_not_null(Audio.stream_for(&"stinger", StringName(id)), id)
	for id in SFX:
		var s: AudioStream = Audio.stream_for(&"sfx", StringName(id))
		assert_not_null(s, id)
		if s != null: assert_between(s.get_length(), 0.02, 4.0, id)

func test_stems_of_a_track_have_equal_length() -> void:
	var want: Dictionary = {"sarmizegetusa": 80.0, "saucer": 40.0}   # 32 and 16 bars at 96 BPM
	for t: String in TRACKS:
		for l: String in TRACKS[t]:
			var s: AudioStream = Audio.stream_for(&"music", StringName("%s_%s" % [t, l]))
			assert_not_null(s, "%s_%s" % [t, l])
			if s == null: continue
			assert_almost_eq(s.get_length(), want[t], 0.001, "%s_%s" % [t, l])

func test_music_stems_loop() -> void:
	var s: AudioStream = Audio.stream_for(&"music", &"sarmizegetusa_explore")
	assert_true(s is AudioStreamOggVorbis and (s as AudioStreamOggVorbis).loop)
