## One tactical battle. Drive it with apply(action); read back events. No scene tree.
## Unit dictionaries: {uid: int, side: "party"|"enemy", def_id: StringName, char_id: StringName,
##   cell: Vector2i, size: int, hp: int, max_hp: int, ap: int, mana: int, charge: int,
##   armor: int, stats: Dictionary, abilities: Array[StringName], statuses: Dictionary, summoned: bool}
## Extra unit keys: max_mana, max_charge, weapon_damage, downed (party at 0 HP), summoner (uid or -1),
##   raiseable, machine, gib, ai. statuses: {name: {turns, value, by}} (by = taunter uid for "taunted").
## Rules live in docs/CONTRACTS.md section 8.
class_name Battle
extends RefCounted

const MAX_ROUNDS: int = 60
const HARMFUL_STATUSES: Array[String] = ["slowed", "stunned", "bleeding", "chilled", "charmed"]
const CLEANSED: Array[String] = ["slowed", "stunned", "bleeding", "chilled", "charmed", "taunted"]
const STATUS_DEFAULT_VALUE: Dictionary = {"bleeding": 2, "regen": 2, "chilled": 2}
const HOSTILE_KINDS: Array[String] = ["damage", "taunt", "push"]
const ACID_DAMAGE: int = 3
const TANK_COVER: int = 20
const DRIFT_CHANCE: float = 0.25

var encounter_id: StringName
var round: int = 0
var rules: Dictionary = {"magic_disabled": false, "gravity": "normal", "turn_limit": 0}
var grid: Grid
## Consumables the party may use with {type: "item"}: item_id -> count. Set it before start();
## uses are taken from it and reported in result().items_used.
var inventory: Dictionary = {}

var _defs: Defs
var _rng: Rng
var _units: Array[Dictionary] = []     # every unit ever created, by uid order (uid = index + 1)
var _order: Array[int] = []            # initiative order of uids (dead ones are skipped)
var _turn_i: int = -1
var _current: int = -1
var _started: bool = false
var _over: bool = false
var _outcome: String = ""
var _reason: String = ""
var _loot: Dictionary = {}
var _items_used: Dictionary = {}
var _corpses: Array[Dictionary] = []   # {cell, def_id, raiseable, machine}
var _hazards: Array[Dictionary] = []   # {cell, hazard, turns}

func _init(enc_id: StringName, party: Array[Character], rng: Rng, defs: Defs) -> void:
	encounter_id = enc_id
	_defs = defs
	_rng = rng
	var enc: Dictionary = defs.get_def(&"encounter", enc_id) if defs.has(&"encounter", enc_id) else {}
	if enc.is_empty(): push_error("Battle: unknown encounter '%s'" % enc_id)
	var r: Dictionary = enc.get("rules", {})
	for k in r: rules[k] = r[k]
	var map_id: StringName = StringName(str(enc.get("map", "")))
	var map_def: Dictionary = defs.get_def(&"map", map_id) if defs.has(&"map", map_id) else {}
	var tiles: Variant = defs.json("tiles")
	grid = Grid.from_map(map_def, tiles if tiles is Dictionary else {})
	var spawns: Array = enc.get("party_spawn", [])
	var si: int = 0
	for ch in party:
		if ch == null or ch.hp <= 0: continue
		if si >= spawns.size(): break
		_add_party_unit(ch, _to_cell(spawns[si]))
		si += 1
	for e in enc.get("enemies", []):
		var eid: StringName = StringName(str(e.get("enemy", "")))
		if not defs.has(&"enemy", eid):
			push_error("Battle: unknown enemy '%s'" % eid)
			continue
		_add_enemy_unit(defs.get_def(&"enemy", eid), _to_cell(e.get("cell", [0, 0])), "enemy", false, -1)

# ---- public API -------------------------------------------------------------

func units() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in _units:
		if not u.dead: out.append(u.duplicate(true))
	return out

func unit(uid: int) -> Dictionary:
	var u: Dictionary = _u(uid)
	return u.duplicate(true) if not u.is_empty() else {}

## uid of the unit whose turn it is.
func current_unit() -> int:
	return _current if _started and not _over else -1

## True for units the AI drives: every enemy, and summoned party units.
## A charmed unit is AI-driven too (for the side that charmed it).
func is_ai(uid: int) -> bool:
	var u: Dictionary = _u(uid)
	if u.is_empty(): return false
	return u.side == "enemy" or u.summoned or u.statuses.has("charmed")

