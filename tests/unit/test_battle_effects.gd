## Every ability effect kind, cover, flank, crits, gibs, corpses, summons, hazards, items (WP-12).
extends "res://tests/unit/combat_case.gd"

## fxc_duel with the knight acting first; dummy at (2,2), knight at (1,2).
func duel(eq: Array = [], stats: Dictionary = {}, seed: int = 1, extra: Array = []) -> Battle:
	var st: Dictionary = {"agility": 40}
	for k in stats: st[k] = stats[k]
	var chars: Array = [mk("k", "fx_knight", st, eq)]
	chars.append_array(extra)
	var b := battle("fxc_duel", chars, seed)
	b.start()
	return b

func test_damage() -> void:
	var ev: Array[Dictionary] = first_hit(func(s: int) -> Battle: return duel([], {}, s),
		{"type": "ability", "ability": "fx_strike", "cell": Vector2i(2, 2)})
	assert_eq(ev[0], {"type": "ability_used", "uid": 1, "ability": &"fx_strike", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "damaged"), {"type": "damaged", "target": 2, "amount": 10, "crit": false, "shield_absorbed": 0})
	assert_eq(hb.unit(2).hp, 50)
	assert_eq(hb.unit(1).ap, 26 - 3)

func test_damage_uses_weapon_and_armor() -> void:
	var build := func(s: int) -> Battle:
		var k := mk("k", "fx_knight", {"agility": 40})
		k.gear = {"weapon": &"fx_sword", "armor": &"fxc_plate", "trinket": &""}
		var b := battle("fxc_duel", [k], s)
		b.start()
		return b
	var ev: Array[Dictionary] = first_hit(build, {"type": "ability", "ability": "fx_strike", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "damaged").amount, 12, "4 + 6 + sword 2")
	assert_eq(hb.unit(1).armor, 2)

func test_crit_doubles_and_natural_twenty_always_hits() -> void:
	var crits: int = 0
	for s in 200:
		var b := duel([], {}, s)
		b.debug_set(2, "stats", {"might": 0, "agility": 200, "wits": 0, "spirit": 0})  # 5%: only natural 20s land
		var ev: Array[Dictionary] = b.apply({"type": "ability", "ability": "fx_strike", "cell": Vector2i(2, 2)})
		var d: Dictionary = find_event(ev, "damaged")
		if d.is_empty():
			assert_eq(find_event(ev, "missed"), {"type": "missed", "uid": 1, "target": 2})
		else:
			crits += 1
			assert_true(d.crit)
			assert_eq(d.amount, 20)
	assert_between(crits, 3, 20)

func test_ignore_armor_and_push() -> void:
	var build := func(s: int) -> Battle:
		var b := duel(["fx_zap"], {}, s)
		b.debug_set(2, "armor", 50)
		return b
	var ev: Array[Dictionary] = first_hit(build, {"type": "ability", "ability": "fx_zap", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "damaged").amount, 8, "6 + wits 4 * 0.5, armor ignored")
	assert_eq(find_event(ev, "pushed"), {"type": "pushed", "target": 2, "path": [Vector2i(3, 2)]})
	assert_eq(hb.unit(2).cell, Vector2i(3, 2))
	assert_eq(hb.unit(1).charge, 4)

func test_push_stops_at_blockers() -> void:
	var build := func(s: int) -> Battle:
		var b := duel(["fxc_shove"], {}, s)
		b.grid.set_walkable(Vector2i(4, 2), false)
		return b
	var ev: Array[Dictionary] = first_hit(build, {"type": "ability", "ability": "fxc_shove", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "pushed").path, [Vector2i(3, 2)])

func test_floaty_push_adds_two() -> void:
	var build := func(s: int) -> Battle:
		var b := battle("fxc_floaty", [mk("k", "fx_knight", {"agility": 40}, ["fxc_shove"])], s)
		b.start()
		b.place(2, Vector2i(1, 0))
		return b
	var ev: Array[Dictionary] = first_hit(build, {"type": "ability", "ability": "fxc_shove", "cell": Vector2i(1, 0)})
	assert_eq(find_event(ev, "pushed").path, [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)])

