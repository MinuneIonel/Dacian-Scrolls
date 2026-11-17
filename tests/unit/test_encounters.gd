## WP-13: Encounters.options / choose / apply_battle_result.
extends TestCase

const FIXTURES: String = "res://tests/fixtures/data"

var defs: Defs
var s: GameState
var rng: Rng

func before_all() -> void:
	defs = ContentLoader.load_root(FIXTURES)

func before_each() -> void:
	s = _state()
	rng = Rng.new(1)

func _state() -> GameState:
	var st := GameState.new()
	st.party.append(Character.create(&"hero", defs.get_def(&"class", &"fx_knight"), "hero_name"))
	st.party.append(Character.create(&"fx_priest", defs.get_def(&"class", &"fx_necro"), "fx_npc_priest"))
	st.gold = 0
	st.food = 5
	return st

func _ids(opts: Array[Dictionary]) -> Array:
	return opts.map(func(o: Dictionary) -> String: return o.id)

func _win(st: GameState) -> Dictionary:
	return {"outcome": "win", "reason": "", "loot": {}, "downed": [],
		"party_hp": {}, "party_mana": {}, "party_charge": {}}

# ---- options ----------------------------------------------------------------

func test_options_hide_failed_if_but_keep_fight_and_flee() -> void:
	var opts: Array[Dictionary] = Encounters.options(&"fxw_bandits", s, defs)
	assert_eq(_ids(opts), ["fight", "talk", "sneak", "flee"])
	assert_eq(opts[0].label_key, "opt_fight")
	assert_eq(opts[0].chance, 100)
	assert_eq(opts[1].chance, 100, "no roll")
	assert_eq(opts[2].chance, Rules.roll_chance(12, 4))
	assert_eq(opts[2].chance, 65)
	assert_eq(opts[3].chance, 75)
	assert_eq(opts[2].keys().size(), 3)

func test_options_show_when_if_passes() -> void:
	s.gold = 12
	s.flags["helped"] = true
	assert_eq(_ids(Encounters.options(&"fxw_bandits", s, defs)), ["fight", "talk", "sneak", "bribe", "help", "flee"])

func test_options_never_fewer_than_two() -> void:
	var knight := GameState.new()
	knight.party.append(Character.create(&"hero", defs.get_def(&"class", &"fx_knight"), "hero_name"))
	assert_eq(_ids(Encounters.options(&"fx_wolves", knight, defs)), ["fight", "flee"])
	assert_eq(_ids(Encounters.options(&"fx_saucer", knight, defs)), ["fight", "flee"])
	var necro := GameState.new()
	necro.party.append(Character.create(&"hero", defs.get_def(&"class", &"fx_necro"), "hero_name"))
	var opts: Array[Dictionary] = Encounters.options(&"fx_wolves", necro, defs)
	assert_eq(_ids(opts), ["fight", "talk", "flee"])
	assert_eq(opts[1].chance, Rules.roll_chance(12, 4))
	assert_eq(Encounters.options(&"fx_saucer", knight, defs)[1].chance, 0, "dc 99")

func test_options_unknown_encounter() -> void:
	expect_errors(1)
	assert_eq(Encounters.options(&"nope", s, defs), [] as Array[Dictionary])

# ---- choose -----------------------------------------------------------------

func test_fight_requests_battle_without_xp() -> void:
	var ev: Array[Dictionary] = Encounters.choose(&"fxw_bandits", "fight", s, rng, defs)
	assert_eq(find_event(ev, "battle_requested").encounter, &"fxw_bandits")
	assert_eq(count_events(ev, "xp_gained"), 0)
	assert_eq(s.party[0].xp, 0)

func test_talk_without_roll_runs_pass_and_grants_xp() -> void:
	var ev: Array[Dictionary] = Encounters.choose(&"fxw_bandits", "talk", s, rng, defs)
	assert_eq(count_events(ev, "roll"), 0)
	assert_eq(find_event(ev, "narrator").line_key, "fxw_line_talk")
	assert_eq(count_events(ev, "xp_gained"), 2, "one per party member")
	assert_eq(find_event(ev, "xp_gained").amount, 36)
	assert_eq(s.party[0].xp, 36)
	assert_eq(s.party[1].xp, 36)

func test_roll_runs_pass_or_fail() -> void:
	var passes: int = 0
	var fails: int = 0
	for seed_i in 60:
		var st: GameState = _state()
		var ev: Array[Dictionary] = Encounters.choose(&"fxw_bandits", "sneak", st, Rng.new(seed_i), defs)
		var r: Dictionary = find_event(ev, "roll")
		assert_eq(r.stat, "agility")
		assert_eq(r.dc, 12)
		assert_eq(r.passed, r.total >= 12)
		assert_between(r.total, 5, 24)
		if r.passed:
			passes += 1
			assert_eq(count_events(ev, "battle_requested"), 0)
			assert_eq(st.party[0].xp, 36)
		else:
			fails += 1
			assert_eq(count_events(ev, "battle_requested"), 1)
			assert_eq(st.party[0].xp, 0)
	assert_true(passes > 0 and fails > 0)

func test_roll_is_deterministic() -> void:
	var a: Array[Dictionary] = Encounters.choose(&"fxw_bandits", "sneak", _state(), Rng.new(9), defs)
	var b: Array[Dictionary] = Encounters.choose(&"fxw_bandits", "sneak", _state(), Rng.new(9), defs)
	assert_eq(var_to_str(a), var_to_str(b))