## Every legal action for that unit. Always contains {type: "end_turn"} while the battle runs.
## Only the current unit can act: any other uid (or a finished battle) gives [].
func legal_actions(uid: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _started or _over or uid != _current: return out
	var u: Dictionary = _u(uid)
	out.append({"type": "end_turn"})
	if _can_flee(u): out.append({"type": "flee"})
	var srch: Dictionary = _move_search(u)
	var cells: Array = srch.cost.keys()
	for c in cells:
		if c == u.cell: continue
		out.append({"type": "move", "path": Grid.path_from(srch.parent, u.cell, c)})
	for ab_id in u.abilities:
		var ab: Dictionary = _ability(ab_id)
		if ab.is_empty() or _cost_error(u, ab, true) != "": continue
		for c in _candidate_cells(u, ab):
			out.append({"type": "ability", "ability": ab_id, "cell": c})
	if _can_use_items(u):
		var ids: Array = inventory.keys()
		ids.sort()
		for item_id in ids:
			var ab: Dictionary = _item_ability(StringName(str(item_id)))
			if ab.is_empty() or _cost_error(u, ab, false) != "": continue
			for c in _candidate_cells(u, ab):
				out.append({"type": "item", "item": StringName(str(item_id)), "cell": c})
	return out

## Applies an action for the current unit. Illegal actions change nothing and return
## [{type: "illegal", reason: String}].
func apply(action: Dictionary) -> Array[Dictionary]:
	var err: String = _validate(action)
	if err != "": return [{"type": "illegal", "reason": err}]
	var ev: Array[Dictionary] = []
	var u: Dictionary = _u(_current)
	match str(action.get("type", "")):
		"end_turn":
			_end_turn(u, ev)
		"flee":
			var total: int = _rng.roll(20) + int(u.stats.get("agility", 0))
			var ok: bool = total >= 10 + _living_enemies()
			ev.append({"type": "fled", "success": ok})
			if ok: _finish("fled", "fled", ev)
			else: _end_turn(u, ev)
		"move":
			_do_move(u, _to_path(action.get("path", [])), ev)
		"ability":
			var ab_id := StringName(str(action.get("ability", "")))
			var ab: Dictionary = _ability(ab_id)
			_pay(u, ab, true)
			_use(u, ab_id, ab, _to_cell(action.get("cell")), ev, &"")
		"item":
			var item_id := StringName(str(action.get("item", "")))
			var ab: Dictionary = _item_ability(item_id)
			_pay(u, ab, false)
			inventory[item_id] = int(inventory[item_id]) - 1
			if inventory[item_id] <= 0: inventory.erase(item_id)
			_items_used[item_id] = int(_items_used.get(item_id, 0)) + 1
			_use(u, StringName(str(ab.id)), ab, _to_cell(action.get("cell")), ev, item_id)
	return ev

## Events produced by starting the battle (initiative, first turn_started).
func start() -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if _started: return [{"type": "illegal", "reason": "already_started"}]
	_started = true
	var rolls: Array = []
	for i in _units.size():
		var u: Dictionary = _units[i]
		rolls.append([Formulas.initiative(int(u.stats.get("agility", 0)), _rng), 0 if u.side == "party" else 1, i])
	rolls.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]: return a[0] > b[0]
		if a[1] != b[1]: return a[1] < b[1]
		return a[2] < b[2])
	for r in rolls: _order.append(_units[r[2]].uid)
	round = 1
	ev.append({"type": "battle_started", "round": round})
	if int(rules.turn_limit) > 0: ev.append({"type": "timer", "turns_left": int(rules.turn_limit)})
	_check_end(ev)
	_turn_i = -1
	_next_turn(ev)
	return ev

func is_over() -> bool:
	return _over

## {outcome: "win"|"lose"|"fled", reason: String, loot: {item_id: n}, downed: [char_id],
##  party_hp: {char_id: hp}, party_mana: {char_id: n}, party_charge: {char_id: n}}. See CONTRACTS section 8.
## Also items_used: {item_id: n}. outcome is "" while the battle runs.
func result() -> Dictionary:
	var downed: Array[StringName] = []
	var hp: Dictionary = {}
	var mana: Dictionary = {}
	var charge: Dictionary = {}
	for u in _units:
		if u.side != "party" or u.summoned or u.char_id == &"": continue
		if u.downed: downed.append(u.char_id)
		hp[u.char_id] = 1 if (u.downed and _outcome == "win") else u.hp
		mana[u.char_id] = u.mana
		charge[u.char_id] = u.charge
	return {"outcome": _outcome, "reason": _reason,
		"loot": _loot.duplicate() if _outcome == "win" else {}, "downed": downed,
		"party_hp": hp, "party_mana": mana, "party_charge": charge, "items_used": _items_used.duplicate()}

## [{cell: Vector2i, def_id: StringName, raiseable: bool}] (plus machine: bool)
func corpses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in _corpses: out.append(c.duplicate())
	return out

## Active hazards: [{cell, hazard, turns}].
func hazards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h in _hazards: out.append(h.duplicate())
	return out

## Initiative order (uids of units still in the battle).
func turn_order() -> Array[int]:
	var out: Array[int] = []
	for id in _order:
		if not _u(id).dead: out.append(id)
	return out

## Hit chance in percent for att_uid's ability against tgt_uid (cover and flank included).
func hit_chance(att_uid: int, tgt_uid: int, ability_id: StringName) -> int:
	var a: Dictionary = _u(att_uid)
	var t: Dictionary = _u(tgt_uid)
	if a.is_empty() or t.is_empty(): return 0
	return _hit_chance(a, t, _ability(ability_id))

