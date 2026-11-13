## Combat AI and party policies (WP-20). Fixtures: fxa_* plus the WP-12 fxc_* ones.
extends "res://tests/unit/combat_case.gd"

const FUZZ_ENCOUNTERS: Array[String] = ["fx_wolves", "fx_saucer", "fxc_brawl", "fxc_lab", "fxc_box",
	"fxa_pack", "fxa_coven", "fxa_saucer"]

func random_party(r: Rng) -> Array[Character]:
	var out: Array[Character] = []
	var k := mk("k", "fx_knight", {"agility": r.randi_range(2, 6)}, ["fx_ward", "fx_zap", "fxc_shove", "fxc_stun"])
	k.gear = {"weapon": &"fx_sword", "armor": &"fxc_plate", "trinket": &""}
	out.append(k)
	if r.chance(0.7): out.append(mk("n", "fx_necro", {"agility": r.randi_range(2, 6)}, ["fx_raise", "fx_heal", "fxc_charm", "fxc_reboot"], 20))
	if r.chance(0.5): out.append(mk("t", "fx_knight", {"agility": 3}, ["fxc_bolt", "fxc_bleed", "fxc_slow", "fxc_acid"]))
	return out

## The standard balance party: a knight and a necromancer built from the class defs.
func class_party() -> Array[Character]:
	var out: Array[Character] = []
	out.append(Character.create(&"k", defs.get_def(&"class", &"fx_knight"), "fx_class_knight"))
	out.append(Character.create(&"n", defs.get_def(&"class", &"fx_necro"), "fx_class_necro"))
	return out

func is_legal(b: Battle, uid: int, a: Dictionary) -> bool:
	return b.legal_actions(uid).has(a)

## Plays uid's turn with policy (Callable(battle, uid, rng)); returns all events of that turn.
func run_turn(b: Battle, uid: int, policy: Callable, rng: Rng) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	for i in 40:
		if b.is_over() or b.current_unit() != uid: return ev
		var a: Dictionary = policy.call(b, uid, rng)
		assert_true(is_legal(b, uid, a), "legal: %s" % str(a))
		ev.append_array(b.apply(a))
	fail("turn of %d did not end" % uid)
	return ev

## Plays a whole battle: party units use party_policy (unless AI-driven), the rest Ai.choose.
## Returns {outcome, rounds, actions}.
func play(b: Battle, party_policy: Callable, rng: Rng) -> Dictionary:
	b.start()
	var n: int = 0
	while not b.is_over() and n < 6000:
		var uid: int = b.current_unit()
		var a: Dictionary = Ai.choose(b, uid, rng) if b.is_ai(uid) else party_policy.call(b, uid, rng)
		var ev: Array[Dictionary] = b.apply(a)
		if count_events(ev, "illegal") > 0:
			fail("illegal %s -> %s" % [a, ev])
			break
		n += 1
	return {"outcome": b.result().outcome, "rounds": b.round, "actions": n, "over": b.is_over()}

