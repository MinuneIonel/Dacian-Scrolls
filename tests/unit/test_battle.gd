## Battle setup, turns, rules, end conditions (WP-12).
extends "res://tests/unit/combat_case.gd"

func test_setup_places_units_and_refills_mana_not_charge() -> void:
	var k := mk("k"); k.charge = 2
	var down := mk("d", "fx_knight", {}, [], 0)
	var n := mk("n", "fx_necro")
	var b := battle("fx_wolves", [k, down, n])
	var us: Array[Dictionary] = b.units()
	assert_eq(us.size(), 4, "2 party (downed one skipped) + 2 wolves")
	var ku: Dictionary = b.unit(uid_of(b, "k"))
	assert_eq(ku.cell, Vector2i(1, 2))
	assert_eq(b.unit(uid_of(b, "n")).cell, Vector2i(1, 3), "spawns in order, skipping the downed")
	assert_eq(ku.mana, 10)
	assert_eq(ku.charge, 2)
	assert_eq(ku.side, "party")
	assert_eq(us[2].side, "enemy")
	assert_eq(us[2].cell, Vector2i(6, 2))
	assert_eq(b.grid.size, Vector2i(8, 7))

func test_start_events_and_initiative_order() -> void:
	var b := battle("fx_wolves", [mk("k", "fx_knight", {"agility": 30})])
	var ev: Array[Dictionary] = b.start()
	assert_eq(ev[0], {"type": "battle_started", "round": 1})
	var ts: Dictionary = find_event(ev, "turn_started")
	assert_eq(ts.uid, uid_of(b, "k"), "agility 30 always goes first")
	assert_eq(ts.ap, 21)
	assert_eq(b.current_unit(), uid_of(b, "k"))
	assert_eq(b.turn_order().size(), 3)
	assert_eq(b.start(), [{"type": "illegal", "reason": "already_started"}])

func test_initiative_ties_go_to_party_then_list_order() -> void:
	# Every unit has the same agility in many seeds; ties must keep party first.
	for s in 30:
		var b := battle("fxc_pair", [mk("a", "fx_knight", {"agility": 0}), mk("b", "fx_knight", {"agility": 0})], s)
		var rolls: Array = []
		var r := Rng.new(s)
		for i in 4: rolls.append(Formulas.initiative(0, r))
		b.start()
		var order: Array[int] = b.turn_order()
		for i in order.size() - 1:
			var a: int = order[i] - 1
			var c: int = order[i + 1] - 1
			assert_true(rolls[a] > rolls[c] or (rolls[a] == rolls[c] and a < c), "seed %d" % s)

func test_ap_formula_at_turn_start() -> void:
	var b := battle("fxc_duel", [mk("k", "fx_knight", {"agility": 4})])
	b.start()
	var ev: Array[Dictionary] = until_turn(b, uid_of(b, "k"))
	var ap: int = b.unit(uid_of(b, "k")).ap
	assert_eq(ap, 8)

func test_end_turn_always_legal_and_only_current_unit_acts() -> void:
	var b := battle("fxc_duel", [mk("k")])
	assert_eq(b.legal_actions(1), [], "not started")
	b.start()
	var cur: int = b.current_unit()
	assert_true(has_action(b.legal_actions(cur), {"type": "end_turn"}))
	var other: int = 1 if cur != 1 else 2
	assert_eq(b.legal_actions(other), [])

func test_walled_in_unit_has_exactly_end_turn() -> void:
	var b := battle("fxc_box", [mk("k", "fx_knight", {"agility": 30}, ["fx_zap", "fx_ward"])])
	b.start()
	var k: int = uid_of(b, "k")
	assert_eq(b.current_unit(), k)
	b.debug_set(k, "ap", 0)
	assert_eq(b.legal_actions(k), [{"type": "end_turn"}])
	b.debug_set(k, "ap", 2)
	b.debug_set(k, "charge", 0)
	b.debug_set(k, "mana", 0)
	assert_eq(b.legal_actions(k), [{"type": "end_turn"}], "walls all round, nothing affordable")

func test_zero_ap_unit_in_open_has_only_end_turn_and_flee() -> void:
	var b := battle("fxc_duel", [mk("k", "fx_knight", {"agility": 30})])
	b.start()
	b.debug_set(1, "ap", 0)
	assert_eq(b.legal_actions(1), [{"type": "end_turn"}, {"type": "flee"}])

