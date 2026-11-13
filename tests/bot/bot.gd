## The bot (WP-31): plays Dacian Scrolls through the core only, no scenes. It mirrors what the
## views do with core results: the world map's travel loop (Travel.step, stop on abducted >
## encounter), the encounter panel (Encounters.options/choose), the location view's
## containers, triggers and dialogues (location.gd open_container/_fire_trigger/talk), and the
## combat view's turn loop and ending (combat.gd _run/_finish: Battle + Ai, then
## Encounters.apply_battle_result and Flow.after_battle, which are pure and called as they are).
## Party turns are played by Ai.policy_good, enemies and summons by Ai.choose.
##
## Every step checks the world-map invariants (HP >= 1, food >= 0, passable cell) and records
## any breach in `problems`. Uses whatever Defs it is given: the bot tests pass the real data/.
extends RefCounted

const TOWN: StringName = &"sarmizegetusa"
const CAVE: StringName = &"strigoi_cave"
const CRASH: StringName = &"crash_site"
const SAUCER: StringName = &"saucer_surgeon"
const BATTLE_GUARD: int = 6000
## Road cells where the UFO's loop crosses the fast road (x31..34, y16): the bot walks between
## them until the saucer takes it.
const LOITER: Array[Vector2i] = [Vector2i(30, 16), Vector2i(33, 16)]
## Quiet road cells south of the town, more than 5 cells from the UFO loop: page hunting.
const SOUTH_ROAD: Array[Vector2i] = [Vector2i(24, 18), Vector2i(24, 27)]

var state: GameState
var rng: Rng
var defs: Defs
## Knight variant: pick a non-combat option wherever one exists (never "fight" by choice).
var pacifist: bool = false
## Real saucer battles before the bot gives up and applies a synthetic win (see abduction()).
var max_saucer_attempts: int = 3
var problems: Array[String] = []
var log: Array[String] = []
var stats: Dictionary = {
	"steps": 0, "battles": 0, "won": 0, "lost": 0, "fled": 0, "encounters": 0,
	"options": {}, "abductions": 0, "saucer_attempts": 0, "saucer_won_in_battle": false,
	"saucer_forced": false, "saucer_results": [], "saucer_sim": {},
}
var event_counts: Dictionary = {}

func _init(s: GameState, r: Rng, d: Defs) -> void:
	state = s
	rng = r
	defs = d

# ---------------------------------------------------------------- bookkeeping

func note(line: String) -> void:
	log.append("d%d %02dh L%d g%d f%d p%d  %s" % [state.day, state.hour, hero().level, state.gold,
		state.food, state.pages.size(), line])

func hero() -> Character:
	return state.party[0]

func _count(ev: Array[Dictionary]) -> void:
	for e in ev:
		var t: String = str(e.get("type", ""))
		event_counts[t] = int(event_counts.get(t, 0)) + 1

## World-map invariants. Call whenever the party stands on the world map.
func check_invariants(where: String) -> void:
	for m in state.party:
		if m.hp < 1: problems.append("%s: %s has %d HP" % [where, m.id, m.hp])
		if m.hp > m.max_hp: problems.append("%s: %s has %d/%d HP" % [where, m.id, m.hp, m.max_hp])
	if state.food < 0: problems.append("%s: food %d" % [where, state.food])
	if state.gold < 0: problems.append("%s: gold %d" % [where, state.gold])
	if not Travel.passable(state.world_pos, defs): problems.append("%s: impassable %s" % [where, state.world_pos])
	if state.hour < 0 or state.hour > 23: problems.append("%s: hour %d" % [where, state.hour])

static func find(ev: Array[Dictionary], type: String) -> Dictionary:
	for e in ev:
		if str(e.get("type", "")) == type: return e
	return {}

## Total XP ever earned by a character (levels are cumulative 120 * L each).
static func total_xp(c: Character) -> int:
	var t: int = c.xp
	for l in range(1, c.level): t += Formulas.xp_to_next(l)
	return t

# ---------------------------------------------------------------- combat

