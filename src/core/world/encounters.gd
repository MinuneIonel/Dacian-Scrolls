class_name Encounters
extends RefCounted

## Options that are always offered, whatever their `if` says.
const ALWAYS: Array[String] = ["fight", "flee"]

## Options the player may pick now: [{id, label_key, chance: int (percent, 100 without a roll)}].
## Never fewer than 2: "fight" and "flee" are always kept.
static func options(encounter_id: StringName, state: GameState, defs: Defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var enc: Dictionary = defs.get_def(&"encounter", encounter_id)
	for o in enc.get("options", []):
		if not _available(o, state, defs): continue
		out.append({"id": str(o.get("id", "")), "label_key": str(o.get("label_key", "")),
			"chance": _chance(o, state)})
	return out

## Runs the option's `pass` (or, when it has a roll, `pass`/`fail` after one d20 + best stat).
## Any option but flee that ends without a battle_requested event resolves the encounter and
## grants its xp. A hidden or unknown option returns [] and changes nothing.
static func choose(encounter_id: StringName, option_id: String, state: GameState, rng: Rng, defs: Defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var enc: Dictionary = defs.get_def(&"encounter", encounter_id)
	var opt: Dictionary = {}
	for o in enc.get("options", []):
		if o is Dictionary and str(o.get("id", "")) == option_id: opt = o
	if opt.is_empty() or not _available(opt, state, defs): return out
	var passed: bool = true
	var roll: Variant = opt.get("roll")
	if roll is Dictionary:
		var stat: String = str(roll.get("stat", ""))
		var dc: int = int(roll.get("dc", 0))
		var total: int = rng.roll(20) + Rules.best_stat(state, stat)
		passed = total >= dc
		out.append({"type": "roll", "stat": stat, "dc": dc, "total": total, "passed": passed})
	var branch: Variant = opt.get("pass", []) if passed else opt.get("fail", [])
	if branch is Array: out.append_array(Rules.run(branch, state, rng, defs))
	if option_id != "flee" and _find(out, "battle_requested").is_empty():
		out.append_array(Rules.grant_xp(state, int(enc.get("xp", 0)), defs))
	return out

## Applies a finished Battle.result(): items used up (result.items_used, any outcome), party
## HP/mana/charge, loot, and on a win flag won_<encounter_id> = true plus the encounter XP.
## On a win (and a successful flee) downed members return at 1 HP. On a win the UFO with this
## encounter on the party's cell is gone; on any other outcome it goes back to patrol and
## flags["ufo_grace"] = Ufo.GRACE_STEPS, so it cannot spot the party again at once.
static func apply_battle_result(encounter_id: StringName, result: Dictionary, state: GameState, rng: Rng, defs: Defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var outcome: String = str(result.get("outcome", ""))
	var won: bool = outcome == "win"
	var used: Variant = result.get("items_used", {})
	if used is Dictionary:
		var used_ids: Array = (used as Dictionary).keys()
		used_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for item in used_ids:
			if int(used[item]) > 0:
				out.append_array(Rules.run([["take_item", str(item), int(used[item])]], state, rng, defs))
	var hp: Dictionary = result.get("party_hp", {})
	var mana: Dictionary = result.get("party_mana", {})
	var charge: Dictionary = result.get("party_charge", {})
	for m in state.party:
		m.hp = clampi(int(_lookup(hp, m.id, m.hp)), 0, m.max_hp)
		m.mana = clampi(int(_lookup(mana, m.id, m.mana)), 0, m.max_mana)
		m.charge = clampi(int(_lookup(charge, m.id, m.charge)), 0, m.max_charge)
		if (won or outcome == "fled") and m.hp <= 0: m.hp = 1
	if won:
		var loot: Dictionary = result.get("loot", {})
		var ids: Array = loot.keys()
		ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for item in ids:
			if int(loot[item]) > 0:
				out.append_array(Rules.run([["give_item", str(item), int(loot[item])]], state, rng, defs))
	for u in state.ufos:
		if str(u.get("state", "")) == "gone" or Rules.to_cell(u.get("pos")) != state.world_pos: continue
		if Ufo.def_of(u, defs).get("encounter", "") != str(encounter_id): continue
		u["state"] = "gone" if won else "patrol"
		out.append({"type": "ufo_moved", "id": u.get("id", &""), "pos": u.pos, "state": u.state})
		if not won:
			out.append_array(Rules.run([["set_flag", Ufo.GRACE_FLAG, Ufo.GRACE_STEPS]], state, rng, defs))
	if won:
		out.append_array(Rules.run([["set_flag", "won_" + str(encounter_id), true]], state, rng, defs))
		out.append_array(Rules.grant_xp(state, int(defs.get_def(&"encounter", encounter_id).get("xp", 0)), defs))
	return out

static func _available(o: Variant, state: GameState, defs: Defs) -> bool:
	if not (o is Dictionary): return false
	if ALWAYS.has(str(o.get("id", ""))): return true
	var conds: Variant = o.get("if", [])
	return Rules.check(conds if conds is Array else [], state, defs)

static func _chance(o: Dictionary, state: GameState) -> int:
	var roll: Variant = o.get("roll")
	if not (roll is Dictionary): return 100
	return Rules.roll_chance(int(roll.get("dc", 0)), Rules.best_stat(state, str(roll.get("stat", ""))))

## A dictionary keyed by StringName or String.
static func _lookup(d: Dictionary, id: StringName, fallback: Variant) -> Variant:
	if d.has(id): return d[id]
	if d.has(str(id)): return d[str(id)]
	return fallback

static func _find(events: Array[Dictionary], type: String) -> Dictionary:
	for e in events:
		if e.get("type", "") == type: return e
	return {}
