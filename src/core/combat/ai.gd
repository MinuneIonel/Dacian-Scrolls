## Picks actions for units. Every function returns one member of battle.legal_actions(uid)
## (or {} when that list is empty: not this unit's turn, or the battle is over).
## One action per call; the caller calls again until the turn changes. Every chosen move or
## ability spends AP, and a per-turn cap ends the turn, so a turn always ends.
##
## Styles: the enemy def's "ai" (brute, skirmisher, caster, boss_surgeon); party-side units the AI
## drives (summons, charmed party members) fight as brutes; policy_good plays a competent party.
class_name Ai
extends RefCounted

const STYLES: Array[String] = ["brute", "skirmisher", "caster", "boss_surgeon"]
## Safety net: after this many actions in one turn, end it.
const MAX_ACTIONS_PER_TURN: int = 16
## policy_random ends its turn after this many actions.
const RANDOM_ACTIONS_PER_TURN: int = 6
## A move must beat staying put by this much.
const MOVE_MARGIN: float = 0.5
const KILL_BONUS: float = 12.0
const STATUS_VALUE: Dictionary = {"stunned": 9.0, "charmed": 10.0, "slowed": 3.0, "chilled": 3.0}
const HARMFUL: Array[String] = ["slowed", "stunned", "bleeding", "chilled", "charmed"]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const FAR: int = 1 << 20

## Enemy brain, by the enemy's "ai" field.
static func choose(battle: Battle, uid: int, rng: Rng) -> Dictionary:
	var me: Dictionary = battle.unit(uid)
	var style: String = str(me.get("ai", ""))
	if str(me.get("side", "")) == "party" or not style in STYLES: style = "brute"
	return _decide(battle, uid, style, rng)

## A competent player: focuses fire, uses combos, heals when needed. For balance sims and the bot.
static func policy_good(battle: Battle, uid: int, rng: Rng) -> Dictionary:
	return _decide(battle, uid, "good", rng)

## A button-masher: a uniformly random legal action, but never end_turn while other actions exist.
## It never flees, and ends its turn after RANDOM_ACTIONS_PER_TURN actions.
static func policy_random(battle: Battle, uid: int, rng: Rng) -> Dictionary:
	var acts: Array[Dictionary] = battle.legal_actions(uid)
	if acts.is_empty(): return {}
	if _count_action(battle, uid) > RANDOM_ACTIONS_PER_TURN: return acts[0]
	var pool: Array[Dictionary] = []
	for a in acts:
		if a.type != "end_turn" and a.type != "flee": pool.append(a)
	if pool.is_empty(): return acts[0]
	return pool[rng.randi_range(0, pool.size() - 1)]

# ---- the decision -----------------------------------------------------------

static func _decide(b: Battle, uid: int, style: String, rng: Rng) -> Dictionary:
	var acts: Array[Dictionary] = b.legal_actions(uid)
	if acts.is_empty(): return {}
	var end: Dictionary = acts[0]   # always {type: end_turn}
	if _count_action(b, uid) > MAX_ACTIONS_PER_TURN: return end
	var ctx: Dictionary = _context(b, uid, style)
	# Best ability or item.
	var best_a: Array[Dictionary] = []
	var best_s: float = 0.0
	for a in acts:
		if a.type != "ability" and a.type != "item": continue
		var ab: Dictionary = _action_ability(b, a)
		if ab.is_empty() or int(ab.get("ap", 0)) <= 0: continue
		var s: float = _score_action(ctx, a, ab)
		if s > best_s + 0.001:
			best_s = s
			best_a = [a]
		elif s > 0.0 and absf(s - best_s) <= 0.001:
			best_a.append(a)
	# Best move.
	var me: Dictionary = ctx.me
	var stay: float = _position_score(ctx, me.cell, int(me.ap))
	var best_m: Array[Dictionary] = []
	var best_ms: float = stay + MOVE_MARGIN
	for a in acts:
		if a.type != "move" or (a.path as Array).is_empty(): continue
		var cost: int = _path_cost(ctx, a.path)
		var s: float = _position_score(ctx, a.path[-1], int(me.ap) - cost) - 0.2 * cost
		if s > best_ms + 0.001:
			best_ms = s
			best_m = [a]
		elif absf(s - best_ms) <= 0.001 and not best_m.is_empty():
			best_m.append(a)
	if style == "skirmisher" and ctx.ranged and _threats_at(ctx, me.cell) > 0 and not best_m.is_empty():
		return _pick(best_m, rng)
	if not best_a.is_empty():
		var chosen: Dictionary = _pick(best_a, rng)
		if style == "boss_surgeon" and not _summon_effect(_action_ability(b, chosen)).is_empty():
			b.set_meta(_summon_key(uid), true)
		return chosen
	if not best_m.is_empty(): return _pick(best_m, rng)
	return end

