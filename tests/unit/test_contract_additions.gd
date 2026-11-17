## Contract additions made after Wave 1: won_<encounter> flag and restore_charge.
extends TestCase

var defs: Defs

func before_all() -> void:
	defs = ContentLoader.load_root("res://tests/fixtures/data")

func _state() -> GameState:
	var s := GameState.new()
	s.party = [Character.create(&"hero", defs.get_def(&"class", &"fx_knight"), "hero_name")]
	return s

func test_win_sets_won_flag() -> void:
	var s := _state()
	var ev := Encounters.apply_battle_result(&"fx_wolves", {"outcome": "win", "loot": {}}, s, Rng.new(1), defs)
	assert_eq(s.flags.get("won_fx_wolves"), true)
	assert_eq(find_event(ev, "flag_set").get("flag"), "won_fx_wolves")

func test_loss_does_not_set_won_flag() -> void:
	var s := _state()
	Encounters.apply_battle_result(&"fx_wolves", {"outcome": "lose"}, s, Rng.new(1), defs)
	assert_false(s.flags.has("won_fx_wolves"))

func test_restore_charge_caps() -> void:
	var s := _state()
	s.party[0].charge = 1
	var ev := Rules.run([["restore_charge", 100]], s, Rng.new(1), defs)
	assert_eq(s.party[0].charge, s.party[0].max_charge)
	assert_eq(find_event(ev, "charge_restored").get("amount"), 100)