## True when the two units fight on the same side right now (charm flips a side).
func are_allies(a_uid: int, b_uid: int) -> bool:
	var a: Dictionary = _u(a_uid)
	var b: Dictionary = _u(b_uid)
	return not a.is_empty() and not b.is_empty() and _side(a) == _side(b)

## The active unit standing on cell, or -1.
func unit_at(cell: Vector2i) -> int:
	var u: Dictionary = _unit_at(cell)
	return u.uid if not u.is_empty() else -1

## The ability definition, or {} when unknown. Shared with Defs: read it, never modify it.
func ability_def(id: StringName) -> Dictionary:
	return _ability(id)

## The ability a consumable uses, or {} when it is not usable right now (none left in the
## inventory, not a consumable, no use_ability). Read it, never modify it.
func item_ability(item_id: StringName) -> Dictionary:
	return _item_ability(item_id)

## Moves a unit without rules or events. For tests and scripted setups only.
func place(uid: int, cell: Vector2i) -> void:
	var u: Dictionary = _u(uid)
	if not u.is_empty(): u.cell = cell

## Sets a unit's field without rules or events (e.g. hp, ap, statuses). For tests only.
func debug_set(uid: int, key: String, value: Variant) -> void:
	var u: Dictionary = _u(uid)
	if not u.is_empty(): u[key] = value

# ---- unit creation ----------------------------------------------------------

func _new_unit() -> Dictionary:
	return {"uid": _units.size() + 1, "side": "party", "def_id": &"", "char_id": &"",
		"cell": Vector2i.ZERO, "size": 1, "hp": 1, "max_hp": 1, "ap": 0,
		"mana": 0, "max_mana": 0, "charge": 0, "max_charge": 0, "armor": 0, "weapon_damage": 0,
		"stats": {"might": 0, "agility": 0, "wits": 0, "spirit": 0},
		"abilities": [] as Array[StringName], "statuses": {}, "summoned": false, "summoner": -1,
		"downed": false, "dead": false, "raiseable": false, "machine": false, "gib": false,
		"ai": "", "loot": []}

func _add_party_unit(ch: Character, cell: Vector2i) -> void:
	var u: Dictionary = _new_unit()
	u.char_id = ch.id
	u.def_id = ch.class_id
	u.cell = cell
	u.hp = ch.hp
	u.max_hp = ch.max_hp
	u.max_mana = ch.max_mana
	u.mana = ch.max_mana   # mana refills at battle start
	u.max_charge = ch.max_charge
	u.charge = ch.charge   # charge does not
	u.stats = ch.stats.duplicate()
	for slot in ch.gear:
		var item_id: StringName = StringName(str(ch.gear[slot]))
		if item_id == &"" or not _defs.has(&"item", item_id): continue
		var mods: Dictionary = _defs.get_def(&"item", item_id).get("mods", {})
		for k in mods:
			if k == "damage": u.weapon_damage += int(mods[k])
			elif k == "armor": u.armor += int(mods[k])
			elif u.stats.has(k): u.stats[k] = int(u.stats[k]) + int(mods[k])
	var ab_list: Array[StringName] = []
	if _defs.has(&"class", ch.class_id):
		var basic: StringName = StringName(str(_defs.get_def(&"class", ch.class_id).get("basic_attack", "")))
		if basic != &"": ab_list.append(basic)
	var n: int = 0
	for a in ch.equipped:
		if n >= Character.MAX_EQUIPPED: break
		n += 1
		if not ab_list.has(a): ab_list.append(a)
	u.abilities = ab_list
	_units.append(u)

func _add_enemy_unit(def: Dictionary, cell: Vector2i, side: String, summoned: bool, summoner: int) -> Dictionary:
	var u: Dictionary = _new_unit()
	u.side = side
	u.def_id = StringName(str(def.get("id", "")))
	u.cell = cell
	u.size = int(def.get("size", 1))
	u.max_hp = int(def.get("hp", 1))
	u.hp = u.max_hp
	u.armor = int(def.get("armor", 0))
	var st: Dictionary = def.get("stats", {})
	for k in u.stats: u.stats[k] = int(st.get(k, 0))
	var ab_list: Array[StringName] = []
	for a in def.get("abilities", []): ab_list.append(StringName(str(a)))
	u.abilities = ab_list
	u.raiseable = bool(def.get("raiseable", false))
	u.machine = bool(def.get("machine", false))
	u.gib = bool(def.get("gib", false))
	u.ai = str(def.get("ai", "brute"))
	u.loot = def.get("loot", [])
	u.summoned = summoned
	u.summoner = summoner
	_units.append(u)
	return u

# ---- helpers ----------------------------------------------------------------

func _u(uid: int) -> Dictionary:
	return _units[uid - 1] if uid >= 1 and uid <= _units.size() else {}

func _active(u: Dictionary) -> bool:
	return not u.dead and not u.downed

