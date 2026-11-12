## WP-11: every Rules condition and effect, state change plus emitted event.
extends TestCase

const FIXTURES: String = "res://tests/fixtures/data"

var defs: Defs
var s: GameState
var rng: Rng

func before_all() -> void:
	defs = ContentLoader.load_root(FIXTURES)

func before_each() -> void:
	s = GameState.new()
	s.party.append(Character.create(&"hero", defs.get_def(&"class", &"fx_knight"), "hero_name"))
	s.food = 5
	s.gold = 30
	rng = Rng.new(1)

func _run(effects: Array) -> Array[Dictionary]:
	return Rules.run(effects, s, rng, defs)

func _check(conds: Array) -> bool:
	return Rules.check(conds, s, defs)

func _add_necro(id: String) -> Character:
	var c: Character = Character.create(StringName(id), defs.get_def(&"class", &"fx_necro"), "fx_npc_priest")
	s.party.append(c)
	return c

# ---- the tables -------------------------------------------------------------

func test_tables_match_contract() -> void:
	assert_eq(Rules.CONDITIONS.keys().size(), 11)
	assert_eq(Rules.EFFECTS.keys().size(), 16)

# ---- conditions -------------------------------------------------------------

func test_empty_conditions_true() -> void:
	assert_true(_check([]))

func test_all_must_hold() -> void:
	s.flags["a"] = true
	assert_true(_check([["flag", "a", "==", true], ["gold", ">=", 30]]))
	assert_false(_check([["flag", "a", "==", true], ["gold", ">", 30]]))

func test_cond_flag() -> void:
	assert_true(_check([["flag", "met", "==", false]]), "missing flag is false")
	assert_false(_check([["flag", "met", "==", true]]))
	s.flags["met"] = true
	assert_true(_check([["flag", "met", "==", true]]))
	assert_true(_check([["flag", "met", "!=", false]]))
	s.flags["count"] = 3
	assert_true(_check([["flag", "count", ">=", 3]]))
	assert_true(_check([["flag", "count", "<", 4.0]]))
	assert_false(_check([["flag", "count", ">", 3]]))
	s.flags["who"] = "olt"
	assert_true(_check([["flag", "who", "==", "olt"]]))
	assert_false(_check([["flag", "who", "==", 3]]), "mismatched types are not equal")

func test_cond_quest() -> void:
	assert_true(_check([["quest", "fx_quest", "==", 0]]), "not started is 0")
	s.quests[&"fx_quest"] = 10
	assert_true(_check([["quest", "fx_quest", ">=", 10]]))
	assert_true(_check([["quest", "fx_quest", "<", 100]]))
	assert_false(_check([["quest", "fx_quest", "==", 100]]))

func test_cond_has_item() -> void:
	assert_false(_check([["has_item", "fx_cell", 1]]))
	s.inventory[&"fx_cell"] = 2
	assert_true(_check([["has_item", "fx_cell", 2]]))
	assert_false(_check([["has_item", "fx_cell", 3]]))

func test_cond_gold() -> void:
	assert_true(_check([["gold", "==", 30]]))
	assert_true(_check([["gold", "<=", 30]]))
	assert_false(_check([["gold", "<", 30]]))
	assert_true(_check([["gold", "!=", 12]]))

func test_cond_class() -> void:
	assert_true(_check([["class", "fx_knight"]]))
	assert_false(_check([["class", "fx_necro"]]))
	_add_necro("fx_priest")
	assert_false(_check([["class", "fx_necro"]]), "only the hero's class counts")

func test_cond_in_party() -> void:
	assert_false(_check([["in_party", "fx_priest"]]))
	_add_necro("fx_priest")
	assert_true(_check([["in_party", "fx_priest"]]))
	assert_true(_check([["in_party", "hero"]]))

func test_cond_has_page() -> void:
	assert_false(_check([["has_page", "fx_page_1"]]))
	s.pages.append(&"fx_page_1")
	assert_true(_check([["has_page", "fx_page_1"]]))