static func _pick(arr: Array[Dictionary], rng: Rng) -> Dictionary:
	return arr[0] if arr.size() == 1 else arr[rng.randi_range(0, arr.size() - 1)]

## Counts this call as one action of uid's current turn; returns the count so far.
static func _count_action(b: Battle, uid: int) -> int:
	var key: String = "%d:%d" % [b.round, uid]
	var c: Array = b.get_meta("ai_turn", ["", 0])
	if c[0] != key: c = [key, 0]
	c = [key, int(c[1]) + 1]
	b.set_meta("ai_turn", c)
	return int(c[1])

static func _summon_key(uid: int) -> String:
	return "ai_summoned_%d" % uid

# ---- context ----------------------------------------------------------------

static func _context(b: Battle, uid: int, style: String) -> Dictionary:
	var me: Dictionary = b.unit(uid)
	var hostiles: Array[Dictionary] = []
	var allies: Array[Dictionary] = []
	var occ: Dictionary = {}
	var occ_hostile: Dictionary = {}
	for u in b.units():
		if u.downed: continue
		if u.uid != uid:
			for p in _cells(u.cell, int(u.size)):
				occ[p] = true
				if not b.are_allies(uid, u.uid): occ_hostile[p] = true
		if b.are_allies(uid, u.uid): allies.append(u)
		else: hostiles.append(u)
	var tanks: Dictionary = {}
	var extra: Dictionary = {}
	for h in b.hazards():
		if h.hazard == "specimen_tank":
			occ[h.cell] = true
			occ_hostile[h.cell] = true
			tanks[h.cell] = true
		elif h.hazard == "gravity_zone" and str(b.rules.gravity) != "floaty":
			extra[h.cell] = 1
	var ctx: Dictionary = {"b": b, "uid": uid, "me": me, "style": style, "hostiles": hostiles,
		"allies": allies, "occ": occ, "occ_hostile": occ_hostile, "tanks": tanks, "extra": extra,
		"step": (2 if str(b.rules.gravity) == "floaty" else 1) + (1 if me.statuses.has("slowed") else 0)}
	var offense: Array[Dictionary] = []
	var max_range: int = 0
	var has_melee: bool = false
	for id in me.abilities:
		var ab: Dictionary = b._ability(StringName(str(id)))
		if ab.is_empty() or int(ab.get("ap", 0)) <= 0 or not _has_hostile(ab) or not _affordable(b, me, ab): continue
		if not str(ab.get("target", "")) in ["enemy", "cell"]: continue
		offense.append(ab)
		max_range = maxi(max_range, int(ab.get("range", 0)))
		if int(ab.get("range", 0)) <= 1: has_melee = true
	ctx["offense"] = offense
	ctx["max_range"] = max_range
	ctx["ranged"] = max_range > 1 and (style == "skirmisher" or style == "caster" or not has_melee)
	ctx["field"] = _attack_field(ctx, maxi(1, max_range))
	return ctx