func test_flee_never_grants_xp() -> void:
	var fled: int = 0
	for seed_i in 40:
		var st: GameState = _state()
		var ev: Array[Dictionary] = Encounters.choose(&"fxw_bandits", "flee", st, Rng.new(seed_i), defs)
		assert_eq(count_events(ev, "xp_gained"), 0)
		if find_event(ev, "roll").passed:
			fled += 1
			assert_eq(count_events(ev, "battle_requested"), 0)
	assert_true(fled > 0)

func test_bribe_hidden_without_gold_then_works() -> void:
	assert_eq(Encounters.choose(&"fxw_bandits", "bribe", s, rng, defs), [] as Array[Dictionary])
	assert_eq(s.party[0].xp, 0)
	s.gold = 20
	var ev: Array[Dictionary] = Encounters.choose(&"fxw_bandits", "bribe", s, rng, defs)
	assert_eq(find_event(ev, "gold_changed").delta, -12)
	assert_eq(s.gold, 8)
	assert_eq(s.party[0].xp, 36)

func test_unknown_option_does_nothing() -> void:
	assert_eq(Encounters.choose(&"fxw_bandits", "dance", s, rng, defs), [] as Array[Dictionary])

func test_talk_sneak_bribe_give_the_same_xp_as_fighting() -> void:
	var fought: GameState = _state()
	Encounters.choose(&"fxw_bandits", "fight", fought, rng, defs)
	Encounters.apply_battle_result(&"fxw_bandits", _win(fought), fought, rng, defs)
	var want: int = fought.party[0].xp
	assert_eq(want, 36)
	var talked: GameState = _state()
	Encounters.choose(&"fxw_bandits", "talk", talked, rng, defs)
	assert_eq(talked.party[0].xp, want)
	var bribed: GameState = _state()
	bribed.gold = 12
	Encounters.choose(&"fxw_bandits", "bribe", bribed, rng, defs)
	assert_eq(bribed.party[0].xp, want)
	for seed_i in 20:
		var sneaked: GameState = _state()
		var ev: Array[Dictionary] = Encounters.choose(&"fxw_bandits", "sneak", sneaked, Rng.new(seed_i), defs)
		if find_event(ev, "roll").passed:
			assert_eq(sneaked.party[0].xp, want)
			return
	fail("no sneak roll passed")

# ---- battle results ---------------------------------------------------------

func test_apply_win_sets_hp_loot_downed_and_xp() -> void:
	s.party[0].hp = 30
	var res: Dictionary = {"outcome": "win", "reason": "", "loot": {&"fx_bread": 2, "fx_cell": 1},
		"downed": [&"hero"], "party_hp": {&"hero": 0, &"fx_priest": 7},
		"party_mana": {&"hero": 1, &"fx_priest": 3}, "party_charge": {&"hero": 2, &"fx_priest": 0}}
	var ev: Array[Dictionary] = Encounters.apply_battle_result(&"fxw_bandits", res, s, rng, defs)
	assert_eq(s.party[0].hp, 1, "downed back at 1 HP")
	assert_eq(s.party[1].hp, 7)
	assert_eq(s.party[0].mana, 1)
	assert_eq(s.party[1].mana, 3)
	assert_eq(s.party[0].charge, 2)
	assert_eq(s.party[1].charge, 0)
	assert_eq(s.inventory[&"fx_bread"], 2)
	assert_eq(s.inventory[&"fx_cell"], 1)
	assert_eq(count_events(ev, "item_changed"), 2)
	assert_eq(count_events(ev, "xp_gained"), 2)
	assert_eq(s.party[0].xp, 36)

func test_apply_lose_gives_nothing() -> void:
	var res: Dictionary = {"outcome": "lose", "reason": "timeout", "loot": {&"fx_bread": 2},
		"downed": [&"hero", &"fx_priest"], "party_hp": {&"hero": 0, &"fx_priest": 0},
		"party_mana": {}, "party_charge": {}}
	var ev: Array[Dictionary] = Encounters.apply_battle_result(&"fxw_bandits", res, s, rng, defs)
	assert_eq(count_events(ev, "xp_gained"), 0)
	assert_true(s.inventory.is_empty())
	assert_eq(s.party[0].hp, 0)

func test_apply_fled_keeps_everyone_standing_without_xp() -> void:
	var res: Dictionary = {"outcome": "fled", "reason": "", "loot": {}, "downed": [&"fx_priest"],
		"party_hp": {&"hero": 12, &"fx_priest": 0}, "party_mana": {}, "party_charge": {}}
	var ev: Array[Dictionary] = Encounters.apply_battle_result(&"fxw_bandits", res, s, rng, defs)
	assert_eq(s.party[0].hp, 12)
	assert_eq(s.party[1].hp, 1)
	assert_eq(count_events(ev, "xp_gained"), 0)

func test_defeated_ufo_is_gone() -> void:
	s.world_pos = Vector2i(3, 5)
	s.ufos.append({"id": &"fx_ufo", "pos": Vector2i(3, 5), "state": "chase", "route_i": 1})
	var ev: Array[Dictionary] = Encounters.apply_battle_result(&"fx_saucer", _win(s), s, rng, defs)
	assert_eq(s.ufos[0].state, "gone")
	assert_eq(find_event(ev, "ufo_moved").state, "gone")
	assert_eq(s.party[0].xp, 60)
	assert_eq(Ufo.tick(s, rng, defs), [] as Array[Dictionary])
