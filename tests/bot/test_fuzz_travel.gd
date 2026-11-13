## 500 random journeys on the real world map: random targets, random encounter options,
## battles resolved by random results (every 25th by a real Ai battle), abductions included.
## After every step and every resolution the state must stay valid: HP >= 1, food >= 0, the
## party on a passable cell; and every journey's state must survive a save round trip.
extends TestCase

const Bot := preload("res://tests/bot/bot.gd")
const JOURNEYS: int = 500
const PER_GAME: int = 10
const MAX_STEPS: int = 40

var defs: Defs
var battles: int = 0
var real_battles: int = 0
var counts: Dictionary = {}

func before_all() -> void:
	defs = Content.defs

func after_all() -> void:
	Game.state = GameState.new()
	Game.rng = Rng.new(0)

func test_500_random_journeys_keep_the_state_valid() -> void:
	var t0: int = Time.get_ticks_msec()
	var fz := Rng.new(31)
	var bot
	var problems: Array[String] = []
	var passable: Array[Vector2i] = []
	var size: Vector2i = Travel.world_size(defs)
	for y in size.y:
		for x in size.x:
			if Travel.passable(Vector2i(x, y), defs): passable.append(Vector2i(x, y))
	for j in JOURNEYS:
		if j % PER_GAME == 0:
			Game.new_game(5000 + j, &"knight" if fz.chance(0.5) else &"necromancer")
			bot = Bot.new(Game.state, Game.rng, defs)
			if fz.chance(0.6): Rules.run([["recruit", "vezina"]], bot.state, bot.rng, defs)
			bot.state.food = fz.randi_range(0, 12)
			bot.state.gold = fz.randi_range(0, 80)
			bot.state.hour = fz.randi_range(0, 23)
			if fz.chance(0.3): bot.state.inventory[&"bread"] = fz.randi_range(1, 3)
			if fz.chance(0.2): bot.state.flags["strigoi_ally"] = true
			if fz.chance(0.2): bot.state.flags["decoy_charm"] = true
		_journey(bot, passable[fz.randi_range(0, passable.size() - 1)], fz)
		var round_trip: Dictionary = SaveCodec.decode(SaveCodec.encode(bot.state))
		if not round_trip.ok: problems.append("journey %d: save round trip failed: %s" % [j, round_trip.get("error_key", "")])
		for p in bot.problems: problems.append("journey %d: %s" % [j, p])
		bot.problems.clear()
		if problems.size() > 20: break
	print("    fuzz_travel: %d journeys, %d battles (%d real), events %s, %d ms" % [JOURNEYS, battles,
		real_battles, JSON.stringify(counts), Time.get_ticks_msec() - t0])
	assert_eq(problems, [] as Array[String])

func _journey(bot, target: Vector2i, fz: Rng) -> void:
	var path: Array[Vector2i] = Travel.path(bot.state, target, defs)
	var n: int = 0
	for c in path:
		if n >= MAX_STEPS: break
		n += 1
		var ev: Array[Dictionary] = Travel.step(bot.state, c, bot.rng, defs)
		if ev.is_empty():
			bot.problems.append("step %s -> %s refused" % [bot.state.world_pos, c])
			return
		_tally(ev)
		bot.check_invariants("step %s" % c)
		var abd: Dictionary = Bot.find(ev, "abducted")
		var enc: Dictionary = Bot.find(ev, "encounter")
		if not abd.is_empty():
			Flow.begin_abduction(bot.state, bot.rng, defs)
			_battle(bot, StringName(str(abd.encounter)), fz)
			return
		if not enc.is_empty():
			var id := StringName(str(enc.encounter))
			var opts: Array[Dictionary] = Encounters.options(id, bot.state, defs)
			var ids: Array = opts.map(func(o: Dictionary) -> String: return str(o.id))
			if not (ids.has("fight") and ids.has("flee")): bot.problems.append("%s lost fight/flee" % id)
			var pick: String = str(opts[fz.randi_range(0, opts.size() - 1)].id)
			var out: Array[Dictionary] = Encounters.choose(id, pick, bot.state, bot.rng, defs)
			_tally(out)
			var br: Dictionary = Bot.find(out, "battle_requested")
			if not br.is_empty(): _battle(bot, StringName(str(br.encounter)), fz)
			bot.check_invariants("after %s/%s" % [id, pick])
			return

## A finished battle: every 25th a real one (Ai both sides), otherwise a random result
## shaped like Battle.result(). Applied like the combat view: apply_battle_result + Flow.
func _battle(bot, enc: StringName, fz: Rng) -> void:
	battles += 1
	var res: Dictionary
	if battles % 25 == 0:
		real_battles += 1
		res = bot.run_battle(enc, bot.state.party, bot.state.inventory, bot.rng)
	else:
		var outcome: String = ["win", "lose", "fled"][fz.randi_range(0, 2)]
		var hp: Dictionary = {}
		var downed: Array[StringName] = []
		for m in bot.state.party:
			var h: int = 0 if fz.chance(0.3) else fz.randi_range(1, m.max_hp)
			if outcome == "lose": h = 0
			if h == 0: downed.append(m.id)
			hp[m.id] = 1 if (h == 0 and outcome == "win") else h
		var used: Dictionary = {}
		for item in bot.state.inventory:
			if fz.chance(0.5): used[item] = fz.randi_range(1, int(bot.state.inventory[item]) + 1)
		res = {"outcome": outcome, "reason": outcome, "loot": {&"healing_herbs": 1} if outcome == "win" else {},
			"downed": downed, "party_hp": hp, "party_mana": {}, "party_charge": {}, "items_used": used}
	var ev: Array[Dictionary] = Encounters.apply_battle_result(enc, res, bot.state, bot.rng, defs)
	var after: Dictionary = Flow.after_battle(enc, res, bot.state, bot.rng, defs)
	ev.append_array(after.events)
	_tally(ev)
	_tally([{"type": "outcome_" + str(res.outcome)}] as Array[Dictionary])
	bot.check_invariants("after battle %s (%s)" % [enc, res.outcome])

func _tally(ev: Array[Dictionary]) -> void:
	for e in ev:
		var t: String = str(e.get("type", ""))
		if t in ["encounter", "abducted", "starved", "defeat", "discovered", "arrived"] or t.begins_with("outcome_"):
			counts[t] = int(counts.get(t, 0)) + 1