static func _affordable(b: Battle, me: Dictionary, ab: Dictionary) -> bool:
	var src: String = str(ab.get("source", ""))
	if src == "magic" and bool(b.rules.magic_disabled): return false
	if str(me.char_id) == "": return true
	if src == "magic" and int(me.mana) < int(ab.get("cost", 0)): return false
	if src == "tech" and int(me.charge) < int(ab.get("cost", 0)): return false
	return true

static func _action_ability(b: Battle, a: Dictionary) -> Dictionary:
	if a.type == "ability": return b._ability(StringName(str(a.ability)))
	if a.type == "item": return b._item_ability(StringName(str(a.item)))
	return {}

static func _has_hostile(ab: Dictionary) -> bool:
	for e in ab.get("effects", []):
		var k: String = str(e.get("kind", ""))
		if k in ["damage", "taunt", "push"]: return true
		if k == "status" and str(e.get("status", "")) in HARMFUL: return true
	return false

static func _summon_effect(ab: Dictionary) -> Dictionary:
	for e in ab.get("effects", []):
		if str(e.get("kind", "")) == "summon": return e
	return {}

# ---- geometry ---------------------------------------------------------------

static func _cells(anchor: Vector2i, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in size:
		for dx in size: out.append(anchor + Vector2i(dx, dy))
	return out

static func _dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## Distance between a footprint at `anchor` and unit t (closest cells).
static func _reach(anchor: Vector2i, size: int, t: Dictionary) -> int:
	var best: int = FAR
	for p in _cells(anchor, size):
		for q in _cells(t.cell, int(t.size)): best = mini(best, _dist(p, q))
	return best

static func _dir(from: Vector2i, to: Vector2i) -> Vector2i:
	var d: Vector2i = to - from
	if d == Vector2i.ZERO: return d
	if absi(d.x) >= absi(d.y): return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))

static func _closest(cells: Array[Vector2i], to: Vector2i) -> Vector2i:
	var best: Vector2i = cells[0]
	for c in cells:
		if _dist(c, to) < _dist(best, to): best = c
	return best

static func _cover(ctx: Dictionary, c: Vector2i) -> int:
	var b: Battle = ctx.b
	return maxi(b.grid.cover_at(c), Battle.TANK_COVER if ctx.tanks.has(c) else 0)

## Cover a unit with footprint at `anchor` gets against shots from unit h.
static func _cover_vs(ctx: Dictionary, anchor: Vector2i, size: int, h: Dictionary) -> int:
	var mine: Array[Vector2i] = _cells(anchor, size)
	var tc: Vector2i = _closest(mine, h.cell)
	var hc: Vector2i = _closest(_cells(h.cell, int(h.size)), tc)
	var d: Vector2i = _dir(tc, hc)
	return 0 if d == Vector2i.ZERO else _cover(ctx, tc + d)

## Hostiles adjacent to a footprint at `anchor`.
static func _threats_at(ctx: Dictionary, anchor: Vector2i) -> int:
	var n: int = 0
	for h in ctx.hostiles:
		if _reach(anchor, int(ctx.me.size), h) <= 1: n += 1
	return n

static func _path_cost(ctx: Dictionary, path: Array) -> int:
	var cost: int = 0
	for c in path: cost += int(ctx.step) + int(ctx.extra.get(c, 0))
	return cost

## Steps from each cell to the nearest cell where the unit can reach a hostile within `rng_`.
## Multi-source BFS over cells the unit fits. Allies block; if that leaves the unit cut off,
## the field is rebuilt with allies treated as passable.
static func _attack_field(ctx: Dictionary, rng_: int) -> Dictionary:
	var f: Dictionary = _bfs(ctx, rng_, ctx.occ)
	if not f.has(ctx.me.cell): f = _bfs(ctx, rng_, ctx.occ_hostile)
	return f