func test_heal_cleanse_regen() -> void:
	var n := mk("n", "fx_necro", {"agility": -5, "spirit": 4}, ["fx_heal"])
	var b := duel([], {}, 1, [n])
	var nid: int = uid_of(b, "n")
	b.debug_set(1, "hp", 10)
	b.debug_set(1, "statuses", {"bleeding": {"turns": 2, "value": 3}, "slowed": {"turns": 3, "value": 0}})
	until_turn(b, nid)
	var ev: Array[Dictionary] = b.apply({"type": "ability", "ability": "fx_heal", "cell": Vector2i(1, 2)})
	assert_eq(find_event(ev, "healed"), {"type": "healed", "target": 1, "amount": 10})
	assert_eq(count_events(ev, "status_ended"), 2)
	assert_eq(find_event(ev, "status"), {"type": "status", "target": 1, "status": "regen", "turns": 2})
	assert_eq(count_events(ev, "missed"), 0, "heals never miss")
	assert_eq(b.unit(1).hp, 20)
	assert_eq(b.unit(nid).mana, 7)
	# Regen ticks at the knight's next turn start.
	var ev2: Array[Dictionary] = until_turn(b, 1)
	assert_eq(find_event(ev2, "healed"), {"type": "healed", "target": 1, "amount": 2})

func test_heal_caps_at_max_and_cannot_target_enemy() -> void:
	var b := duel(["fx_heal"])
	var acts: Array[Dictionary] = b.legal_actions(1)
	assert_true(has_action(acts, {"type": "ability", "ability": "fx_heal", "cell": Vector2i(1, 2)}))
	assert_false(has_action(acts, {"type": "ability", "ability": "fx_heal", "cell": Vector2i(2, 2)}))
	var ev: Array[Dictionary] = b.apply({"type": "ability", "ability": "fx_heal", "cell": Vector2i(1, 2)})
	assert_eq(find_event(ev, "healed").amount, 0)

func test_shield_absorbs_damage_first() -> void:
	var b := duel(["fx_ward"])
	b.apply({"type": "ability", "ability": "fx_ward", "cell": Vector2i(1, 2)})
	assert_eq(b.unit(1).statuses.shield, {"turns": 2, "value": 6})
	var ev: Array[Dictionary] = []
	b.debug_set(2, "hp", 3)
	b.debug_set(2, "stats", {"might": 3, "agility": 99, "wits": 0, "spirit": 0})
	b.debug_set(2, "statuses", {})
	until_turn(b, 2)
	b.debug_set(2, "ap", 10)
	ev = b.apply({"type": "ability", "ability": "fxc_poke", "cell": Vector2i(1, 2)})
	var d: Dictionary = find_event(ev, "damaged")
	if d.crit:
		assert_eq(d.shield_absorbed, 6); assert_eq(d.amount, 2)
	else:
		assert_eq(d, {"type": "damaged", "target": 1, "amount": 0, "crit": false, "shield_absorbed": 4})
		assert_eq(b.unit(1).statuses.shield.value, 2)

func test_taunt_restricts_attacks_to_taunter() -> void:
	var j := mk("j", "fx_knight", {"agility": -5})
	var build := func(s: int) -> Battle:
		var b := duel(["fx_ward"], {}, s, [j])
		b.place(3, Vector2i(2, 3))   # dummy adjacent to knight (2,2) and j (1,3)
		b.place(1, Vector2i(2, 2))
		return b
	var ev: Array[Dictionary] = first_hit(build, {"type": "ability", "ability": "fx_ward", "cell": Vector2i(2, 2)})
	var st: Array[Dictionary] = events_of(ev, "status")
	assert_has(st, {"type": "status", "target": 3, "status": "taunted", "turns": 2})
	assert_has(st, {"type": "status", "target": 1, "status": "shield", "turns": 2})
	assert_has(st, {"type": "status", "target": 2, "status": "shield", "turns": 2}, "ward shields allies in area 3")
	until_turn(hb, 3)
	var acts: Array[Dictionary] = hb.legal_actions(3)
	var targets: Array = []
	for a in acts:
		if a.type == "ability": targets.append(a.cell)
	assert_eq(targets, [Vector2i(2, 2)], "only the taunter, although j at (1,3) is adjacent")
	assert_eq(hb.apply({"type": "ability", "ability": "fxc_poke", "cell": Vector2i(1, 3)})[0].reason, "taunted")