func test_illegal_actions_change_nothing() -> void:
	var rng := Rng.new(3)
	var b := Battle.new(&"fxc_duel", party([mk("k", "fx_knight", {"agility": 30})]), rng, defs)
	b.start()
	var before: Array[Dictionary] = b.units()
	var state: int = rng.get_state()
	var bad: Array = [
		{"type": "move", "path": [Vector2i(3, 2)]},             # not adjacent to (1,2)
		{"type": "move", "path": [Vector2i(2, 2)]},             # occupied by the dummy
		{"type": "move", "path": []},
		{"type": "move", "path": [Vector2i(1, 1), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5), Vector2i(4, 5), Vector2i(3, 5), Vector2i(2, 5), Vector2i(1, 5), Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3), Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0)]},
		{"type": "ability", "ability": "fx_strike", "cell": Vector2i(4, 4)},
		{"type": "ability", "ability": "fx_heal", "cell": Vector2i(1, 2)},  # not equipped
		{"type": "item", "item": "fxc_medkit", "cell": Vector2i(1, 2)},     # none in inventory
		{"type": "dance"},
		{},
	]
	for a in bad:
		var ev: Array[Dictionary] = b.apply(a)
		assert_eq(ev.size(), 1, str(a))
		assert_eq(ev[0].type, "illegal", str(a))
		assert_true(ev[0].reason is String and ev[0].reason != "")
	assert_eq(b.units(), before)
	assert_eq(rng.get_state(), state)

func test_magic_disabled_removes_magic_abilities() -> void:
	var n := mk("n", "fx_necro", {"agility": 30}, ["fx_raise", "fx_heal", "fx_zap"])
	var b := battle("fx_saucer", [n])
	b.start()
	var abil: Array[String] = abilities_in(b.legal_actions(uid_of(b, "n")))
	assert_not_has(abil, "fx_heal")
	assert_has(abil, "fx_zap")
	var ev: Array[Dictionary] = b.apply({"type": "ability", "ability": "fx_heal", "cell": Vector2i(1, 2)})
	assert_eq(ev[0].reason, "magic_disabled")
	var b2 := battle("fx_wolves", [mk("n", "fx_necro", {"agility": 30}, ["fx_heal"])])
	b2.start()
	assert_has(abilities_in(b2.legal_actions(1)), "fx_heal")

func test_basic_attack_plus_at_most_four_equipped() -> void:
	var k := mk("k", "fx_knight", {}, ["fx_ward", "fx_zap", "fx_heal", "fx_raise", "fxc_shove"])
	var b := battle("fxc_duel", [k])
	var abil: Array = b.unit(1).abilities
	assert_eq(abil, [&"fx_strike", &"fx_ward", &"fx_zap", &"fx_heal", &"fx_raise"])