func uses_of(ev: Array, ability: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in ev:
		if e.type == "ability_used" and str(e.ability) == ability: out.append(e)
	return out

# ---- legality ---------------------------------------------------------------

func test_every_policy_returns_a_legal_action_over_300_states() -> void:
	var checked: int = 0
	var s: int = 0
	while checked < 300:
		s += 1
		var r := Rng.new(s * 31 + 7)
		var enc: String = FUZZ_ENCOUNTERS[s % FUZZ_ENCOUNTERS.size()]
		var b := Battle.new(StringName(enc), random_party(r), Rng.new(s), defs)
		b.inventory = {&"fxc_medkit": 1}
		b.start()
		var steps: int = r.randi_range(0, 60)
		for i in steps:
			if b.is_over(): break
			var uid0: int = b.current_unit()
			b.apply(Ai.policy_random(b, uid0, r) if r.chance(0.5) else Ai.choose(b, uid0, r))
		if b.is_over(): continue
		var uid: int = b.current_unit()
		for pol in [Ai.choose, Ai.policy_good, Ai.policy_random]:
			var a: Dictionary = pol.call(b, uid, r)
			assert_true(is_legal(b, uid, a), "seed %d %s: %s" % [s, enc, a])
		checked += 1

func test_not_current_unit_gets_an_empty_action() -> void:
	var b := battle("fxa_pack", [mk("k")])
	b.start()
	var other: int = 1 if b.current_unit() != 1 else 2
	assert_eq(Ai.choose(b, other, Rng.new(1)), {})

func test_never_a_zero_length_move_and_turns_end() -> void:
	# Boxed in (fxc_box): the knight at (1,1) cannot move; the AI must end the turn.
	var b := battle("fxc_box", [mk("k")])
	b.start()
	var k: int = uid_of(b, "k")
	until_turn(b, k)
	var ev: Array[Dictionary] = run_turn(b, k, Ai.choose, Rng.new(1))
	assert_eq(count_events(ev, "moved"), 0)
	assert_ne(b.current_unit(), k)

# ---- archetypes -------------------------------------------------------------

func test_brute_closes_in_and_attacks_the_nearest() -> void:
	var b := battle("fxa_pack", [mk("a"), mk("z")])
	b.start()
	var wolf: int = uid_of(b, "fx_wolf")
	until_turn(b, wolf)
	b.place(uid_of(b, "a"), Vector2i(3, 1))   # 3 steps from the wolf at (6,1)
	b.place(uid_of(b, "z"), Vector2i(1, 5))   # far away
	var ev: Array[Dictionary] = run_turn(b, wolf, Ai.choose, Rng.new(1))
	assert_eq(count_events(ev, "moved"), 1)
	var hits: Array[Dictionary] = uses_of(ev, "fx_strike")
	assert_true(hits.size() >= 1, str(ev))
	assert_eq(hits[0].cell, Vector2i(3, 1))

func test_brute_hits_the_taunter() -> void:
	var b := battle("fxa_pack", [mk("a"), mk("z")])
	b.start()
	var wolf: int = uid_of(b, "fx_wolf")
	until_turn(b, wolf)
	var a: int = uid_of(b, "a")
	var z: int = uid_of(b, "z")
	b.place(a, Vector2i(5, 1)); b.debug_set(a, "hp", 2)   # a tempting kill
	b.place(z, Vector2i(6, 2))
	b.debug_set(wolf, "statuses", {"taunted": {"turns": 2, "value": 0, "by": z}})
	var ev: Array[Dictionary] = run_turn(b, wolf, Ai.choose, Rng.new(1))
	var hits: Array[Dictionary] = uses_of(ev, "fx_strike")
	assert_true(hits.size() >= 1)
	for h in hits: assert_eq(h.cell, Vector2i(6, 2))

func test_skirmisher_retreats_from_melee_and_still_shoots() -> void:
	var b := battle("fxa_pack", [mk("k")])
	b.start()
	var sk: int = uid_of(b, "fxa_skirm")
	until_turn(b, sk)
	var k: int = uid_of(b, "k")
	b.place(k, Vector2i(6, 5))
	b.place(sk, Vector2i(7, 5))
	var ev: Array[Dictionary] = run_turn(b, sk, Ai.choose, Rng.new(1))
	var end_cell: Vector2i = b.unit(sk).cell
	var d: int = absi(end_cell.x - 6) + absi(end_cell.y - 5)
	assert_true(d > 1 and d <= 3, "ends at range, got %s" % end_cell)
	assert_true(uses_of(ev, "fxa_spit").size() >= 1, str(ev))

func test_skirmisher_shoots_from_cover() -> void:
	var b := battle("fxa_pack", [mk("k")])
	b.start()
	var sk: int = uid_of(b, "fxa_skirm")
	until_turn(b, sk)
	b.place(uid_of(b, "k"), Vector2i(1, 2))
	b.place(sk, Vector2i(6, 5))
	b.place(uid_of(b, "fx_wolf"), Vector2i(7, 1))
	b.place(uid_of(b, "fxc_brute"), Vector2i(7, 3))
	var ev: Array[Dictionary] = run_turn(b, sk, Ai.choose, Rng.new(1))
	var c: Vector2i = b.unit(sk).cell
	# The cell next to the skirmisher toward the knight must give cover (a crate).
	var dx: int = 1 - c.x
	var dy: int = 2 - c.y
	var step: Vector2i = Vector2i(signi(dx), 0) if absi(dx) >= absi(dy) else Vector2i(0, signi(dy))
	assert_true(b.grid.cover_at(c + step) > 0, "covered at %s" % c)
	assert_eq(uses_of(ev, "fxa_spit").size(), 1, str(ev))

func test_caster_hits_the_lowest_hp_hostile_in_range() -> void:
	var b := battle("fxa_coven", [mk("k"), mk("n", "fx_necro")])
	b.start()
	var sh: int = uid_of(b, "fxa_shaman")
	until_turn(b, sh)
	b.place(uid_of(b, "k"), Vector2i(4, 3))
	b.place(uid_of(b, "n"), Vector2i(5, 5))   # both within the hex's range 4
	b.debug_set(uid_of(b, "n"), "hp", 9)
	var ev: Array[Dictionary] = run_turn(b, sh, Ai.choose, Rng.new(1))
	var hex: Array[Dictionary] = uses_of(ev, "fxa_hex")
	assert_true(hex.size() >= 1, str(ev))
	assert_eq(hex[0].cell, Vector2i(5, 5))

func test_caster_heals_a_hurt_ally() -> void:
	var b := battle("fxa_coven", [mk("k")])
	b.start()
	var sh: int = uid_of(b, "fxa_shaman")
	until_turn(b, sh)
	var br: int = uid_of(b, "fxc_brute")
	b.place(br, Vector2i(7, 1))
	b.debug_set(br, "hp", 3)
	b.place(uid_of(b, "k"), Vector2i(4, 3))
	var ev: Array[Dictionary] = run_turn(b, sh, Ai.choose, Rng.new(1))
	var mend: Array[Dictionary] = uses_of(ev, "fxa_mend")
	assert_true(mend.size() >= 1, str(ev))
	assert_eq(mend[0].cell, Vector2i(7, 1))

func test_surgeon_places_hazards_on_turn_one() -> void:
	var b := battle("fxa_saucer", [mk("k"), mk("n", "fx_necro"), mk("t")])
	b.start()
	var boss: int = uid_of(b, "fxa_surgeon")
	until_turn(b, boss)
	assert_eq(b.round, 1)
	run_turn(b, boss, Ai.choose, Rng.new(1))
	var kinds: Dictionary = {}
	for h in b.hazards(): kinds[h.hazard] = true
	assert_has(kinds, "specimen_tank")
	assert_has(kinds, "gravity_zone")

func test_surgeon_pushes_into_a_gravity_zone() -> void:
	var b := battle("fxa_saucer", [mk("k")])
	b.start()
	var boss: int = uid_of(b, "fxa_surgeon")
	var k: int = uid_of(b, "k")
	until_turn(b, boss)
	b.apply({"type": "end_turn"})
	until_turn(b, boss)   # round 2: no more hazard placing
	assert_eq(b.round, 2)
	b.place(k, Vector2i(1, 1))
	b.apply({"type": "ability", "ability": &"fxc_gravity", "cell": Vector2i(3, 3)})
	b.debug_set(boss, "ap", 7)
	b.place(k, Vector2i(5, 3))
	var a: Dictionary = Ai.choose(b, boss, Rng.new(1))
	assert_eq(a, {"type": "ability", "ability": &"fxc_shove", "cell": Vector2i(5, 3)})

func test_surgeon_summons_a_probe_once_at_half_hp() -> void:
	var b := battle("fxa_saucer", [mk("k")])
	b.start()
	var boss: int = uid_of(b, "fxa_surgeon")
	until_turn(b, boss)
	b.apply({"type": "end_turn"})
	until_turn(b, boss)
	b.debug_set(boss, "hp", 20)
	var ev: Array[Dictionary] = run_turn(b, boss, Ai.choose, Rng.new(1))
	var sm: Array[Dictionary] = events_of(ev, "summoned")
	assert_eq(sm.size(), 1, str(ev))
	assert_eq(sm[0].def_id, "fxa_probe_drone")
	b.debug_set(sm[0].uid, "dead", true)   # the probe is gone; no second one
	until_turn(b, boss)
	ev = run_turn(b, boss, Ai.choose, Rng.new(1))
	assert_eq(count_events(ev, "summoned"), 0)

func test_summoned_party_unit_fights_for_the_party() -> void:
	var b := battle("fxa_saucer", [mk("k", "fx_knight", {}, ["fxc_reboot"])])
	b.start()
	var boss: int = uid_of(b, "fxa_surgeon")
	until_turn(b, boss)
	b.debug_set(boss, "hp", 20)
	run_turn(b, boss, Ai.choose, Rng.new(1))
	var probe: int = uid_of(b, "fxa_probe_drone")
	assert_true(probe > 0)
	b.debug_set(probe, "side", "party")   # as if reprogrammed
	b.debug_set(probe, "summoned", true)
	until_turn(b, probe)
	b.place(probe, Vector2i(3, 3))
	var ev: Array[Dictionary] = run_turn(b, probe, Ai.choose, Rng.new(1))
	for e in uses_of(ev, "fxa_spit"): assert_eq(b.unit_at(e.cell), boss)

# ---- party policies ---------------------------------------------------------

func test_good_policy_heals_an_ally_under_half() -> void:
	var b := battle("fxa_pack", [mk("k"), mk("n", "fx_necro", {}, ["fx_heal"])])
	b.start()
	var n: int = uid_of(b, "n")
	until_turn(b, n)
	b.debug_set(uid_of(b, "k"), "hp", 10)
	var a: Dictionary = Ai.policy_good(b, n, Rng.new(1))
	assert_eq(a, {"type": "ability", "ability": &"fx_heal", "cell": b.unit(uid_of(b, "k")).cell})

func test_good_policy_raises_a_corpse() -> void:
	var b := battle("fxa_pack", [mk("k", "fx_knight", {"agility": 20}), mk("n", "fx_necro", {}, ["fx_raise"])])
	b.start()
	var wolf: int = uid_of(b, "fx_wolf")
	var k: int = uid_of(b, "k")
	until_turn(b, k)
	b.place(wolf, Vector2i(2, 2))
	b.debug_set(wolf, "hp", 1)
	for i in 3:
		if not b.corpses().is_empty() or b.unit(k).ap < 3: break
		b.apply({"type": "ability", "ability": &"fx_strike", "cell": Vector2i(2, 2)})
	if b.corpses().is_empty(): return   # three misses in a row; nothing to test on this seed
	var n: int = uid_of(b, "n")
	until_turn(b, n)
	var a: Dictionary = Ai.policy_good(b, n, Rng.new(1))
	assert_eq(a.get("ability", ""), "fx_raise")

func test_good_policy_wards_when_an_ally_is_threatened() -> void:
	var b := battle("fxa_pack", [mk("k", "fx_knight", {}, ["fx_ward"]), mk("n", "fx_necro")])
	b.start()
	var k: int = uid_of(b, "k")
	until_turn(b, k)
	b.place(k, Vector2i(3, 3))
	b.place(uid_of(b, "n"), Vector2i(1, 3))
	b.place(uid_of(b, "fx_wolf"), Vector2i(1, 2))
	b.place(uid_of(b, "fxc_brute"), Vector2i(2, 3))
	var a: Dictionary = Ai.policy_good(b, k, Rng.new(1))
	assert_eq(a.get("ability", ""), "fx_ward")

func test_good_policy_never_flees() -> void:
	for s in 20:
		var b := battle("fxa_pack", [mk("k")], s)
		b.start()
		var k: int = uid_of(b, "k")
		until_turn(b, k)
		var r := Rng.new(s)
		for i in 10:
			if b.current_unit() != k: break
			var a: Dictionary = Ai.policy_good(b, k, r)
			assert_ne(a.type, "flee")
			b.apply(a)

func test_random_policy_acts_before_ending_and_ends_after_six() -> void:
	var b := battle("fxa_pack", [mk("k")])
	b.start()
	var k: int = uid_of(b, "k")
	until_turn(b, k)
	var r := Rng.new(5)
	var first: Dictionary = Ai.policy_random(b, k, r)
	assert_ne(first.type, "end_turn")
	assert_ne(first.type, "flee")
	var ev: Array[Dictionary] = run_turn(b, k, Ai.policy_random, r)
	assert_true(count_events(ev, "moved") + count_events(ev, "ability_used") <= Ai.RANDOM_ACTIONS_PER_TURN)

# ---- whole battles ----------------------------------------------------------

func test_ai_on_both_sides_always_terminates() -> void:
	for s in 40:
		var enc: String = FUZZ_ENCOUNTERS[s % FUZZ_ENCOUNTERS.size()]
		var b := Battle.new(StringName(enc), random_party(Rng.new(s)), Rng.new(s), defs)
		var res: Dictionary = play(b, Ai.policy_good, Rng.new(s + 1000))
		assert_true(res.over, "seed %d %s" % [s, enc])
		assert_true(res.rounds <= Battle.MAX_ROUNDS)
		assert_ne(res.outcome, "fled")

func test_same_seed_same_battle() -> void:
	var a: Dictionary = play(Battle.new(&"fxa_coven", class_party(), Rng.new(9), defs), Ai.policy_good, Rng.new(4))
	var b: Dictionary = play(Battle.new(&"fxa_coven", class_party(), Rng.new(9), defs), Ai.policy_good, Rng.new(4))
	assert_eq(a, b)

func test_good_policy_beats_random_by_a_clear_margin() -> void:
	var good: int = 0
	var rand: int = 0
	for s in 100:
		if play(Battle.new(&"fxa_pack", class_party(), Rng.new(s), defs), Ai.policy_good, Rng.new(s)).outcome == "win": good += 1
		if play(Battle.new(&"fxa_pack", class_party(), Rng.new(s), defs), Ai.policy_random, Rng.new(s)).outcome == "win": rand += 1
	assert_true(good >= 60, "good wins %d/100" % good)
	assert_true(good - rand >= 30, "good %d vs random %d" % [good, rand])