func test_taunt_lifts_when_taunter_is_down() -> void:
	var j := mk("j", "fx_knight", {"agility": -5})
	var b := duel([], {}, 1, [j])
	b.place(3, Vector2i(1, 3)); b.place(2, Vector2i(0, 3))
	b.debug_set(3, "statuses", {"taunted": {"turns": 3, "value": 0, "by": 1}})
	b.place(1, Vector2i(1, 4))
	until_turn(b, 3)
	b.debug_set(1, "downed", true)
	var targets: Array = []
	for a in b.legal_actions(3):
		if a.type == "ability": targets.append(a.cell)
	assert_eq(targets, [Vector2i(0, 3)])

func test_status_stunned_skips_turn() -> void:
	var ev: Array[Dictionary] = first_hit(func(s: int) -> Battle: return duel(["fxc_stun"], {}, s),
		{"type": "ability", "ability": "fxc_stun", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "status"), {"type": "status", "target": 2, "status": "stunned", "turns": 1})
	var ev2: Array[Dictionary] = hb.apply({"type": "end_turn"})
	assert_has(ev2, {"type": "turn_started", "uid": 2, "ap": 0})
	assert_has(ev2, {"type": "status_ended", "target": 2, "status": "stunned"})
	assert_eq(hb.current_unit(), 1, "back to the knight")
	assert_eq(hb.round, 2)

func test_status_bleeding_ticks_at_turn_start() -> void:
	var ev: Array[Dictionary] = first_hit(func(s: int) -> Battle: return duel(["fxc_bleed"], {}, s),
		{"type": "ability", "ability": "fxc_bleed", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "status"), {"type": "status", "target": 2, "status": "bleeding", "turns": 2})
	var ev2: Array[Dictionary] = hb.apply({"type": "end_turn"})
	assert_eq(find_event(ev2, "damaged"), {"type": "damaged", "target": 2, "amount": 3, "crit": false, "shield_absorbed": 0})
	assert_eq(hb.unit(2).hp, 57)

func test_status_slowed_and_chilled() -> void:
	var ev: Array[Dictionary] = first_hit(func(s: int) -> Battle: return duel(["fxc_slow"], {}, s),
		{"type": "ability", "ability": "fxc_slow", "cell": Vector2i(2, 2)})
	assert_eq(count_events(ev, "status"), 2)
	var ev2: Array[Dictionary] = hb.apply({"type": "end_turn"})
	assert_has(ev2, {"type": "turn_started", "uid": 2, "ap": 3}, "6 - chilled 3")
	var ev3: Array[Dictionary] = hb.apply({"type": "move", "path": [Vector2i(3, 2)]})
	assert_eq(hb.unit(2).ap, 1, "slowed: 2 AP per cell")
	assert_eq(hb.apply({"type": "move", "path": [Vector2i(4, 2)]})[0].reason, "not_enough_ap")

func test_status_charmed_flips_side() -> void:
	var ev: Array[Dictionary] = first_hit(func(s: int) -> Battle: return duel(["fxc_charm"], {}, s),
		{"type": "ability", "ability": "fxc_charm", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "status").status, "charmed")
	assert_true(hb.are_allies(1, 2))
	assert_true(hb.is_ai(2))
	hb.apply({"type": "end_turn"})
	assert_eq(hb.current_unit(), 2)
	assert_eq(abilities_in(hb.legal_actions(2)), [], "no hostiles to poke: the knight is a friend now")
	var ev2: Array[Dictionary] = hb.apply({"type": "end_turn"})
	assert_has(ev2, {"type": "status_ended", "target": 2, "status": "charmed"})
	assert_false(hb.are_allies(1, 2))

