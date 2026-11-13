## Review Focus 3 and determinism: seeded battles driven by random legal actions (WP-12).
## Ai is WP-20's; this file has its own tiny random driver.
extends "res://tests/unit/combat_case.gd"

const ENCOUNTERS: Array[String] = ["fx_wolves", "fx_saucer", "fxc_brawl", "fxc_lab", "fxc_pair", "fxc_floaty", "fxc_box"]

func random_party(r: Rng) -> Array[Character]:
	var out: Array[Character] = []
	var k := mk("k", "fx_knight", {"agility": r.randi_range(2, 6)}, ["fx_ward", "fx_zap", "fxc_shove", "fxc_stun"])
	k.gear = {"weapon": &"fx_sword", "armor": &"fxc_plate", "trinket": &""}
	out.append(k)
	if r.chance(0.7): out.append(mk("n", "fx_necro", {"agility": r.randi_range(2, 6)}, ["fx_raise", "fx_heal", "fxc_charm", "fxc_reboot"], 20))
	if r.chance(0.5): out.append(mk("t", "fx_knight", {"agility": 3}, ["fxc_bolt", "fxc_bleed", "fxc_slow", "fxc_acid"]))
	return out

## A uniformly random legal action, biased toward doing something so battles finish.
func pick(acts: Array[Dictionary], r: Rng, actions_this_turn: int) -> Dictionary:
	var doing: Array[Dictionary] = []
	var moves: Array[Dictionary] = []
	for a in acts:
		if a.type == "ability" or a.type == "item": doing.append(a)
		elif a.type == "move": moves.append(a)
	if actions_this_turn >= 6 or r.chance(0.1): return {"type": "end_turn"}
	if r.chance(0.01) and has_action(acts, {"type": "flee"}): return {"type": "flee"}
	if not doing.is_empty() and r.chance(0.7): return doing[r.randi_range(0, doing.size() - 1)]
	if not moves.is_empty(): return moves[r.randi_range(0, moves.size() - 1)]
	return {"type": "end_turn"}

## Plays one battle; returns {events, actions, errors}.
func play(seed: int, scripted: Array = []) -> Dictionary:
	var r := Rng.new(seed * 7919 + 1)
	var enc: String = ENCOUNTERS[seed % ENCOUNTERS.size()]
	var b := Battle.new(StringName(enc), random_party(r), Rng.new(seed), defs)
	b.inventory = {&"fxc_medkit": 2}
	var ev: Array[Dictionary] = b.start()
	var actions: Array = []
	var errors: Array[String] = []
	var per_turn: int = 0
	var last_uid: int = -1
	var i: int = 0
	while not b.is_over() and i < 5000:
		var uid: int = b.current_unit()
		if uid != last_uid: per_turn = 0; last_uid = uid
		var acts: Array[Dictionary] = b.legal_actions(uid)
		if not has_action(acts, {"type": "end_turn"}): errors.append("no end_turn for %d" % uid)
		var a: Dictionary = scripted[i] if i < scripted.size() else pick(acts, r, per_turn)
		var out: Array[Dictionary] = b.apply(a)
		if count_events(out, "illegal") > 0: errors.append("legal action refused: %s -> %s" % [a, out])
		ev.append_array(out)
		actions.append(a)
		per_turn += 1
		i += 1
	if not b.is_over(): errors.append("not over after 5000 actions (seed %d)" % seed)
	if b.round > 60: errors.append("ran past 60 rounds")
	if b.result().outcome == "": errors.append("no outcome")
	if b.turn_order().is_empty(): errors.append("empty order")
	return {"events": ev, "actions": actions, "errors": errors, "outcome": b.result().outcome, "reason": b.result().reason}

func test_two_hundred_random_battles_end_cleanly() -> void:
	var outcomes: Dictionary = {}
	var seen: Dictionary = {}
	for s in 200:
		var res: Dictionary = play(s)
		for e in res.errors: fail("seed %d: %s" % [s, e])
		var key: String = "%s/%s" % [res.outcome, res.reason]
		outcomes[key] = int(outcomes.get(key, 0)) + 1
		for e in res.events: seen[e.type] = true
		assert_eq(count_events(res.events, "battle_ended"), 1)
		assert_eq(res.events[-1].type, "battle_ended")
	assert_true(outcomes.size() >= 3, str(outcomes))
	for t in ["moved", "ability_used", "missed", "damaged", "healed", "status", "status_ended", "pushed",
			"died", "summoned", "hazard", "drifted", "timer", "fled"]:
		assert_has(seen, t, "the fuzz exercises %s" % t)

func test_same_seed_same_actions_same_events() -> void:
	for s in [3, 11, 42]:
		var a: Dictionary = play(s)
		var b: Dictionary = play(s, a.actions)
		assert_eq(b.events, a.events, "seed %d" % s)
		assert_true(a.events.size() > 5)