## Effective side: charm flips it.
func _side(u: Dictionary) -> String:
	if u.statuses.has("charmed"): return "enemy" if u.side == "party" else "party"
	return u.side

func _cells_of(u: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in u.size:
		for dx in u.size:
			out.append(u.cell + Vector2i(dx, dy))
	return out

static func _dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _dist_cell_unit(c: Vector2i, u: Dictionary) -> int:
	var best: int = 1 << 30
	for p in _cells_of(u): best = mini(best, _dist(c, p))
	return best

func _unit_at(c: Vector2i) -> Dictionary:
	for u in _units:
		if _active(u) and c.x >= u.cell.x and c.y >= u.cell.y and c.x < u.cell.x + u.size and c.y < u.cell.y + u.size:
			return u
	return {}

func _has_hazard(c: Vector2i, kind: String) -> bool:
	for h in _hazards:
		if h.cell == c and h.hazard == kind: return true
	return false

func _cover_at(c: Vector2i) -> int:
	return maxi(grid.cover_at(c), TANK_COVER if _has_hazard(c, "specimen_tank") else 0)

## Cells a unit (except `except_uid`) cannot enter: other active units and specimen tanks.
func _occupied(except_uid: int) -> Dictionary:
	var occ: Dictionary = {}
	for u in _units:
		if u.uid == except_uid or not _active(u): continue
		for p in _cells_of(u): occ[p] = true
	for h in _hazards:
		if h.hazard == "specimen_tank": occ[h.cell] = true
	return occ

func _floaty_at(u: Dictionary) -> bool:
	if rules.gravity == "floaty": return true
	for p in _cells_of(u):
		if _has_hazard(p, "gravity_zone"): return true
	return false

func _step_base(u: Dictionary) -> int:
	return (2 if rules.gravity == "floaty" else 1) + (1 if u.statuses.has("slowed") else 0)

## Extra cost for stepping onto gravity_zone cells when the battle's gravity is normal.
func _step_extra() -> Dictionary:
	var extra: Dictionary = {}
	if rules.gravity != "floaty":
		for h in _hazards:
			if h.hazard == "gravity_zone": extra[h.cell] = 1
	return extra

func _move_search(u: Dictionary) -> Dictionary:
	if u.ap <= 0: return {"cost": {u.cell: 0}, "parent": {}}
	return grid.search(u.cell, u.ap, u.size, _occupied(u.uid), _step_base(u), _step_extra())

func _ability(id: StringName) -> Dictionary:
	return _defs.get_def(&"ability", id) if _defs.has(&"ability", id) else {}

func _item_ability(item_id: StringName) -> Dictionary:
	if int(inventory.get(item_id, 0)) <= 0 or not _defs.has(&"item", item_id): return {}
	var it: Dictionary = _defs.get_def(&"item", item_id)
	if str(it.get("kind", "")) != "consumable" or not it.has("use_ability"): return {}
	return _ability(StringName(str(it.use_ability)))

func _can_flee(u: Dictionary) -> bool:
	return u.side == "party" and not u.summoned and not u.statuses.has("charmed") and int(rules.turn_limit) == 0

func _can_use_items(u: Dictionary) -> bool:
	return u.side == "party" and not u.summoned and u.char_id != &"" and not u.statuses.has("charmed")

func _pays_costs(u: Dictionary) -> bool:
	return u.char_id != &""

## "" when the unit can afford the ability (pay_resource: mana/charge too).
func _cost_error(u: Dictionary, ab: Dictionary, pay_resource: bool) -> String:
	if str(ab.get("source", "")) == "magic" and bool(rules.magic_disabled): return "magic_disabled"
	if u.ap < int(ab.get("ap", 0)): return "not_enough_ap"
	if pay_resource and _pays_costs(u):
		var cost: int = int(ab.get("cost", 0))
		if str(ab.source) == "magic" and u.mana < cost: return "not_enough_mana"
		if str(ab.source) == "tech" and u.charge < cost: return "not_enough_charge"
	return ""

func _pay(u: Dictionary, ab: Dictionary, pay_resource: bool) -> void:
	u.ap -= int(ab.get("ap", 0))
	if pay_resource and _pays_costs(u):
		if str(ab.source) == "magic": u.mana -= int(ab.get("cost", 0))
		elif str(ab.source) == "tech": u.charge -= int(ab.get("cost", 0))

func _has_hostile_effect(ab: Dictionary) -> bool:
	for e in ab.get("effects", []):
		var k: String = str(e.get("kind", ""))
		if k in HOSTILE_KINDS: return true
		if k == "status" and str(e.get("status", "")) in HARMFUL_STATUSES: return true
	return false

func _summon_effect(ab: Dictionary) -> Dictionary:
	for e in ab.get("effects", []):
		if str(e.get("kind", "")) == "summon": return e
	return {}

func _corpse_at(c: Vector2i) -> Dictionary:
	for k in _corpses:
		if k.cell == c: return k
	return {}

func _range_from(u: Dictionary, c: Vector2i) -> int:
	return _dist_cell_unit(c, u)

## The live taunter of a taunted unit, or {}.
func _taunter(u: Dictionary) -> Dictionary:
	if not u.statuses.has("taunted"): return {}
	var t: Dictionary = _u(int(u.statuses.taunted.get("by", -1)))
	return t if not t.is_empty() and _active(t) else {}

## "" when caster u may use ability ab on cell c (costs are checked separately).
func _target_error(u: Dictionary, ab: Dictionary, c: Vector2i) -> String:
	if not grid.in_bounds(c): return "out_of_bounds"
	var target: String = str(ab.get("target", "enemy"))
	if target == "self":
		if c != u.cell: return "not_self"
	elif _range_from(u, c) > int(ab.get("range", 0)):
		return "out_of_range"
	var at: Dictionary = _unit_at(c)
	match target:
		"enemy":
			if at.is_empty() or _side(at) == _side(u): return "no_enemy"
		"ally":
			if at.is_empty() or _side(at) != _side(u): return "no_ally"
		"corpse", "machine":
			var k: Dictionary = _corpse_at(c)
			if k.is_empty(): return "no_corpse"
			if target == "machine" and not k.machine: return "not_machine"
	var sm: Dictionary = _summon_effect(ab)
	if not sm.is_empty():
		var from: String = str(sm.get("from", ""))
		var size: int = 1
		if from == "corpse" or from == "machine":
			var k: Dictionary = _corpse_at(c)
			if k.is_empty(): return "no_corpse"
			if from == "corpse" and not k.raiseable: return "not_raiseable"
			if from == "machine" and not k.machine: return "not_machine"
			size = int(_defs.get_def(&"enemy", k.def_id).get("size", 1)) if _defs.has(&"enemy", k.def_id) else 1
		else:
			var eid := StringName(str(sm.get("enemy", "")))
			if not _defs.has(&"enemy", eid): return "unknown_enemy"
			size = int(_defs.get_def(&"enemy", eid).get("size", 1))
		if not grid.fits(c, size, _occupied(-1)): return "blocked"
	var taunter: Dictionary = _taunter(u)
	if not taunter.is_empty() and _has_hostile_effect(ab) and _unit_at(c).get("uid", -1) != taunter.uid:
		return "taunted"
	return ""

func _candidate_cells(u: Dictionary, ab: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var target: String = str(ab.get("target", "enemy"))
	var rng_: int = int(ab.get("range", 0))
	match target:
		"self":
			if _target_error(u, ab, u.cell) == "": out.append(u.cell)
		"enemy", "ally":
			for t in _units:
				if not _active(t): continue
				for p in _cells_of(t):
					if _target_error(u, ab, p) == "":
						out.append(p)
						break
		"corpse", "machine":
			for k in _corpses:
				if _target_error(u, ab, k.cell) == "": out.append(k.cell)
		_:
			var lo: Vector2i = u.cell - Vector2i(rng_, rng_)
			var hi: Vector2i = u.cell + Vector2i(rng_ + u.size - 1, rng_ + u.size - 1)
			for y in range(maxi(0, lo.y), mini(grid.size.y - 1, hi.y) + 1):
				for x in range(maxi(0, lo.x), mini(grid.size.x - 1, hi.x) + 1):
					if _target_error(u, ab, Vector2i(x, y)) == "": out.append(Vector2i(x, y))
	return out

func _validate(action: Dictionary) -> String:
	if not _started: return "not_started"
	if _over: return "battle_over"
	var u: Dictionary = _u(_current)
	if u.is_empty() or not _active(u): return "no_unit"
	match str(action.get("type", "")):
		"end_turn":
			return ""
		"flee":
			return "" if _can_flee(u) else "cannot_flee"
		"move":
			return _path_error(u, action.get("path", []))
		"ability":
			var ab_id := StringName(str(action.get("ability", "")))
			if not u.abilities.has(ab_id): return "unknown_ability"
			var ab: Dictionary = _ability(ab_id)
			if ab.is_empty(): return "unknown_ability"
			if not _is_cell(action.get("cell")): return "bad_cell"
			var e: String = _cost_error(u, ab, true)
			return e if e != "" else _target_error(u, ab, _to_cell(action.cell))
		"item":
			if not _can_use_items(u): return "cannot_use_items"
			var ab: Dictionary = _item_ability(StringName(str(action.get("item", ""))))
			if ab.is_empty(): return "unknown_item"
			if not _is_cell(action.get("cell")): return "bad_cell"
			var e: String = _cost_error(u, ab, false)
			return e if e != "" else _target_error(u, ab, _to_cell(action.cell))
	return "unknown_action"

func _path_error(u: Dictionary, raw: Variant) -> String:
	if not raw is Array or (raw as Array).is_empty(): return "bad_path"
	var occ: Dictionary = _occupied(u.uid)
	var extra: Dictionary = _step_extra()
	var base: int = _step_base(u)
	var prev: Vector2i = u.cell
	var cost: int = 0
	for p in raw:
		if not _is_cell(p): return "bad_path"
		var c: Vector2i = _to_cell(p)
		if _dist(prev, c) != 1: return "bad_path"
		if not grid.fits(c, u.size, occ): return "blocked"
		cost += base + int(extra.get(c, 0))
		prev = c
	return "not_enough_ap" if cost > u.ap else ""

static func _is_cell(v: Variant) -> bool:
	return v is Vector2i or (v is Array and (v as Array).size() == 2)

static func _to_cell(v: Variant) -> Vector2i:
	if v is Vector2i: return v
	if v is Array and (v as Array).size() == 2: return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(-1, -1)

static func _to_path(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in raw: out.append(_to_cell(p))
	return out

# ---- combat math ------------------------------------------------------------

## Unit step from `from` toward `to` along the dominant axis (x on ties); ZERO when equal.
static func _dir(from: Vector2i, to: Vector2i) -> Vector2i:
	var d: Vector2i = to - from
	if d == Vector2i.ZERO: return d
	if absi(d.x) >= absi(d.y): return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))

func _nearest_cell(u: Dictionary, c: Vector2i) -> Vector2i:
	var best: Vector2i = u.cell
	for p in _cells_of(u):
		if _dist(p, c) < _dist(best, c): best = p
	return best

func _hit_chance(a: Dictionary, t: Dictionary, ab: Dictionary) -> int:
	var tc: Vector2i = _nearest_cell(t, a.cell)
	var ac: Vector2i = _nearest_cell(a, tc)
	var dir: Vector2i = _dir(tc, ac)
	var cover: int = 0
	var flanked: bool = false
	if dir != Vector2i.ZERO:
		if int(ab.get("range", 0)) > 1: cover = _cover_at(tc + dir)
		var opp: Vector2i = tc - dir
		while opp.x >= t.cell.x and opp.y >= t.cell.y and opp.x < t.cell.x + t.size and opp.y < t.cell.y + t.size:
			opp -= dir
		var f: Dictionary = _unit_at(opp)
		flanked = not f.is_empty() and f.uid != a.uid and _side(f) == _side(a)
	return Formulas.hit_chance(int(a.stats.get("agility", 0)), int(t.stats.get("agility", 0)), cover, flanked)

# ---- resolving actions ------------------------------------------------------

func _do_move(u: Dictionary, path: Array[Vector2i], ev: Array[Dictionary]) -> void:
	var cost: int = 0
	var extra: Dictionary = _step_extra()
	var base: int = _step_base(u)
	for c in path: cost += base + int(extra.get(c, 0))
	u.ap -= cost
	u.cell = path[-1]
	ev.append({"type": "moved", "uid": u.uid, "path": path})
	if _floaty_at(u) and _rng.chance(DRIFT_CHANCE):
		var occ: Dictionary = _occupied(u.uid)
		var free: Array[Vector2i] = []
		for d in Grid.DIRS:
			if grid.fits(u.cell + d, u.size, occ): free.append(u.cell + d)
		if not free.is_empty():
			var from: Vector2i = u.cell
			u.cell = free[_rng.randi_range(0, free.size() - 1)]
			ev.append({"type": "drifted", "uid": u.uid, "from": from, "to": u.cell})

func _use(c: Dictionary, ab_id: StringName, ab: Dictionary, cell: Vector2i, ev: Array[Dictionary], item_id: StringName) -> void:
	var used: Dictionary = {"type": "ability_used", "uid": c.uid, "ability": ab_id, "cell": cell}
	if item_id != &"": used["item"] = item_id
	ev.append(used)
	var area: int = int(ab.get("area", 0))
	var targets: Array[Dictionary] = []
	for t in _units:
		if _active(t) and _dist_cell_unit(cell, t) <= area: targets.append(t)
	# One to-hit roll per hostile target.
	var hits: Dictionary = {}   # uid -> {hit: bool, crit: bool}
	if _has_hostile_effect(ab):
		for t in targets:
			if _side(t) == _side(c): continue
			var roll: int = _rng.roll(20)
			var ok: bool = Formulas.roll_hits(roll, _hit_chance(c, t, ab))
			hits[t.uid] = {"hit": ok, "crit": ok and roll == 20}
			if not ok: ev.append({"type": "missed", "uid": c.uid, "target": t.uid})
	for eff in ab.get("effects", []):
		var kind: String = str(eff.get("kind", ""))
		var hostile: bool = kind in HOSTILE_KINDS or (kind == "status" and str(eff.get("status", "")) in HARMFUL_STATUSES)
		if kind == "summon":
			_summon(c, eff, cell, ev)
			continue
		if kind == "hazard":
			_place_hazard(cell, area, str(eff.get("hazard", "")), int(eff.get("turns", 1)), ev)
			continue
		for t in targets:
			if not _active(t): continue
			if hostile:
				if _side(t) == _side(c) or not hits.get(t.uid, {}).get("hit", false): continue
			elif _side(t) != _side(c):
				continue
			match kind:
				"damage":
					var armor: int = 0 if bool(eff.get("ignore_armor", false)) else int(t.armor)
					var dmg: int = Formulas.damage(int(eff.get("base", 0)), int(c.stats.get(str(eff.get("stat", "might")), 0)),
						float(eff.get("scale", 1.0)), armor - int(c.weapon_damage))
					var crit: bool = hits[t.uid].crit
					if crit: dmg *= 2
					_deal(t, dmg, crit, ev)
				"heal":
					var amt: int = maxi(0, floori(float(eff.get("base", 0)) + float(c.stats.get(str(eff.get("stat", "spirit")), 0)) * float(eff.get("scale", 1.0))))
					_heal(t, amt, ev)
				"shield":
					_add_status(t, "shield", int(eff.get("turns", 1)), int(eff.get("amount", 0)), -1, ev)
				"taunt":
					_add_status(t, "taunted", int(eff.get("turns", 1)), 0, c.uid, ev)
				"status":
					var st: String = str(eff.get("status", ""))
					_add_status(t, st, int(eff.get("turns", 1)), int(eff.get("value", STATUS_DEFAULT_VALUE.get(st, 0))), -1, ev)
				"cleanse":
					for st in CLEANSED:
						if t.statuses.has(st):
							t.statuses.erase(st)
							ev.append({"type": "status_ended", "target": t.uid, "status": st})
				"push":
					_push(c, t, int(eff.get("cells", 1)), ev)
	_check_end(ev)

func _add_status(t: Dictionary, st: String, turns: int, value: int, by: int, ev: Array[Dictionary]) -> void:
	if turns <= 0: return
	var cur: Dictionary = t.statuses.get(st, {})
	var s: Dictionary = {"turns": maxi(turns, int(cur.get("turns", 0))), "value": maxi(value, int(cur.get("value", 0)))}
	if st == "taunted": s["by"] = by
	t.statuses[st] = s
	ev.append({"type": "status", "target": t.uid, "status": st, "turns": s.turns})

func _deal(t: Dictionary, amount: int, crit: bool, ev: Array[Dictionary]) -> void:
	var absorbed: int = 0
	var shield_gone: bool = false
	if t.statuses.has("shield"):
		var sh: Dictionary = t.statuses.shield
		absorbed = mini(int(sh.value), amount)
		sh.value = int(sh.value) - absorbed
		amount -= absorbed
		if sh.value <= 0:
			t.statuses.erase("shield")
			shield_gone = true
	var before: int = t.hp
	t.hp = maxi(0, t.hp - amount)
	ev.append({"type": "damaged", "target": t.uid, "amount": amount, "crit": crit, "shield_absorbed": absorbed})
	if shield_gone: ev.append({"type": "status_ended", "target": t.uid, "status": "shield"})
	if t.hp == 0 and before > 0: _kill(t, crit, amount - before, ev)

func _heal(t: Dictionary, amount: int, ev: Array[Dictionary]) -> void:
	var got: int = mini(amount, t.max_hp - t.hp)
	t.hp += got
	ev.append({"type": "healed", "target": t.uid, "amount": got})

func _kill(t: Dictionary, crit: bool, overkill: int, ev: Array[Dictionary]) -> void:
	t.statuses = {}
	t.ap = 0
	if t.side == "party" and not t.summoned:
		t.downed = true
		ev.append({"type": "died", "target": t.uid, "gib": false, "corpse": false})
		return
	t.dead = true
	var gib: bool = t.gib and Formulas.is_gib(crit, overkill, t.max_hp)
	var corpse: bool = not t.summoned and (t.raiseable or t.machine)
	if corpse:
		_corpses.append({"cell": t.cell, "def_id": t.def_id, "raiseable": t.raiseable, "machine": t.machine})
	if t.side == "enemy" and not t.summoned:
		for l in t.loot:
			if _rng.chance(float(l.get("chance", 0.0))):
				var item: StringName = StringName(str(l.get("item", "")))
				_loot[item] = int(_loot.get(item, 0)) + 1
	ev.append({"type": "died", "target": t.uid, "gib": gib, "corpse": corpse})

func _push(c: Dictionary, t: Dictionary, cells: int, ev: Array[Dictionary]) -> void:
	var dir: Vector2i = _dir(c.cell, t.cell)
	if dir == Vector2i.ZERO: return
	if _floaty_at(t): cells += 2
	var occ: Dictionary = _occupied(t.uid)
	var path: Array[Vector2i] = []
	var cur: Vector2i = t.cell
	for i in cells:
		if not grid.fits(cur + dir, t.size, occ): break
		cur += dir
		path.append(cur)
	if path.is_empty(): return
	t.cell = cur
	ev.append({"type": "pushed", "target": t.uid, "path": path})

func _summon(c: Dictionary, eff: Dictionary, cell: Vector2i, ev: Array[Dictionary]) -> void:
	var from: String = str(eff.get("from", ""))
	var def_id: StringName
	if from == "corpse" or from == "machine":
		var k: Dictionary = _corpse_at(cell)
		if k.is_empty(): return
		def_id = k.def_id
		_corpses.erase(k)
	else:
		def_id = StringName(str(eff.get("enemy", "")))
	if not _defs.has(&"enemy", def_id): return
	var s: Dictionary = _add_enemy_unit(_defs.get_def(&"enemy", def_id), cell, c.side, true, c.uid)
	if s.side == "party": s.hp = maxi(1, s.max_hp / 2)
	# Acts right after its summoner (after the summoner's earlier summons).
	var at: int = _order.find(c.uid) + 1
	while at < _order.size() and _u(_order[at]).summoner == c.uid: at += 1
	_order.insert(at, s.uid)
	if at <= _turn_i: _turn_i += 1
	ev.append({"type": "summoned", "uid": s.uid, "def_id": def_id, "cell": cell, "from_corpse": from == "corpse"})

func _place_hazard(center: Vector2i, area: int, kind: String, turns: int, ev: Array[Dictionary]) -> void:
	for y in range(center.y - area, center.y + area + 1):
		for x in range(center.x - area, center.x + area + 1):
			var p := Vector2i(x, y)
			if not grid.in_bounds(p) or _dist(p, center) > area: continue
			var found: bool = false
			for h in _hazards:
				if h.cell == p and h.hazard == kind:
					h.turns = maxi(int(h.turns), turns)
					found = true
			if not found: _hazards.append({"cell": p, "hazard": kind, "turns": turns})
			ev.append({"type": "hazard", "cell": p, "hazard": kind, "turns": turns})

# ---- turn flow --------------------------------------------------------------

func _end_turn(u: Dictionary, ev: Array[Dictionary]) -> void:
	_tick_statuses(u, ev)
	_next_turn(ev)

func _tick_statuses(u: Dictionary, ev: Array[Dictionary]) -> void:
	for st in u.statuses.keys():
		var s: Dictionary = u.statuses[st]
		s.turns = int(s.turns) - 1
		if s.turns <= 0:
			u.statuses.erase(st)
			ev.append({"type": "status_ended", "target": u.uid, "status": st})

func _next_turn(ev: Array[Dictionary]) -> void:
	while not _over:
		_turn_i += 1
		if _turn_i >= _order.size():
			_turn_i = 0
			if not _new_round(ev): return
		var u: Dictionary = _u(_order[_turn_i])
		if not _active(u): continue
		if _begin_turn(u, ev): return

## False when the battle ended instead.
func _new_round(ev: Array[Dictionary]) -> bool:
	round += 1
	var limit: int = int(rules.turn_limit)
	if limit > 0 and round > limit:
		round = limit
		_finish("lose", "timeout", ev)
		return false
	if round > MAX_ROUNDS:
		round = MAX_ROUNDS
		_finish("lose", "stalemate", ev)
		return false
	for h in _hazards.duplicate():
		h.turns = int(h.turns) - 1
		if h.turns <= 0:
			_hazards.erase(h)
			ev.append({"type": "hazard", "cell": h.cell, "hazard": h.hazard, "turns": 0})
	if limit > 0: ev.append({"type": "timer", "turns_left": limit - round + 1})
	return true

## True when the unit now gets to act (or the battle ended).
func _begin_turn(u: Dictionary, ev: Array[Dictionary]) -> bool:
	_current = u.uid
	var stunned: bool = u.statuses.has("stunned")
	var ap: int = Formulas.ap_for(int(u.stats.get("agility", 0)))
	if u.statuses.has("chilled"): ap -= int(u.statuses.chilled.get("value", 0))
	u.ap = 0 if stunned else maxi(0, ap)
	ev.append({"type": "turn_started", "uid": u.uid, "ap": u.ap})
	if u.statuses.has("bleeding"): _deal(u, int(u.statuses.bleeding.value), false, ev)
	if _active(u) and u.statuses.has("regen"): _heal(u, int(u.statuses.regen.value), ev)
	if _active(u):
		for p in _cells_of(u):
			if _has_hazard(p, "acid"):
				_deal(u, ACID_DAMAGE, false, ev)
				break
	_check_end(ev)
	if _over: return true
	if not _active(u): return false
	if stunned:
		_tick_statuses(u, ev)
		return false
	return true

func _living_enemies() -> int:
	var n: int = 0
	for u in _units:
		if u.side == "enemy" and _active(u): n += 1
	return n

func _check_end(ev: Array[Dictionary]) -> void:
	if _over or not _started: return
	if _living_enemies() == 0:
		_finish("win", "enemies_defeated", ev)
		return
	for u in _units:
		if u.side == "party" and not u.summoned and _active(u): return
	_finish("lose", "party_down", ev)

func _finish(outcome: String, reason: String, ev: Array[Dictionary]) -> void:
	if _over: return
	_over = true
	_outcome = outcome
	_reason = reason
	ev.append({"type": "battle_ended", "outcome": outcome, "reason": reason})
