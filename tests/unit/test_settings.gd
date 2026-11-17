## Settings persist through save/load and survive a corrupt file.
extends TestCase

const TEST_PATH: String = "user://test_settings.json"
var _saved: Dictionary

func before_each() -> void:
	_saved = Settings.to_dict()
	Settings.path = TEST_PATH
	_remove()

func after_each() -> void:
	_remove()
	Settings.path = Settings.PATH
	Settings.gore = _saved.gore; Settings.music_volume = _saved.music_volume
	Settings.sfx_volume = _saved.sfx_volume; Settings.fullscreen = _saved.fullscreen

func _remove() -> void:
	if FileAccess.file_exists(TEST_PATH): DirAccess.remove_absolute(TEST_PATH)

func _write(text: String) -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_values_persist_across_save_and_load() -> void:
	Settings.gore = Settings.Gore.BLOODY_MESS
	Settings.music_volume = 0.25
	Settings.sfx_volume = 0.6
	Settings.save()
	Settings.reset_defaults()
	assert_eq(Settings.gore, Settings.Gore.NORMAL)
	Settings.load_settings()
	assert_eq(Settings.gore, 2)
	assert_almost_eq(Settings.music_volume, 0.25)
	assert_almost_eq(Settings.sfx_volume, 0.6)
	assert_false(Settings.fullscreen)

func test_corrupt_file_falls_back_to_defaults() -> void:
	_write("{ this is not json")
	Settings.gore = 0
	Settings.load_settings()
	assert_eq(Settings.gore, Settings.Gore.NORMAL)
	assert_almost_eq(Settings.music_volume, 0.8)
	assert_almost_eq(Settings.sfx_volume, 0.8)
	assert_false(Settings.fullscreen)

func test_wrong_types_and_ranges_are_clamped_or_ignored() -> void:
	_write(JSON.stringify({"gore": 9, "music_volume": "loud", "sfx_volume": -3, "fullscreen": "yes"}))
	Settings.load_settings()
	assert_eq(Settings.gore, 2)
	assert_almost_eq(Settings.music_volume, 0.8)
	assert_almost_eq(Settings.sfx_volume, 0.0)
	assert_false(Settings.fullscreen)

func test_missing_file_gives_defaults() -> void:
	Settings.gore = 0
	Settings.load_settings()
	assert_eq(Settings.gore, 1)

func test_gore_key_names_each_level() -> void:
	for g in 3:
		Settings.gore = g
		assert_ne(tr(Settings.gore_key()), Settings.gore_key(), "missing string for gore %d" % g)