## One battle to the end, like combat.gd's turn loop: party by Ai.policy_good, the rest by
## Ai.choose; an illegal or empty choice ends the turn; 60 actions in a row by one unit end it.
func run_battle(enc: StringName, party: Array[Character], inventory: Dictionary, r: Rng) -> Dictionary:
	var b := Battle.new(enc, party, r, defs)
	b.inventory = inventory.duplicate()
	b.start()
	var guard: int = 0
	var last: int = -1
	var same: int = 0
	while not b.is_over() and guard < BATTLE_GUARD:
		var uid: int = b.current_unit()
		if uid < 0: break
		same = same + 1 if uid == last else 0
		last = uid
		var a: Dictionary
		if same > 60: a = {"type": "end_turn"}
		elif b.is_ai(uid): a = Ai.choose(b, uid, r)
		else: a = Ai.policy_good(b, uid, r)
		var ev: Array[Dictionary] = b.apply(a)
		if ev.size() == 1 and str(ev[0].get("type", "")) == "illegal": b.apply({"type": "end_turn"})
		guard += 1
	if not b.is_over(): problems.append("battle %s did not end after %d actions" % [enc, guard])
	var res: Dictionary = b.result()
	res["rounds"] = b.round
	return res

## Fights `enc` with the real party and applies the result like combat.gd _finish.
## Returns Flow.after_battle's answer plus `result`.
func fight(enc: StringName) -> Dictionary:
	var res: Dictionary = run_battle(enc, state.party, state.inventory, rng)
	return finish_battle(enc, res)

func finish_battle(enc: StringName, res: Dictionary) -> Dictionary:
	stats.battles += 1
	var outcome: String = str(res.get("outcome", ""))
	match outcome:
		"win": stats.won += 1
		"fled": stats.fled += 1
		_: stats.lost += 1
	var ev: Array[Dictionary] = Encounters.apply_battle_result(enc, res, state, rng, defs)
	var after: Dictionary = Flow.after_battle(enc, res, state, rng, defs)
	ev.append_array(after.events)
	_count(ev)
	use_page_items()
	note("battle %s: %s (%s, %d rounds)%s" % [enc, outcome, res.get("reason", ""), int(res.get("rounds", 0)),
		(" -> wake " + str(after.wake)) if str(after.wake) != "" else ""])
	after["result"] = res
	# Woken on the temple floor: Vezina is a few steps away.
	if str(after.wake) == "temple": rest_in_town()
	return after

# ---------------------------------------------------------------- world map

## Walks to `target` one Travel.step at a time, re-pathing after every interruption (an
## encounter, an abduction, a wake-up elsewhere). False if it cannot get there.
func travel_to(target: Vector2i, max_steps: int = 600) -> bool:
	var steps: int = 0
	while state.world_pos != target and steps < max_steps:
		var path: Array[Vector2i] = Travel.path(state, target, defs)
		if path.is_empty():
			problems.append("no path from %s to %s" % [state.world_pos, target])
			return false
		for c in path:
			var ev: Array[Dictionary] = Travel.step(state, c, rng, defs)
			steps += 1
			stats.steps += 1
			_count(ev)
			if ev.is_empty():
				problems.append("step %s -> %s refused" % [state.world_pos, c])
				return false
			check_invariants("step to %s" % c)
			var abd: Dictionary = find(ev, "abducted")
			if not abd.is_empty():
				abduction(StringName(str(abd.get("ufo", ""))), StringName(str(abd.get("encounter", ""))))
				break
			var enc: Dictionary = find(ev, "encounter")
			if not enc.is_empty():
				encounter(StringName(str(enc.get("encounter", ""))))
				break
			eat_if_hungry()
	return state.world_pos == target

func travel_to_location(id: StringName) -> bool:
	return travel_to(Rules.to_cell(Rules.location(id, defs).get("cell", [])))

func at_location(id: StringName) -> bool:
	return state.world_pos == Rules.to_cell(Rules.location(id, defs).get("cell", []))

## The encounter panel: one option, then the battle if it asks for one.
func encounter(enc: StringName) -> void:
	stats.encounters += 1
	var opts: Array[Dictionary] = Encounters.options(enc, state, defs)
	var pick: String = choose_option(enc, opts)
	stats.options[pick] = int(stats.options.get(pick, 0)) + 1
	var ev: Array[Dictionary] = Encounters.choose(enc, pick, state, rng, defs)
	_count(ev)
	if ev.is_empty() and pick != "flee": problems.append("option %s of %s did nothing" % [pick, enc])
	use_page_items()
	var roll: Dictionary = find(ev, "roll")
	note("encounter %s: %s%s" % [enc, pick, "" if roll.is_empty() else (" (roll %s)" % ("pass" if roll.passed else "fail"))])
	var br: Dictionary = find(ev, "battle_requested")
	if not br.is_empty(): fight(StringName(str(br.get("encounter", enc))))
	check_invariants("after encounter %s" % enc)