func test_area_and_range_are_manhattan() -> void:
	# fxc_bolt: range 5, area 1, target cell, damage only hits hostiles.
	var b := duel(["fxc_bolt"])
	var acts: Array[Dictionary] = b.legal_actions(1)
	assert_false(has_action(acts, {"type": "ability", "ability": "fxc_bolt", "cell": Vector2i(5, 4)}))
	assert_true(has_action(acts, {"type": "ability", "ability": "fxc_bolt", "cell": Vector2i(4, 4)}))

func test_area_hits_only_hostiles_in_radius() -> void:
	var n := mk("n", "fx_necro", {"agility": -5})
	var build := func(s: int) -> Battle:
		var b := battle("fxc_pair", [mk("k", "fx_knight", {"agility": 40}, ["fxc_bolt"]), n], s)
		b.start()
		b.place(4, Vector2i(3, 2))  # second dummy next to the first
		b.place(uid_of(b, "n"), Vector2i(2, 1))
		return b
	var ev: Array[Dictionary] = first_hit(build, {"type": "ability", "ability": "fxc_bolt", "cell": Vector2i(2, 2)})
	var dm: Array[Dictionary] = events_of(ev, "damaged")
	assert_eq(dm.size(), 2)
	assert_eq(dm[0].target, uid_of(hb, "fxc_dummy"))
	assert_eq(dm[0].amount, 5)

func test_cover_and_flank() -> void:
	var j := mk("j", "fx_knight", {"agility": 0})
	var b := duel(["fx_zap"], {"agility": 0}, 1, [j])
	b.place(3, Vector2i(4, 2))
	b.place(2, Vector2i(0, 0))
	assert_eq(b.hit_chance(1, 3, &"fx_zap"), 75)
	b.grid.set_cover(Vector2i(3, 2), 20)
	assert_eq(b.hit_chance(1, 3, &"fx_zap"), 55, "cover of the cell next to the target toward the attacker")
	assert_eq(b.hit_chance(1, 3, &"fx_strike"), 75, "melee ignores cover")
	b.place(2, Vector2i(5, 2))
	assert_eq(b.hit_chance(1, 3, &"fx_zap"), 70, "ally on the opposite side flanks")
	b.place(2, Vector2i(4, 3))
	assert_eq(b.hit_chance(1, 3, &"fx_zap"), 55, "beside is not opposite")

func test_overkill_gib_and_raise_from_corpse() -> void:
	var n := mk("n", "fx_necro", {"agility": 30}, ["fx_raise"])
	var build := func(s: int) -> Battle:
		var b := battle("fx_wolves", [mk("k", "fx_knight", {"agility": 40}), n], s)
		b.start()
		b.place(3, Vector2i(2, 2))
		b.debug_set(3, "hp", 1)
		return b
	var ev: Array[Dictionary] = first_hit(build, {"type": "ability", "ability": "fx_strike", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "died"), {"type": "died", "target": 3, "gib": true, "corpse": true}, "overkill 9 >= 5")
	assert_eq(hb.corpses(), [{"cell": Vector2i(2, 2), "def_id": &"fx_wolf", "raiseable": true, "machine": false}])
	assert_eq(hb.unit_at(Vector2i(2, 2)), -1)
	until_turn(hb, 2)
	assert_true(has_action(hb.legal_actions(2), {"type": "ability", "ability": "fx_raise", "cell": Vector2i(2, 2)}))
	var ev2: Array[Dictionary] = hb.apply({"type": "ability", "ability": "fx_raise", "cell": Vector2i(2, 2)})
	var sm: Dictionary = find_event(ev2, "summoned")
	assert_eq(sm, {"type": "summoned", "uid": 5, "def_id": &"fx_wolf", "cell": Vector2i(2, 2), "from_corpse": true})
	var w: Dictionary = hb.unit(5)
	assert_eq(w.side, "party"); assert_true(w.summoned); assert_eq(w.hp, 5); assert_eq(w.max_hp, 10)
	assert_true(hb.is_ai(5))
	assert_eq(hb.corpses(), [])
	var order: Array[int] = hb.turn_order()
	assert_eq(order[order.find(2) + 1], 5, "acts right after its summoner")
	assert_false(hb.result().party_hp.has(&""), "summons are not in the result")
	hb.inventory = {&"fxc_medkit": 1}
	until_turn(hb, 5)
	assert_false(hb.legal_actions(5).any(func(a: Dictionary) -> bool: return a.type in ["flee", "item"]), "summons neither flee nor use items")

