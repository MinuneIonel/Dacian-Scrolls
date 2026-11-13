## WP-10: the Game autoload (new game, save, load) on fixture content.
extends TestCase

const FIXTURES: String = "res://tests/fixtures/data"
const DIR: String = "user://test_saves"

var _toasts: Array[String] = []

func before_all() -> void:
	Content.reload(FIXTURES)
	Game.save_dir_override = DIR
	Bus.toast.connect(_on_toast)

func after_all() -> void:
	Bus.toast.disconnect(_on_toast)
	_clean()
	Game.save_dir_override = ""
	Game.state = GameState.new()
	Game.rng = Rng.new(0)
	Content.reload("res://data")

func before_each() -> void:
	_clean()
	_toasts.clear()

func _on_toast(key: String) -> void:
	_toasts.append(key)

func _clean() -> void:
	var da := DirAccess.open(DIR)
	if da == null: return
	for f in da.get_files(): da.remove(f)

func _write_raw(slot: int, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(Game.save_path(slot), FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_new_game_values() -> void:
	Game.new_game(7, &"fx_knight")
	var s: GameState = Game.state
	assert_eq(s.party.size(), 1)
	assert_eq(s.party[0].id, &"hero")
	assert_eq(s.party[0].name_key, "hero_name")
	assert_eq(s.party[0].level, 1)
	assert_eq(s.party[0].class_id, &"fx_knight")
	assert_eq(s.food, 12); assert_eq(s.gold, 24)
	assert_eq(s.day, 1); assert_eq(s.hour, 8)
	assert_eq(s.world_pos, Vector2i(1, 1))
	assert_eq(s.discovered, [&"fx_town"])
	assert_eq(s.mode, &"location")
	assert_eq(s.location_id, &"fx_town")
	assert_eq(s.location_cell, Vector2i(3, 3))
	assert_eq(s.seed, 7)
	assert_eq(s.ufos, [{"id": &"fx_ufo", "pos": Vector2i(3, 6), "state": "patrol", "route_i": 0}])
	# radius 2 around (1, 1), clipped to the map: x and y in 0..3 -> 16 cells
	assert_eq(s.revealed.size(), 16)
	assert_has(s.revealed, "3,3")
	assert_has(s.revealed, "0,0")
	assert_not_has(s.revealed, "4,1")

func test_new_game_resets_previous_state() -> void:
	Game.new_game(1, &"fx_knight")
	Game.state.gold = 999
	Game.state.flags["x"] = true
	Game.new_game(2, &"fx_necro")
	assert_eq(Game.state.gold, 24)
	assert_eq(Game.state.flags, {})
	assert_eq(Game.state.party[0].class_id, &"fx_necro")

func test_rng_seeded() -> void:
	Game.new_game(7, &"fx_knight")
	var a: int = Game.rng.randi_range(0, 1 << 30)
	var b: int = Rng.new(7).randi_range(0, 1 << 30)
	assert_eq(a, b)

func test_save_load_is_deterministic() -> void:
	Game.new_game(7, &"fx_knight")
	var straight: Array = []
	for i in 20: straight.append(Game.rng.randi_range(0, 1000000))
	Game.new_game(7, &"fx_knight")
	var drawn: Array = []
	for i in 10: drawn.append(Game.rng.randi_range(0, 1000000))
	assert_eq(Game.save(1), OK)
	Game.rng = Rng.new(12345)   # scramble: load must restore it
	Game.state = GameState.new()
	assert_eq(Game.load_slot(1), OK)
	for i in 10: drawn.append(Game.rng.randi_range(0, 1000000))
	assert_eq(drawn, straight)

func test_save_writes_file_and_no_temp_left() -> void:
	Game.new_game(3, &"fx_knight")
	assert_false(Game.has_save(2))
	assert_eq(Game.save(2), OK)
	assert_true(Game.has_save(2))
	assert_eq(Game.save_path(2), DIR + "/save_2.json")
	var files: PackedStringArray = DirAccess.open(DIR).get_files()
	assert_eq(Array(files), ["save_2.json"])

func test_save_overwrites() -> void:
	Game.new_game(3, &"fx_knight")
	Game.save(1)
	Game.state.gold = 77
	Game.save(1)
	Game.state.gold = 1
	assert_eq(Game.load_slot(1), OK)
	assert_eq(Game.state.gold, 77)

func test_load_round_trip() -> void:
	Game.new_game(5, &"fx_knight")
	Game.state.flags["met"] = true
	Game.state.inventory[&"fx_cell"] = 2
	var before: Dictionary = Game.state.to_dict()
	Game.save(3)
	Game.new_game(9, &"fx_necro")
	assert_eq(Game.load_slot(3), OK)
	before.rng_state = Game.state.to_dict().rng_state
	assert_eq(Game.state.to_dict(), before)

func test_bad_slot() -> void:
	expect_errors(2)
	Game.new_game(5, &"fx_knight")
	assert_ne(Game.save(-1), OK)
	assert_ne(Game.save(Game.SLOTS), OK)

func _assert_load_fails(slot: int, key: String) -> void:
	Game.new_game(11, &"fx_knight")
	Game.state.gold = 500
	var before: Dictionary = Game.state.to_dict()
	var st: GameState = Game.state
	var rng_before: int = Game.rng.get_state()
	_toasts.clear()
	assert_ne(Game.load_slot(slot), OK)
	assert_true(Game.state == st, "same object")
	assert_eq(Game.state.to_dict(), before)
	assert_eq(Game.rng.get_state(), rng_before)
	assert_eq(_toasts, [key])

func test_load_missing_slot() -> void:
	_assert_load_fails(2, "save_corrupt")

func test_load_empty_file() -> void:
	_write_raw(1, "")
	_assert_load_fails(1, "save_corrupt")

func test_load_invalid_json() -> void:
	_write_raw(1, "{not json")
	_assert_load_fails(1, "save_corrupt")

func test_load_too_new() -> void:
	_write_raw(1, "{\"version\": 999}")
	_assert_load_fails(1, "save_too_new")

func test_load_without_party() -> void:
	Game.new_game(4, &"fx_knight")
	Game.save(1)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(1)))
	d.erase("party")
	_write_raw(1, JSON.stringify(d))
	_assert_load_fails(1, "save_corrupt")
