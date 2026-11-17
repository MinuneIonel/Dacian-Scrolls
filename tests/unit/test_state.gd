## WP-10: Character and GameState.
extends TestCase

const FIXTURES: String = "res://tests/fixtures/data"
const TestStates = preload("res://tests/unit/fxs_state_helpers.gd")

var defs: Defs

func before_all() -> void:
	defs = ContentLoader.load_root(FIXTURES)

func _knight() -> Dictionary:
	return defs.get_def(&"class", &"fx_knight")

func test_create_from_class() -> void:
	var c: Character = Character.create(&"hero", _knight(), "hero_name")
	assert_eq(c.id, &"hero")
	assert_eq(c.name_key, "hero_name")
	assert_eq(c.class_id, &"fx_knight")
	assert_eq(c.level, 1)
	assert_eq(c.xp, 0)
	assert_eq(c.max_hp, 30); assert_eq(c.hp, 30)
	assert_eq(c.max_mana, 4); assert_eq(c.mana, 4)
	assert_eq(c.max_charge, 4); assert_eq(c.charge, 4)
	assert_eq(c.stats, {"might": 6, "agility": 4, "wits": 2, "spirit": 3})
	assert_eq(c.known, [&"fx_strike", &"fx_ward", &"fx_zap"])
	assert_eq(c.equipped, [&"fx_strike", &"fx_ward", &"fx_zap"])
	assert_true(c.stats.might is int, "stats are ints")

func test_create_equips_at_most_four() -> void:
	var cd: Dictionary = _knight().duplicate(true)
	cd.abilities = ["a", "b", "c", "d", "e"]
	var c: Character = Character.create(&"x", cd, "k")
	assert_eq(c.known.size(), 5)
	assert_eq(c.equipped, [&"a", &"b", &"c", &"d"])

func test_create_does_not_share_stats_with_class() -> void:
	var cd: Dictionary = _knight()
	var c: Character = Character.create(&"hero", cd, "hero_name")
	c.stats.might = 99
	assert_eq(int(cd.base_stats.might), 6)

func test_120_xp_at_level_1_levels_up() -> void:
	var c: Character = Character.create(&"hero", _knight(), "hero_name")
	var ev: Array[Dictionary] = c.gain_xp(120, _knight())
	assert_eq(c.level, 2)
	assert_eq(c.xp, 0)
	assert_eq(c.max_hp, 36); assert_eq(c.hp, 36)
	assert_eq(c.stats.might, 7, "highest base stat +1")
	assert_eq(find_event(ev, "xp_gained"), {"type": "xp_gained", "unit": &"hero", "amount": 120})
	assert_eq(find_event(ev, "level_up"), {"type": "level_up", "unit": &"hero", "level": 2})

func test_119_xp_does_not_level() -> void:
	var c: Character = Character.create(&"hero", _knight(), "hero_name")
	var ev: Array[Dictionary] = c.gain_xp(119, _knight())
	assert_eq(c.level, 1)
	assert_eq(c.xp, 119)
	assert_eq(count_events(ev, "level_up"), 0)
	assert_eq(count_events(ev, "xp_gained"), 1)

func test_multi_level_and_carry_over() -> void:
	# level 1 -> 2 needs 120, level 2 -> 3 needs 240: 370 gives level 3 with 10 left.
	var c: Character = Character.create(&"hero", _knight(), "hero_name")
	var ev: Array[Dictionary] = c.gain_xp(370, _knight())
	assert_eq(c.level, 3)
	assert_eq(c.xp, 10)
	assert_eq(count_events(ev, "level_up"), 2)
	assert_eq(ev[-1].level, 3)

func test_level_up_keeps_damage_taken() -> void:
	var c: Character = Character.create(&"hero", _knight(), "hero_name")
	c.hp = 10
	c.gain_xp(120, _knight())
	assert_eq(c.hp, 16)

func test_highest_stat_tie_break_order() -> void:
	var cd: Dictionary = _knight().duplicate(true)
	cd.base_stats = {"might": 3, "agility": 5, "wits": 5, "spirit": 5}
	var c: Character = Character.create(&"x", cd, "k")
	c.gain_xp(120, cd)
	assert_eq(c.stats, {"might": 3, "agility": 6, "wits": 5, "spirit": 5})

func test_zero_xp_no_events() -> void:
	var c: Character = Character.create(&"hero", _knight(), "hero_name")
	assert_eq(c.gain_xp(0, _knight()), [])

func test_character_round_trip() -> void:
	var c: Character = Character.create(&"hero", _knight(), "hero_name")
	c.gain_xp(130, _knight())
	c.hp = 3
	c.gear = {"weapon": &"fx_sword", "armor": &"", "trinket": &""}
	var back: Character = Character.from_dict(c.to_dict())
	assert_eq(back.to_dict(), c.to_dict())
	assert_eq(back.id, &"hero")
	assert_true(back.id is StringName)
	assert_eq(back.gear.weapon, &"fx_sword")
	assert_eq(back.known, c.known)

func test_is_night() -> void:
	var s := GameState.new()
	s.hour = 20; assert_true(s.is_night())
	s.hour = 5; assert_true(s.is_night())
	s.hour = 6; assert_false(s.is_night())
	s.hour = 19; assert_false(s.is_night())

func test_game_state_round_trip() -> void:
	var s := TestStates.full(defs)
	var back: GameState = GameState.from_dict(s.to_dict())
	assert_eq(back.to_dict(), s.to_dict())
	assert_eq(back.party.size(), 3)
	assert_eq(back.world_pos, Vector2i(4, 5))
	assert_eq(back.ufos[1].pos, Vector2i(8, 4))
	assert_true(back.inventory.keys()[0] is StringName)
	assert_eq(back.mode, &"location")
	assert_true(back.mode is StringName)

func test_to_dict_is_json_safe() -> void:
	var d: Dictionary = TestStates.full(defs).to_dict()
	var again: Variant = JSON.parse_string(JSON.stringify(d))
	assert_eq(GameState.from_dict(again).to_dict(), d)