func test_cond_stat_best_in_party() -> void:
	assert_true(_check([["stat", "wits", "==", 2]]))
	_add_necro("fx_priest")
	assert_true(_check([["stat", "wits", "==", 6]]))
	assert_true(_check([["stat", "might", ">=", 6]]))
	assert_false(_check([["stat", "spirit", ">", 4]]))

func test_cond_night() -> void:
	s.hour = 12
	assert_false(_check([["night"]]))
	s.hour = 22
	assert_true(_check([["night"]]))

func test_cond_not() -> void:
	assert_true(_check([["not", ["flag", "met", "==", true]]]))
	s.flags["met"] = true
	assert_false(_check([["not", ["flag", "met", "==", true]]]))

func test_cond_any() -> void:
	assert_false(_check([["any", []]]), "any of nothing is false")
	assert_false(_check([["any", [["gold", ">", 100], ["night"]]]]))
	assert_true(_check([["any", [["gold", ">", 100], ["gold", "==", 30]]]]))

func test_unknown_condition_false_one_error() -> void:
	expect_errors(1)
	assert_false(_check([["moon_phase", "full"]]))

func test_malformed_condition_false_one_error() -> void:
	expect_errors(3)
	assert_false(_check([["gold", ">"]]), "too few args")
	assert_false(_check(["gold"]), "not an array")
	assert_false(_check([["gold", "~", 3]]), "bad op")

func test_unknown_inside_not_is_one_error() -> void:
	expect_errors(1)
	assert_true(_check([["not", ["moon_phase", "full"]]]))

# ---- effects ----------------------------------------------------------------

func test_eff_set_flag() -> void:
	var ev: Array[Dictionary] = _run([["set_flag", "met", true]])
	assert_eq(s.flags["met"], true)
	assert_eq(ev, [{"type": "flag_set", "flag": "met", "value": true}])

func test_eff_give_item() -> void:
	var ev: Array[Dictionary] = _run([["give_item", "power_cell", 2]])
	assert_eq(s.inventory.power_cell, 2)
	assert_eq(ev, [{"type": "item_changed", "item": "power_cell", "delta": 2}])
	_run([["give_item", "power_cell", 1]])
	assert_eq(s.inventory.power_cell, 3)

func test_eff_take_item() -> void:
	s.inventory[&"fx_cell"] = 3
	var ev: Array[Dictionary] = _run([["take_item", "fx_cell", 2]])
	assert_eq(s.inventory[&"fx_cell"], 1)
	assert_eq(ev, [{"type": "item_changed", "item": "fx_cell", "delta": -2}])
	ev = _run([["take_item", "fx_cell", 5]])
	assert_not_has(s.inventory, &"fx_cell", "key removed at 0")
	assert_eq(ev, [{"type": "item_changed", "item": "fx_cell", "delta": -1}], "never below 0")

func test_eff_gold() -> void:
	var ev: Array[Dictionary] = _run([["gold", 12]])
	assert_eq(s.gold, 42)
	assert_eq(ev, [{"type": "gold_changed", "delta": 12}])
	ev = _run([["gold", -100]])
	assert_eq(s.gold, 0)
	assert_eq(ev, [{"type": "gold_changed", "delta": -42}])

func test_eff_food() -> void:
	var ev: Array[Dictionary] = _run([["food", 3]])
	assert_eq(s.food, 8)
	assert_eq(ev, [{"type": "food_changed", "food": 8, "delta": 3}])
	ev = _run([["food", -20]])
	assert_eq(s.food, 0)
	assert_eq(ev, [{"type": "food_changed", "food": 0, "delta": -8}])

func test_eff_quest_forward_only() -> void:
	var ev: Array[Dictionary] = _run([["quest", "fx_quest", 10]])
	assert_eq(s.quests[&"fx_quest"], 10)
	assert_eq(ev, [{"type": "quest_changed", "quest": "fx_quest", "stage": 10}])
	ev = _run([["quest", "fx_quest", 0]])
	assert_eq(s.quests[&"fx_quest"], 10)
	assert_eq(ev, [])
	ev = _run([["quest", "fx_quest", 10]])
	assert_eq(ev, [])