func test_small_overkill_no_gib_and_non_gib_enemy() -> void:
	var build := func(s: int) -> Battle:
		var b := battle("fx_wolves", [mk("k", "fx_knight", {"agility": 40, "might": 0})], s)
		b.start()
		b.place(2, Vector2i(2, 2))
		b.debug_set(2, "hp", 3)
		return b
	var ev: Array[Dictionary] = first_hit(build, {"type": "ability", "ability": "fx_strike", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "died").gib, false, "4 damage on 3 HP: overkill 1")

func test_non_raiseable_corpse_is_not_a_raise_target_but_machines_reboot() -> void:
	var n := mk("n", "fx_necro", {"agility": 30}, ["fx_raise", "fxc_reboot"])
	var b := battle("fxc_brawl", [n], 1)
	b.start()
	var drone: int = uid_of(b, "fxc_drone")
	b.place(drone, Vector2i(2, 2))
	b.debug_set(drone, "hp", 1)
	for i in 30:
		b.debug_set(1, "ap", 20)
		b.apply({"type": "ability", "ability": "fx_strike", "cell": Vector2i(2, 2)})
		if b.unit(drone).get("dead", false): break
	assert_eq(b.corpses(), [{"cell": Vector2i(2, 2), "def_id": &"fxc_drone", "raiseable": false, "machine": true}])
	var acts: Array[Dictionary] = b.legal_actions(1)
	assert_false(has_action(acts, {"type": "ability", "ability": "fx_raise"}))
	assert_eq(b.apply({"type": "ability", "ability": "fx_raise", "cell": Vector2i(2, 2)})[0].type, "illegal")
	assert_true(has_action(acts, {"type": "ability", "ability": "fxc_reboot", "cell": Vector2i(2, 2)}))
	var ev: Array[Dictionary] = b.apply({"type": "ability", "ability": "fxc_reboot", "cell": Vector2i(2, 2)})
	var sm: Dictionary = find_event(ev, "summoned")
	assert_eq(sm.def_id, &"fxc_drone"); assert_eq(sm.from_corpse, false)
	assert_eq(b.unit(sm.uid).side, "party"); assert_eq(b.unit(sm.uid).hp, 4)

func test_enemy_with_neither_flag_leaves_no_corpse() -> void:
	var b := duel([], {"might": 99})
	for i in 20:
		b.debug_set(1, "ap", 20)
		var ev: Array[Dictionary] = b.apply({"type": "ability", "ability": "fx_strike", "cell": Vector2i(2, 2)})
		if b.is_over():
			assert_eq(find_event(ev, "died"), {"type": "died", "target": 2, "gib": false, "corpse": false})
			break
	assert_eq(b.corpses(), [])

