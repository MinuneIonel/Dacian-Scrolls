## WP-10: SaveCodec. Review Focus 1: garbage in never crashes.
extends TestCase

const FIXTURES: String = "res://tests/fixtures/data"
const TestStates = preload("res://tests/unit/fxs_state_helpers.gd")

var defs: Defs

func before_all() -> void:
	defs = ContentLoader.load_root(FIXTURES)

func _valid_dict() -> Dictionary:
	return JSON.parse_string(SaveCodec.encode(TestStates.full(defs)))

func _assert_rejected(text: String, key: String = "save_corrupt") -> void:
	var r: Dictionary = SaveCodec.decode(text)
	assert_eq(r.ok, false, text.substr(0, 80))
	assert_eq(r.error_key, key, text.substr(0, 80))
	assert_null(r.state)

func test_round_trip() -> void:
	var s: GameState = TestStates.full(defs)
	var r: Dictionary = SaveCodec.decode(SaveCodec.encode(s))
	assert_true(r.ok)
	assert_eq(r.error_key, "")
	assert_eq(r.state.to_dict(), s.to_dict())
	assert_eq(r.state.party.size(), 3)
	assert_eq(r.state.inventory.size(), 5)
	assert_eq(r.state.flags.size(), 4)
	assert_eq(r.state.ufos.size(), 2)

func test_big_rng_state_is_exact() -> void:
	var s: GameState = TestStates.full(defs)
	s.rng_state = -8070450532247928832
	s.seed = 9223372036854775807
	var back: GameState = SaveCodec.decode(SaveCodec.encode(s)).state
	assert_true(back.rng_state == -8070450532247928832)
	assert_true(back.seed == 9223372036854775807)

func test_empty_string() -> void:
	_assert_rejected("")

func test_invalid_json() -> void:
	_assert_rejected("{not json")

func test_not_an_object() -> void:
	_assert_rejected("[1, 2, 3]")
	_assert_rejected("42")
	_assert_rejected("null")
	_assert_rejected("\"hello\"")

func test_too_new() -> void:
	_assert_rejected("{\"version\": 999}", "save_too_new")
	var d: Dictionary = _valid_dict()
	d.version = GameState.VERSION + 1
	_assert_rejected(JSON.stringify(d), "save_too_new")

func test_bad_version() -> void:
	var d: Dictionary = _valid_dict()
	d.version = "one"
	_assert_rejected(JSON.stringify(d))
	d.version = 0
	_assert_rejected(JSON.stringify(d))
	d.erase("version")
	_assert_rejected(JSON.stringify(d))

func test_missing_party() -> void:
	var d: Dictionary = _valid_dict()
	d.erase("party")
	_assert_rejected(JSON.stringify(d))

func test_empty_party() -> void:
	var d: Dictionary = _valid_dict()
	d.party = []
	_assert_rejected(JSON.stringify(d))

func test_wrong_types() -> void:
	var cases: Array = [
		["party", "lots"], ["party", [1, 2]], ["food", "many"], ["gold", null], ["day", [1]],
		["inventory", [1]], ["inventory", {"fx_sword": "one"}], ["flags", "x"], ["quests", {"q": "x"}],
		["pages", "fx_page_1"], ["pages", [1]], ["world_pos", [1]], ["world_pos", "1,2"],
		["revealed", []], ["discovered", {}], ["ufos", [1]], ["ufos", [{"id": "u"}]],
		["mode", 3], ["location_cell", null], ["rng_state", "abc"], ["rng_state", [1]],
	]
	for c in cases:
		var d: Dictionary = _valid_dict()
		d[c[0]] = c[1]
		_assert_rejected(JSON.stringify(d))

func test_every_key_required() -> void:
	for k in _valid_dict().keys():
		var d: Dictionary = _valid_dict()
		d.erase(k)
		var r: Dictionary = SaveCodec.decode(JSON.stringify(d))
		assert_false(r.ok, "missing " + k)

func test_bad_character() -> void:
	var fields: Array = [["id", 5], ["level", "x"], ["hp", null], ["stats", []],
		["stats", {"might": "x"}], ["known", "a"], ["equipped", [1]], ["gear", 1], ["class_id", null]]
	for f in fields:
		var d: Dictionary = _valid_dict()
		d.party[1][f[0]] = f[1]
		_assert_rejected(JSON.stringify(d))
	var d2: Dictionary = _valid_dict()
	d2.party[0].erase("max_hp")
	_assert_rejected(JSON.stringify(d2))

func test_too_many_in_party() -> void:
	var d: Dictionary = _valid_dict()
	d.party = [d.party[0], d.party[1], d.party[2], d.party[0], d.party[1]]
	_assert_rejected(JSON.stringify(d))

func test_binary_garbage() -> void:
	_assert_rejected("\u0001\u00ff{{{")
	_assert_rejected("{\"version\": 1, \"party\": [{]")