func test_eff_quest_done_grants_xp_to_all() -> void:
	_add_necro("fx_priest")
	var ev: Array[Dictionary] = _run([["quest", "fx_quest", 100]])
	assert_eq(s.quests[&"fx_quest"], 100)
	assert_eq(ev[0], {"type": "quest_changed", "quest": "fx_quest", "stage": 100})
	assert_eq(count_events(ev, "xp_gained"), 2)
	assert_eq(s.party[0].xp, 48)
	assert_eq(s.party[1].xp, 48)
	ev = _run([["quest", "fx_quest", 100]])
	assert_eq(ev, [], "done only once")
	assert_eq(s.party[0].xp, 48)

func test_eff_page_once() -> void:
	var ev: Array[Dictionary] = _run([["page", "fx_page_1"]])
	assert_eq(s.pages, [&"fx_page_1"])
	assert_eq(ev[0], {"type": "page_found", "page": "fx_page_1"})
	assert_eq(ev[1], {"type": "xp_gained", "unit": &"hero", "amount": 24})
	ev = _run([["page", "fx_page_1"]])
	assert_eq(ev, [])
	assert_eq(s.pages, [&"fx_page_1"])
	assert_eq(s.party[0].xp, 24)

func test_eff_xp_to_every_member_with_level_up() -> void:
	_add_necro("fx_priest")
	var ev: Array[Dictionary] = _run([["xp", 120]])
	assert_eq(s.party[0].level, 2)
	assert_eq(s.party[1].level, 2)
	assert_eq(count_events(ev, "xp_gained"), 2)
	assert_eq(count_events(ev, "level_up"), 2)
	assert_eq(s.party[1].stats.wits, 7, "necro's top stat")

func test_eff_recruit() -> void:
	s.party[0].gain_xp(120 + 240, defs.get_def(&"class", &"fx_knight"))   # level 3
	var ev: Array[Dictionary] = _run([["recruit", "fx_priest"]])
	assert_eq(s.party.size(), 2)
	var c: Character = s.party[1]
	assert_eq(c.id, &"fx_priest")
	assert_eq(c.name_key, "fx_npc_priest")
	assert_eq(c.class_id, &"fx_necro")
	assert_eq(c.level, 3)
	assert_eq(c.max_hp, 28)
	assert_eq(c.hp, 28)
	assert_eq(ev, [{"type": "recruited", "unit": &"fx_priest"}])

func test_eff_recruit_twice_does_nothing() -> void:
	_run([["recruit", "fx_priest"]])
	var ev: Array[Dictionary] = _run([["recruit", "fx_priest"]])
	assert_eq(s.party.size(), 2)
	assert_eq(ev, [])

func test_eff_recruit_party_full() -> void:
	_add_necro("a"); _add_necro("b"); _add_necro("c")
	var ev: Array[Dictionary] = _run([["recruit", "fx_priest"]])
	assert_eq(s.party.size(), 4)
	assert_eq(ev, [{"type": "toast", "text_key": "party_full"}])

func test_eff_heal_party() -> void:
	var c: Character = _add_necro("fx_priest")
	s.party[0].hp = 1; s.party[0].mana = 0; s.party[0].charge = 0
	c.hp = 0; c.mana = 2
	var ev: Array[Dictionary] = _run([["heal_party"]])
	assert_eq(s.party[0].hp, 30); assert_eq(s.party[0].mana, 4); assert_eq(s.party[0].charge, 4)
	assert_eq(c.hp, 20); assert_eq(c.mana, 10)
	assert_eq(ev, [{"type": "healed_party"}])

func test_eff_battle_request() -> void:
	var before: Dictionary = s.to_dict()
	var ev: Array[Dictionary] = _run([["battle", "fx_wolves"]])
	assert_eq(ev, [{"type": "battle_requested", "encounter": "fx_wolves"}])
	assert_eq(s.to_dict(), before)