## Which option the bot takes. Page encounters take the page option while the page is
## missing; otherwise the Necromancer fights and the pacifist Knight picks the non-combat
## option with the best chance (flee only when nothing else exists).
func choose_option(enc: StringName, opts: Array[Dictionary]) -> String:
	var ids: Array[String] = []
	var chance: Dictionary = {}
	for o in opts:
		ids.append(str(o.id))
		chance[str(o.id)] = int(o.chance)
	if enc == &"wandering_trader" and not state.pages.has(&"page_trader") and ids.has("trade"): return "trade"
	if enc == &"roman_deserters" and not state.pages.has(&"page_deserters"):
		if ids.has("bribe"): return "bribe"
		if ids.has("talk"): return "talk"
	if not pacifist: return "fight"
	var best: String = ""
	for id in ids:
		if id == "fight" or id == "flee": continue
		if best == "" or int(chance[id]) > int(chance[best]): best = id
	return best if best != "" else "flee"

## The saucer: Flow.begin_abduction, the battle, then apply + Flow.after_battle. After
## max_saucer_attempts real losses the bot records the failure and applies a synthetic win
## (the surgeon's guaranteed loot, party HP as it stood) so the rest of the route can be checked.
func abduction(ufo: StringName, enc: StringName) -> void:
	stats.abductions += 1
	_count(Flow.begin_abduction(state, rng, defs))
	note("abducted by %s" % ufo)
	stats.saucer_attempts += 1
	var res: Dictionary = run_battle(enc, state.party, state.inventory, rng)
	stats.saucer_results.append("%s/%s r%d" % [res.outcome, res.reason, int(res.get("rounds", 0))])
	if str(res.outcome) == "win":
		stats.saucer_won_in_battle = true
	elif stats.saucer_attempts >= max_saucer_attempts:
		stats.saucer_forced = true
		note("saucer lost %d times: applying a synthetic win (balance blocker)" % stats.saucer_attempts)
		res = forced_win(enc, res)
	finish_battle(enc, res)

## A win result for `enc` built from a real result: every enemy's guaranteed loot (chance 1.0),
## nobody left downed.
func forced_win(enc: StringName, real: Dictionary) -> Dictionary:
	var loot: Dictionary = {}
	for e in defs.get_def(&"encounter", enc).get("enemies", []):
		for l in defs.get_def(&"enemy", StringName(str(e.get("enemy", "")))).get("loot", []):
			if float(l.get("chance", 0.0)) >= 1.0:
				var id := StringName(str(l.get("item", "")))
				loot[id] = int(loot.get(id, 0)) + 1
	var hp: Dictionary = {}
	for k in real.get("party_hp", {}): hp[k] = maxi(1, int(real.party_hp[k]))
	var out: Dictionary = real.duplicate(true)
	out.outcome = "win"
	out.reason = "bot_forced"
	out.loot = loot
	out.downed = []
	out.party_hp = hp
	return out

## Win rate of the saucer battle for a copy of the current party and pack over n seeds.
func saucer_win_rate(n: int) -> Dictionary:
	var wins: int = 0
	var timeouts: int = 0
	for i in n:
		var party: Array[Character] = []
		for m in state.party:
			var c: Character = Character.from_dict(m.to_dict())
			c.hp = c.max_hp
			party.append(c)
		var res: Dictionary = run_battle(SAUCER, party, state.inventory, Rng.new(1000 + i))
		if str(res.outcome) == "win": wins += 1
		if str(res.reason) == "timeout": timeouts += 1
	return {"n": n, "wins": wins, "timeouts": timeouts, "level": hero().level,
		"pct": 100.0 * wins / maxf(1.0, float(n))}

## Walks between the loiter cells on the fast road until the saucer takes the party.
func loiter_for_abduction(max_legs: int = 40) -> bool:
	var start: int = stats.abductions
	for i in max_legs:
		travel_to(LOITER[i % LOITER.size()], 60)
		if stats.abductions > start: return true
	return false

# ---------------------------------------------------------------- pack

## Reads any page item in the pack whose page is still missing (PartyScreen.use_item).
func use_page_items() -> void:
	var ids: Array = state.inventory.keys()
	ids.sort()
	for item in ids:
		var fx: Array = defs.get_def(&"item", StringName(str(item))).get("use_effects", [])
		for f in fx:
			if f is Array and f.size() == 2 and str(f[0]) == "page" and not state.pages.has(StringName(str(f[1]))):
				_count(use_item(StringName(str(item))))
				break