static func _bfs(ctx: Dictionary, rng_: int, occ: Dictionary) -> Dictionary:
	var b: Battle = ctx.b
	var size: int = int(ctx.me.size)
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for y in b.grid.size.y:
		for x in b.grid.size.x:
			var c := Vector2i(x, y)
			if not b.grid.fits(c, size, occ): continue
			for h in ctx.hostiles:
				if _reach(c, size, h) <= rng_:
					dist[c] = 0
					queue.append(c)
					break
	var i: int = 0
	while i < queue.size():
		var cur: Vector2i = queue[i]
		i += 1
		for d in DIRS:
			var n: Vector2i = cur + d
			if dist.has(n) or not b.grid.fits(n, size, occ): continue
			dist[n] = int(dist[cur]) + 1
			queue.append(n)
	return dist

# ---- scoring actions --------------------------------------------------------

static func _score_action(ctx: Dictionary, a: Dictionary, ab: Dictionary) -> float:
	var cell: Vector2i = a.cell
	var area: int = int(ab.get("area", 0))
	var s: float = 0.0
	if _has_hostile(ab):
		for t in ctx.hostiles:
			if _reach(cell, 1, t) <= area: s += _hostile_value(ctx, t, ab)
	for t in ctx.allies:
		if _reach(cell, 1, t) <= area: s += _friendly_value(ctx, t, ab)
	for e in ab.get("effects", []):
		var k: String = str(e.get("kind", ""))
		if k == "summon": s += _summon_value(ctx, e)
		elif k == "hazard": s += _hazard_value(ctx, cell, area, e)
	if str(ctx.me.char_id) != "" and str(ab.get("source", "")) != "steel":
		s -= 0.3 * int(ab.get("cost", 0))
	if a.type == "item": s -= 3.0
	return s

static func _damage_of(ctx: Dictionary, t: Dictionary, ab: Dictionary) -> int:
	var me: Dictionary = ctx.me
	var dmg: int = 0
	for e in ab.get("effects", []):
		if str(e.get("kind", "")) != "damage": continue
		var armor: int = 0 if bool(e.get("ignore_armor", false)) else int(t.armor)
		dmg += Formulas.damage(int(e.get("base", 0)), int(me.stats.get(str(e.get("stat", "might")), 0)),
			float(e.get("scale", 1.0)), armor - int(me.weapon_damage))
	return dmg

static func _hp_pool(t: Dictionary) -> int:
	return int(t.hp) + int(t.statuses.get("shield", {}).get("value", 0))

## Expected value of a hostile ability against t, at hit chance p (0..1).
static func _hostile_effects_value(ctx: Dictionary, t: Dictionary, ab: Dictionary, p: float) -> float:
	var v: float = 0.0
	var dmg: int = _damage_of(ctx, t, ab)
	var pool: int = _hp_pool(t)
	if dmg > 0:
		v += p * mini(dmg, pool)
		if dmg >= pool: v += p * KILL_BONUS
	for e in ab.get("effects", []):
		var k: String = str(e.get("kind", ""))
		if k == "status":
			var st: String = str(e.get("status", ""))
			if not st in HARMFUL or t.statuses.has(st): continue
			if st == "bleeding": v += p * 0.8 * int(e.get("value", 2)) * int(e.get("turns", 1))
			else: v += p * float(STATUS_VALUE.get(st, 2.0))
		elif k == "taunt":
			if int(t.statuses.get("taunted", {}).get("by", -1)) == int(ctx.uid): continue
			v += p * _taunt_value(ctx, t)
		elif k == "push":
			v += p * _push_value(ctx, t, int(e.get("cells", 1)))
	return v

static func _hostile_value(ctx: Dictionary, t: Dictionary, ab: Dictionary) -> float:
	var b: Battle = ctx.b
	var p: float = b.hit_chance(int(ctx.uid), int(t.uid), StringName(str(ab.id))) / 100.0
	var v: float = _hostile_effects_value(ctx, t, ab, p)
	return v + _target_pref(ctx, t) if v > 0.0 else 0.0