func test_floaty_three_cell_move_costs_six() -> void:
	var b := battle("fxc_floaty", [mk("k", "fx_knight", {"agility": 30})])
	b.start()
	var ap0: int = b.unit(1).ap
	var ev: Array[Dictionary] = b.apply({"type": "move", "path": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]})
	assert_eq(find_event(ev, "moved").path, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	assert_eq(b.unit(1).ap, ap0 - 6)

func test_floaty_drift_happens_about_a_quarter_of_the_time() -> void:
	var drifts: int = 0
	for s in 200:
		var b := battle("fxc_floaty", [mk("k", "fx_knight", {"agility": 30})], s)
		b.start()
		var ev: Array[Dictionary] = b.apply({"type": "move", "path": [Vector2i(1, 0), Vector2i(2, 0)]})
		var d: Dictionary = find_event(ev, "drifted")
		if not d.is_empty():
			drifts += 1
			assert_eq(d.from, Vector2i(2, 0))
			assert_eq(Battle._dist(d.to, d.from), 1)
			assert_eq(b.unit(1).cell, d.to)
	assert_between(drifts, 25, 75)

func test_normal_gravity_never_drifts_and_moves_cost_one() -> void:
	var b := battle("fxc_duel", [mk("k", "fx_knight", {"agility": 30})])
	b.start()
	var ev: Array[Dictionary] = b.apply({"type": "move", "path": [Vector2i(1, 1), Vector2i(1, 0)]})
	assert_eq(b.unit(1).ap, 19)
	assert_eq(count_events(ev, "drifted"), 0)
	assert_eq(b.unit(1).cell, Vector2i(1, 0))

func test_legal_moves_are_all_affordable_and_cover_reachable() -> void:
	var b := battle("fxc_duel", [mk("k", "fx_knight", {"agility": 0})])
	b.start()
	until_turn(b, 1)
	var moves: Array = b.legal_actions(1).filter(func(a: Dictionary) -> bool: return a.type == "move")
	var ends: Dictionary = {}
	for m in moves:
		assert_true(m.path.size() <= 6)
		ends[m.path[-1]] = true
	assert_eq(ends.size(), b.grid.reachable(Vector2i(1, 2), 6, 1, {Vector2i(2, 2): true}).size() - 1)

func test_turn_limit_timer_and_timeout() -> void:
	var b := battle("fx_saucer", [mk("k")])
	var ev: Array[Dictionary] = b.start()
	for i in 500:
		if b.is_over(): break
		ev.append_array(b.apply({"type": "end_turn"}))
	var timers: Array[Dictionary] = events_of(ev, "timer")
	assert_eq(timers.size(), 8)
	assert_eq(timers[0].turns_left, 8)
	assert_eq(timers[7].turns_left, 1)
	assert_eq(ev[-1], {"type": "battle_ended", "outcome": "lose", "reason": "timeout"})
	assert_eq(b.round, 8)
	assert_eq(b.result().outcome, "lose")
	assert_eq(b.result().reason, "timeout")
	assert_eq(b.legal_actions(b.current_unit()), [])
	assert_eq(b.apply({"type": "end_turn"})[0].reason, "battle_over")

func test_flee_not_legal_with_turn_limit() -> void:
	var b := battle("fx_saucer", [mk("k", "fx_knight", {"agility": 30})])
	b.start()
	assert_false(has_action(b.legal_actions(1), {"type": "flee"}))
	assert_eq(b.apply({"type": "flee"})[0].type, "illegal")

func test_stalemate_after_sixty_rounds() -> void:
	var b := battle("fxc_duel", [mk("k")])
	var ev: Array[Dictionary] = b.start()
	for i in 1000:
		if b.is_over(): break
		ev.append_array(b.apply({"type": "end_turn"}))
	assert_true(b.is_over())
	assert_eq(b.round, 60)
	assert_eq(ev[-1], {"type": "battle_ended", "outcome": "lose", "reason": "stalemate"})
	assert_eq(count_events(ev, "turn_started"), 120)

func test_flee_success_and_failure() -> void:
	var b := battle("fxc_duel", [mk("k", "fx_knight", {"agility": 30})])
	b.start()
	var ev: Array[Dictionary] = b.apply({"type": "flee"})
	assert_eq(ev[0], {"type": "fled", "success": true})
	assert_eq(ev[-1], {"type": "battle_ended", "outcome": "fled", "reason": "fled"})
	assert_eq(b.result().outcome, "fled")
	assert_eq(b.result().loot, {})
	# agility -20: d20 - 20 can never reach 11.
	var b2 := battle("fxc_duel", [mk("k", "fx_knight", {"agility": -20}), mk("j", "fx_knight", {"agility": 30})])
	b2.start()
	until_turn(b2, 1)
	var ev2: Array[Dictionary] = b2.apply({"type": "flee"})
	assert_eq(ev2[0], {"type": "fled", "success": false})
	assert_false(b2.is_over())
	assert_ne(b2.current_unit(), 1, "a failed flee ends the turn")

func test_flee_threshold_counts_living_enemies() -> void:
	# agility 0, 2 enemies: needs d20 >= 12, i.e. 45%.
	var ok: int = 0
	for s in 400:
		var b := battle("fxc_pair", [mk("k", "fx_knight", {"agility": 0})], s)
		b.start()
		until_turn(b, 1)
		if b.apply({"type": "flee"})[0].success: ok += 1
	assert_between(ok, 140, 220)

func test_win_restores_downed_at_one_hp_and_reports_result() -> void:
	var k := mk("k", "fx_knight", {"agility": 30, "might": 60})
	var j := mk("j", "fx_knight", {"agility": -5})
	var b := battle("fxc_duel", [k, j])
	b.start()
	b.debug_set(2, "hp", 0)
	b.debug_set(2, "downed", true)
	var ev: Array[Dictionary] = []
	for i in 20:
		ev = b.apply({"type": "ability", "ability": "fx_strike", "cell": Vector2i(2, 2)})
		if b.is_over(): break
		b.debug_set(1, "ap", 20)
	assert_true(b.is_over())
	assert_eq(ev[-1], {"type": "battle_ended", "outcome": "win", "reason": "enemies_defeated"})
	var r: Dictionary = b.result()
	assert_eq(r.outcome, "win")
	assert_eq(r.downed, [&"j"])
	assert_eq(r.party_hp, {&"k": 30, &"j": 1})
	assert_eq(r.party_mana, {&"k": 10, &"j": 10})
	assert_eq(r.party_charge, {&"k": 6, &"j": 6})
	assert_eq(r.loot, {&"fx_bread": 1})
	assert_eq(r.items_used, {})

func test_lose_when_every_party_member_is_down() -> void:
	var k := mk("k", "fx_knight", {"agility": -10}, [], 1)
	var b := battle("fxc_duel", [k])
	b.start()
	var d: int = uid_of(b, "fxc_dummy")
	until_turn(b, d)
	b.debug_set(d, "stats", {"might": 0, "agility": 40, "wits": 0, "spirit": 0})
	var ev: Array[Dictionary] = b.apply({"type": "ability", "ability": "fxc_poke", "cell": Vector2i(1, 2)})
	var died: Dictionary = find_event(ev, "died")
	assert_eq(died, {"type": "died", "target": 1, "gib": false, "corpse": false})
	assert_true(b.unit(1).downed, "downed, not removed")
	assert_eq(b.unit(1).hp, 0)
	assert_eq(ev[-1], {"type": "battle_ended", "outcome": "lose", "reason": "party_down"})
	assert_eq(b.result().party_hp, {&"k": 0})
	assert_eq(b.result().downed, [&"k"])

func test_is_ai() -> void:
	var b := battle("fxc_duel", [mk("k")])
	assert_false(b.is_ai(1))
	assert_true(b.is_ai(2))
	assert_false(b.is_ai(99))