## PartyScreen.use_item: use_effects, then take one.
func use_item(item: StringName) -> Array[Dictionary]:
	var fx: Array = defs.get_def(&"item", item).get("use_effects", [])
	var ev: Array[Dictionary] = Rules.run(fx, state, rng, defs)
	ev.append_array(Rules.run([["take_item", str(item), 1]], state, rng, defs))
	return ev

func eat_if_hungry() -> void:
	if state.food < state.party.size() and int(state.inventory.get(&"bread", 0)) > 0:
		_count(use_item(&"bread"))

# ---------------------------------------------------------------- locations

func _map_entity(map_id: StringName, id: String) -> Dictionary:
	for e in defs.get_def(&"map", map_id).get("entities", []):
		if str(e.get("id", "")) == id: return e
	problems.append("map %s has no entity %s" % [map_id, id])
	return {}

## location.gd open_container. Returns false when locked or already searched.
func open_container(map_id: StringName, id: String) -> bool:
	var e: Dictionary = _map_entity(map_id, id)
	var once: bool = bool(e.get("once", true))
	var flag: String = "opened_%s_%s" % [map_id, id]
	if once and bool(state.flags.get(flag, false)): return false
	if not Rules.check(e.get("if", []), state, defs): return false
	var fx: Array = []
	if once: fx.append(["set_flag", flag, true])
	fx.append_array(e.get("effects", []))
	_handle(Rules.run(fx, state, rng, defs))
	note("opened %s/%s" % [map_id, id])
	return true

## location.gd _fire_trigger (the party walks over it).
func fire_trigger(map_id: StringName, id: String) -> void:
	var e: Dictionary = _map_entity(map_id, id)
	var once: bool = bool(e.get("once", false))
	var flag: String = "triggered_%s_%s" % [map_id, id]
	if once and bool(state.flags.get(flag, false)): return
	if not Rules.check(e.get("if", []), state, defs): return
	var fx: Array = []
	if once: fx.append(["set_flag", flag, true])
	fx.append_array(e.get("effects", []))
	note("trigger %s/%s" % [map_id, id])
	_handle(Rules.run(fx, state, rng, defs))

func npc_visible(map_id: StringName, id: String) -> bool:
	return Rules.check(_map_entity(map_id, id).get("if", []), state, defs)

## A conversation, like DialogueBox + location.gd talk: each wanted choice (by text_key) is
## taken once when visible; otherwise the last visible choice (every dialogue ends its lists
## with the way out). A battle asked for during the talk starts when it closes.
func talk(dialogue: StringName, wanted: Array[String]) -> Array[Dictionary]:
	var left: Array[String] = wanted.duplicate()
	var all: Array[Dictionary] = []
	var d := DialogueRunner.new(dialogue, state, rng, defs)
	all.append_array(d.start())
	var guard: int = 0
	while not d.is_done() and guard < 50:
		guard += 1
		var cur: Dictionary = d.current()
		var choices: Array = cur.get("choices", [])
		if choices.is_empty():
			problems.append("dialogue %s dead-ends at %s" % [dialogue, cur.get("text_key", "")])
			break
		var pick: int = int(choices[-1].index)
		for c in choices:
			if left.has(str(c.text_key)):
				pick = int(c.index)
				left.erase(str(c.text_key))
				break
		all.append_array(d.choose(pick))
	if not d.is_done(): problems.append("dialogue %s did not end" % dialogue)
	note("talked to %s (%d events)" % [dialogue, all.size()])
	_handle(all)
	return all

## location.gd _handle: a requested battle starts (returning to the location).
func _handle(ev: Array[Dictionary]) -> void:
	_count(ev)
	use_page_items()
	var br: Dictionary = find(ev, "battle_requested")
	if not br.is_empty(): fight(StringName(str(br.get("encounter", ""))))

func party_hurt() -> bool:
	for m in state.party:
		if m.hp < m.max_hp or m.mana < m.max_mana or m.charge < m.max_charge: return true
	return false

## In town: free healing at Vezina, a meal at Zia's when food runs low and gold allows.
func rest_in_town(gold_reserve: int = 0) -> void:
	if party_hurt(): talk(&"vezina", ["dlg_vezina_hello_c0"] as Array[String])
	if state.food < 4 * state.party.size() and state.gold >= 12 + gold_reserve:
		talk(&"zia", ["dlg_zia_hello_c0"] as Array[String])