## Which hostile this style likes to hit, as a bonus on top of the expected value.
static func _target_pref(ctx: Dictionary, t: Dictionary) -> float:
	match str(ctx.style):
		"caster": return maxf(0.0, 40.0 - _hp_pool(t)) * 0.4
		"good": return maxf(0.0, 40.0 - _hp_pool(t)) * 0.3
		"skirmisher": return maxf(0.0, 30.0 - _hp_pool(t)) * 0.2
		"boss_surgeon": return _danger(t) * 0.6
	return 0.0

## How much damage a unit can dish out: its best stat plus weapon.
static func _danger(t: Dictionary) -> float:
	var st: Dictionary = t.stats
	return float(maxi(int(st.get("might", 0)), maxi(int(st.get("wits", 0)), int(st.get("spirit", 0)))) + int(t.weapon_damage))

## Taunting t is worth more when t is next to one of our other units.
static func _taunt_value(ctx: Dictionary, t: Dictionary) -> float:
	for a in ctx.allies:
		if int(a.uid) != int(ctx.uid) and _reach(a.cell, int(a.size), t) <= 2: return 6.0
	return 1.5

## Where a push of t would land (same rule as the engine).
static func _push_value(ctx: Dictionary, t: Dictionary, cells: int) -> float:
	var b: Battle = ctx.b
	var me: Dictionary = ctx.me
	var d: Vector2i = _dir(me.cell, t.cell)
	if d == Vector2i.ZERO: return 0.0
	var haz: Dictionary = {}
	for h in b.hazards(): haz[h.cell] = h.hazard
	var floaty: bool = str(b.rules.gravity) == "floaty"
	for p in _cells(t.cell, int(t.size)):
		if haz.get(p, "") == "gravity_zone": floaty = true
	if floaty: cells += 2
	var occ: Dictionary = {}
	for u in b.units():
		if u.downed or int(u.uid) == int(t.uid): continue
		for p in _cells(u.cell, int(u.size)): occ[p] = true
	for c in ctx.tanks: occ[c] = true
	var cur: Vector2i = t.cell
	for i in cells:
		if not b.grid.fits(cur + d, int(t.size), occ): break
		cur += d
	if cur == t.cell: return 0.0
	for p in _cells(cur, int(t.size)):
		var h: String = str(haz.get(p, ""))
		if h == "gravity_zone" or h == "acid": return 30.0 if ctx.style == "boss_surgeon" else 6.0
	return 0.5

static func _friendly_value(ctx: Dictionary, t: Dictionary, ab: Dictionary) -> float:
	var me: Dictionary = ctx.me
	var ratio: float = float(t.hp) / maxf(1.0, float(t.max_hp))
	var thresh: float = 0.5 if ctx.style == "good" else 0.6
	var v: float = 0.0
	for e in ab.get("effects", []):
		match str(e.get("kind", "")):
			"heal":
				if ratio >= thresh: continue
				var amt: int = maxi(0, floori(float(e.get("base", 0)) + float(me.stats.get(str(e.get("stat", "spirit")), 0)) * float(e.get("scale", 1.0))))
				v += 2.0 * mini(amt, int(t.max_hp) - int(t.hp)) + 8.0
				if ratio < 0.25: v += 8.0
			"shield":
				if t.statuses.has("shield"): continue
				for h in ctx.hostiles:
					if _reach(t.cell, int(t.size), h) <= 2:
						v += 0.6 * int(e.get("amount", 0))
						break
			"cleanse":
				for st in HARMFUL + ["taunted"]:
					if t.statuses.has(st): v += 4.0
			"status":
				var st: String = str(e.get("status", ""))
				if st in HARMFUL or t.statuses.has(st) or ratio >= 0.9: continue
				v += 0.5 * int(e.get("value", 2)) * int(e.get("turns", 1))
	if bool(t.summoned) and ctx.style == "good": v *= 0.5
	return v