func test_enemy_spawn_summon_full_hp_and_hazards() -> void:
	var b := battle("fxc_lab", [mk("k", "fx_knight", {"agility": 0})], 1)
	b.start()
	var s: int = uid_of(b, "fxc_surgeon")
	until_turn(b, s)
	b.debug_set(s, "ap", 30)
	var ev: Array[Dictionary] = b.apply({"type": "ability", "ability": "fxc_spawn", "cell": Vector2i(4, 2)})
	var sm: Dictionary = find_event(ev, "summoned")
	assert_eq(sm.from_corpse, false)
	assert_eq(b.unit(sm.uid).side, "enemy")
	assert_eq(b.unit(sm.uid).hp, 8)
	# Specimen tank: blocks movement, gives 20 cover.
	ev = b.apply({"type": "ability", "ability": "fxc_tank", "cell": Vector2i(2, 2)})
	assert_eq(find_event(ev, "hazard"), {"type": "hazard", "cell": Vector2i(2, 2), "hazard": "specimen_tank", "turns": 3})
	assert_eq(b.hazards().size(), 1)
	# Acid under the knight at (1,2).
	ev = b.apply({"type": "ability", "ability": "fxc_acid", "cell": Vector2i(1, 2)})
	# Gravity zone area 1 around (2,4): 5 cells (one is water, still a hazard cell).
	ev = b.apply({"type": "ability", "ability": "fxc_gravity", "cell": Vector2i(2, 4)})
	assert_eq(count_events(ev, "hazard"), 5)
	ev = until_turn(b, 1)
	assert_has(ev, {"type": "damaged", "target": 1, "amount": 3, "crit": false, "shield_absorbed": 0}, "acid")
	var acts: Array[Dictionary] = b.legal_actions(1)
	for a in acts:
		if a.type == "move": assert_not_has(a.path, Vector2i(2, 2), "tank blocks")
	assert_eq(b.apply({"type": "move", "path": [Vector2i(2, 2)]})[0].reason, "blocked")
	var ap: int = b.unit(1).ap
	b.apply({"type": "move", "path": [Vector2i(1, 3), Vector2i(2, 3)]})
	assert_eq(b.unit(1).ap, ap - 3, "1 + 2 for the step into the gravity zone")

func test_tank_gives_cover() -> void:
	var b := duel(["fx_zap"], {"agility": 0})
	b.place(2, Vector2i(4, 2))
	assert_eq(b.hit_chance(1, 2, &"fx_zap"), 75)
	b._place_hazard(Vector2i(3, 2), 0, "specimen_tank", 2, [] as Array[Dictionary])
	assert_eq(b.hit_chance(1, 2, &"fx_zap"), 55)

func test_hazards_expire() -> void:
	var b := duel([])
	b._place_hazard(Vector2i(4, 4), 0, "acid", 2, [] as Array[Dictionary])
	var ev: Array[Dictionary] = []
	for i in 6: ev.append_array(b.apply({"type": "end_turn"}))
	assert_has(ev, {"type": "hazard", "cell": Vector2i(4, 4), "hazard": "acid", "turns": 0})
	assert_eq(b.hazards(), [])

func test_item_use_ability() -> void:
	var b := battle("fxc_duel", [mk("k", "fx_knight", {"agility": 40})])
	b.inventory = {&"fxc_medkit": 1, &"fx_bread": 3}
	b.start()
	b.debug_set(1, "hp", 10)
	var acts: Array[Dictionary] = b.legal_actions(1)
	assert_true(has_action(acts, {"type": "item", "item": "fxc_medkit", "cell": Vector2i(1, 2)}))
	assert_false(has_action(acts, {"type": "item", "item": "fx_bread"}), "no use_ability")
	var ev: Array[Dictionary] = b.apply({"type": "item", "item": &"fxc_medkit", "cell": Vector2i(1, 2)})
	assert_eq(ev[0], {"type": "ability_used", "uid": 1, "ability": &"fxc_patch", "cell": Vector2i(1, 2), "item": &"fxc_medkit"})
	assert_eq(find_event(ev, "healed").amount, 5)
	assert_eq(b.inventory, {&"fx_bread": 3})
	assert_eq(b.unit(1).ap, 24)
	assert_false(has_action(b.legal_actions(1), {"type": "item", "item": "fxc_medkit"}))
	assert_eq(b.result().items_used, {&"fxc_medkit": 1})