func test_eff_shop_request() -> void:
	var before: Dictionary = s.to_dict()
	var ev: Array[Dictionary] = _run([["shop", "fx_shop"]])
	assert_eq(ev, [{"type": "shop_requested", "shop": "fx_shop"}])
	assert_eq(s.to_dict(), before)

func test_eff_discover() -> void:
	var ev: Array[Dictionary] = _run([["discover", "fx_cave"]])
	assert_eq(s.discovered, [&"fx_cave"])
	assert_eq(ev[0], {"type": "discovered", "location": "fx_cave"})
	assert_eq(ev[1].type, "revealed")
	# fx_cave is at (9, 6) on a 12x8 map: x 7..11, y 4..7 -> 20 cells
	assert_eq(ev[1].cells.size(), 20)
	assert_eq(s.revealed.size(), 20)
	assert_has(s.revealed, "11,7")
	ev = _run([["discover", "fx_cave"]])
	assert_eq(s.discovered, [&"fx_cave"], "once")
	assert_eq(ev, [])

func test_eff_teleport() -> void:
	var ev: Array[Dictionary] = _run([["teleport", "fx_cave"]])
	assert_eq(s.world_pos, Vector2i(9, 6))
	assert_eq(ev, [{"type": "teleported", "location": "fx_cave"}])

func test_eff_unknown_location_skipped() -> void:
	expect_errors(2)
	assert_eq(_run([["teleport", "nowhere"]]), [])
	assert_eq(_run([["discover", "nowhere"]]), [])
	assert_eq(s.world_pos, Vector2i.ZERO)

func test_eff_narrate() -> void:
	var ev: Array[Dictionary] = _run([["narrate", "fx_line"]])
	assert_eq(ev, [{"type": "narrator", "line_key": "fx_line"}])

func test_eff_roll_pass_and_fail() -> void:
	# d20 + best wits (2) >= dc. Seeded: predict the die from a twin Rng.
	for seed_value in 30:
		before_each()
		rng = Rng.new(seed_value)
		var d20: int = Rng.new(seed_value).roll(20)
		var ev: Array[Dictionary] = _run([["roll", "wits", 12, [["gold", 1]], [["gold", -1]]]])
		var passed: bool = d20 + 2 >= 12
		assert_eq(ev[0], {"type": "roll", "stat": "wits", "dc": 12, "total": d20 + 2, "passed": passed})
		assert_eq(ev.size(), 2, "exactly one branch")
		assert_eq(s.gold, 31 if passed else 29)

func test_eff_roll_uses_best_stat() -> void:
	_add_necro("fx_priest")
	rng = Rng.new(4)
	var d20: int = Rng.new(4).roll(20)
	var ev: Array[Dictionary] = _run([["roll", "wits", 12, [], []]])
	assert_eq(ev[0].total, d20 + 6)
	assert_eq(ev.size(), 1)

func test_effects_in_order() -> void:
	var ev: Array[Dictionary] = _run([["gold", 1], ["set_flag", "x", 1], ["narrate", "fx_line"]])
	assert_eq(ev.map(func(e: Dictionary) -> String: return e.type), ["gold_changed", "flag_set", "narrator"])

func test_unknown_effect_skipped_one_error() -> void:
	expect_errors(1)
	var ev: Array[Dictionary] = _run([["summon_cthulhu", 1], ["gold", 1]])
	assert_eq(ev, [{"type": "gold_changed", "delta": 1}])
	assert_eq(s.gold, 31)

func test_malformed_effect_skipped_one_error() -> void:
	expect_errors(2)
	assert_eq(_run([["gold"]]), [])
	assert_eq(_run([42]), [])

func test_roll_chance() -> void:
	assert_eq(Rules.roll_chance(12, 2), 55)
	assert_eq(Rules.roll_chance(30, 0), 0)
	assert_eq(Rules.roll_chance(1, 10), 100)
	assert_eq(Rules.roll_chance(20, 0), 5)

func test_best_stat() -> void:
	assert_eq(Rules.best_stat(s, "might"), 6)
	_add_necro("fx_priest")
	assert_eq(Rules.best_stat(s, "wits"), 6)