static func _summon_value(ctx: Dictionary, e: Dictionary) -> float:
	var from: String = str(e.get("from", ""))
	if from == "corpse" or from == "machine": return 25.0
	if ctx.style != "boss_surgeon": return 15.0
	var me: Dictionary = ctx.me
	var b: Battle = ctx.b
	if int(me.hp) * 2 > int(me.max_hp) or b.has_meta(_summon_key(int(ctx.uid))): return -100.0
	for u in b.units():
		if int(u.summoner) == int(ctx.uid): return -100.0
	return 100.0

static func _hazard_value(ctx: Dictionary, cell: Vector2i, area: int, e: Dictionary) -> float:
	var b: Battle = ctx.b
	var kind: String = str(e.get("hazard", ""))
	var boss: bool = ctx.style == "boss_surgeon"
	if boss:
		if b.round != 1: return 0.0
		for h in b.hazards():
			if h.hazard == kind: return 0.0
	var hit: int = 0
	for t in ctx.hostiles:
		if _reach(cell, 1, t) <= area: hit += 1
	match kind:
		"gravity_zone":
			return 12.0 + 5.0 * hit if boss else 2.0 * hit
		"acid":
			return 8.0 + 8.0 * hit if boss else 5.0 * hit
		"specimen_tank":
			if not boss or b.unit_at(cell) != -1 or not b.grid.is_walkable(cell): return 0.0
			return 18.0 + maxf(0.0, 3.0 - _reach(cell, 1, ctx.me))
	return 0.0

# ---- scoring positions ------------------------------------------------------

## How good it is to stand at `anchor` with `ap` left.
static func _position_score(ctx: Dictionary, anchor: Vector2i, ap: int) -> float:
	var me: Dictionary = ctx.me
	var size: int = int(me.size)
	var s: float = 0.0
	var best: float = 0.0
	for ab in ctx.offense:
		if int(ab.get("ap", 0)) > ap: continue
		var r: int = int(ab.get("range", 0)) + (int(ab.get("area", 0)) if str(ab.get("target", "")) == "cell" else 0)
		for t in ctx.hostiles:
			if _reach(anchor, size, t) > r: continue
			var p: float = _est_hit(ctx, anchor, t, ab) / 100.0
			var v: float = _hostile_effects_value(ctx, t, ab, p)
			if v > 0.0: best = maxf(best, v + _target_pref(ctx, t))
	s += best
	if best <= 0.0: s -= 1.5 * float(ctx.field.get(anchor, 40))
	if ctx.ranged:
		s -= 6.0 * _threats_at(ctx, anchor)
		var near: Dictionary = _nearest_hostile(ctx, anchor)
		if not near.is_empty():
			s += _cover_vs(ctx, anchor, size, near) / 5.0
			if ctx.style == "skirmisher": s += 0.5 * mini(_reach(anchor, size, near), int(ctx.max_range))
	elif ctx.style == "good":
		var near2: Dictionary = _nearest_hostile(ctx, anchor)
		if not near2.is_empty(): s += _cover_vs(ctx, anchor, size, near2) / 10.0
	return s

static func _nearest_hostile(ctx: Dictionary, anchor: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var bd: int = FAR
	for h in ctx.hostiles:
		var d: int = _reach(anchor, int(ctx.me.size), h)
		if d < bd:
			bd = d
			best = h
	return best

## Hit chance (percent) for an attack from `anchor` on t: agility and cover, no flank.
static func _est_hit(ctx: Dictionary, anchor: Vector2i, t: Dictionary, ab: Dictionary) -> int:
	var me: Dictionary = ctx.me
	var cover: int = 0
	if int(ab.get("range", 0)) > 1:
		var tc: Vector2i = _closest(_cells(t.cell, int(t.size)), anchor)
		var ac: Vector2i = _closest(_cells(anchor, int(me.size)), tc)
		var d: Vector2i = _dir(tc, ac)
		if d != Vector2i.ZERO: cover = _cover(ctx, tc + d)
	return Formulas.hit_chance(int(me.stats.get("agility", 0)), int(t.stats.get("agility", 0)), cover, false)
