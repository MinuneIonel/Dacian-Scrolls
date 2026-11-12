## The rules mini-language shared by dialogue, quests, encounters and map triggers.
## Conditions are arrays like ["flag", "met_priest", "==", true]; effects like ["gold", 12].
## See docs/CONTRACTS.md section "Rules" for every form.
class_name Rules
extends RefCounted

## Condition name -> number of arguments after the name.
const CONDITIONS: Dictionary = {
	"flag": 3, "quest": 3, "has_item": 2, "gold": 2, "class": 1, "in_party": 1,
	"has_page": 1, "stat": 3, "night": 0, "not": 1, "any": 1,
}
## Effect name -> number of arguments after the name.
const EFFECTS: Dictionary = {
	"set_flag": 2, "give_item": 2, "take_item": 2, "gold": 1, "food": 1, "quest": 2,
	"page": 1, "xp": 1, "recruit": 1, "heal_party": 0, "battle": 1, "shop": 1,
	"discover": 1, "teleport": 1, "narrate": 1, "roll": 4,
}
const OPS: Array[String] = ["==", "!=", ">=", "<=", ">", "<"]

const REVEAL_RADIUS: int = 2
const MAX_PARTY: int = 4

## True when every condition holds. An empty list is true.
static func check(conds: Array, state: GameState, defs: Defs) -> bool:
	for c in conds:
		if not _cond(c, state, defs): return false
	return true

## Applies effects in order, returns the events they caused.
static func run(effects: Array, state: GameState, rng: Rng, defs: Defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in effects:
		out.append_array(_effect(e, state, rng, defs))
	return out

## Percent chance shown to players for a roll: clamp((21 - (dc - best)) * 5, 0, 100).
static func roll_chance(dc: int, best: int) -> int:
	return clampi((21 - (dc - best)) * 5, 0, 100)

## The best value of a stat among party members (0 for an empty party).
static func best_stat(state: GameState, stat: String) -> int:
	var best: int = 0
	for c in state.party: best = maxi(best, int(c.stats.get(stat, 0)))
	return best

## Compares a and b with op. Numbers compare by value, strings with StringNames; other
## mismatched types are only ever "!=".
static func compare(a: Variant, op: String, b: Variant) -> bool:
	var num_a: bool = a is int or a is float
	var num_b: bool = b is int or b is float
	if (a is String or a is StringName) and (b is String or b is StringName):
		a = str(a); b = str(b)
	elif not (num_a and num_b) and typeof(a) != typeof(b):
		return op == "!="
	match op:
		"==": return a == b
		"!=": return a != b
	if not (num_a and num_b) and not (a is String): return false
	match op:
		">=": return a >= b
		"<=": return a <= b
		">": return a > b
		"<": return a < b
	return false

# ---- conditions --------------------------------------------------------------

## Checks name and arity; pushes one error and returns "" when malformed.
static func _head(x: Variant, table: Dictionary, what: String) -> String:
	if not (x is Array) or x.is_empty() or not (x[0] is String or x[0] is StringName):
		push_error("Rules: malformed %s %s" % [what, var_to_str(x)])
		return ""
	var name: String = str(x[0])
	if not table.has(name):
		push_error("Rules: unknown %s '%s'" % [what, name])
		return ""
	if x.size() - 1 != int(table[name]):
		push_error("Rules: %s '%s' takes %d args, got %d" % [what, name, table[name], x.size() - 1])
		return ""
	return name

static func _op_ok(op: Variant) -> bool:
	if op is String and OPS.has(op): return true
	push_error("Rules: bad operator %s" % var_to_str(op))
	return false

static func _cond(c: Variant, state: GameState, defs: Defs) -> bool:
	var name: String = _head(c, CONDITIONS, "condition")
	match name:
		"flag":
			if not _op_ok(c[2]): return false
			return compare(state.flags.get(str(c[1]), false), c[2], c[3])
		"quest":
			if not _op_ok(c[2]): return false
			return compare(int(state.quests.get(StringName(str(c[1])), 0)), c[2], c[3])
		"has_item":
			return int(state.inventory.get(StringName(str(c[1])), 0)) >= int(c[2])
		"gold":
			if not _op_ok(c[1]): return false
			return compare(state.gold, c[1], c[2])
		"class":
			return not state.party.is_empty() and state.party[0].class_id == StringName(str(c[1]))
		"in_party":
			return _member(state, StringName(str(c[1]))) != null
		"has_page":
			return state.pages.has(StringName(str(c[1])))
		"stat":
			if not _op_ok(c[2]): return false
			return compare(best_stat(state, str(c[1])), c[2], c[3])
		"night":
			return state.is_night()
		"not":
			return not _cond(c[1], state, defs)
		"any":
			if not (c[1] is Array):
				push_error("Rules: 'any' takes a list of conditions")
				return false
			for sub in c[1]:
				if _cond(sub, state, defs): return true
			return false
	return false

static func _member(state: GameState, id: StringName) -> Character:
	for m in state.party:
		if m.id == id: return m
	return null

# ---- effects -----------------------------------------------------------------

static func _effect(e: Variant, state: GameState, rng: Rng, defs: Defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var name: String = _head(e, EFFECTS, "effect")
	match name:
		"set_flag":
			state.flags[str(e[1])] = e[2]
			out.append({"type": "flag_set", "flag": str(e[1]), "value": e[2]})
		"give_item", "take_item":
			var item := StringName(str(e[1]))
			var n: int = absi(int(e[2]))
			var have: int = int(state.inventory.get(item, 0))
			var now: int = have + n if name == "give_item" else maxi(0, have - n)
			if now > 0: state.inventory[item] = now
			else: state.inventory.erase(item)
			out.append({"type": "item_changed", "item": item, "delta": now - have})
		"gold":
			var before: int = state.gold
			state.gold = maxi(0, state.gold + int(e[1]))
			out.append({"type": "gold_changed", "delta": state.gold - before})
		"food":
			var before: int = state.food
			state.food = maxi(0, state.food + int(e[1]))
			out.append({"type": "food_changed", "food": state.food, "delta": state.food - before})
		"quest":
			var q := StringName(str(e[1]))
			var stage: int = int(e[2])
			if stage <= int(state.quests.get(q, 0)): return out
			state.quests[q] = stage
			out.append({"type": "quest_changed", "quest": q, "stage": stage})
			if stage >= 100 and defs.has(&"quest", q):
				out.append_array(grant_xp(state, int(defs.get_def(&"quest", q).get("xp_on_done", 0)), defs))
		"page":
			var p := StringName(str(e[1]))
			if state.pages.has(p): return out
			state.pages.append(p)
			out.append({"type": "page_found", "page": p})
			if defs.has(&"page", p):
				out.append_array(grant_xp(state, int(defs.get_def(&"page", p).get("xp", 0)), defs))
		"xp":
			out.append_array(grant_xp(state, int(e[1]), defs))
		"recruit":
			out.append_array(recruit(state, StringName(str(e[1])), defs))
		"heal_party":
			for m in state.party:
				m.hp = m.max_hp; m.mana = m.max_mana; m.charge = m.max_charge
			out.append({"type": "healed_party"})
		"battle":
			out.append({"type": "battle_requested", "encounter": StringName(str(e[1]))})
		"shop":
			out.append({"type": "shop_requested", "shop": StringName(str(e[1]))})
		"discover":
			var lid := StringName(str(e[1]))
			var loc: Dictionary = location(lid, defs)
			if loc.is_empty():
				push_error("Rules: unknown location '%s'" % lid)
				return out
			if state.discovered.has(lid): return out
			state.discovered.append(lid)
			out.append({"type": "discovered", "location": lid})
			var cells: Array[Vector2i] = reveal_around(state, to_cell(loc.get("cell", [])), REVEAL_RADIUS, defs)
			if not cells.is_empty(): out.append({"type": "revealed", "cells": cells})
		"teleport":
			var lid := StringName(str(e[1]))
			var loc: Dictionary = location(lid, defs)
			if loc.is_empty():
				push_error("Rules: unknown location '%s'" % lid)
				return out
			state.world_pos = to_cell(loc.get("cell", []))
			out.append({"type": "teleported", "location": lid})
		"narrate":
			out.append({"type": "narrator", "line_key": str(e[1])})
		"roll":
			var stat: String = str(e[1])
			var dc: int = int(e[2])
			var total: int = rng.roll(20) + best_stat(state, stat)
			var passed: bool = total >= dc
			out.append({"type": "roll", "stat": stat, "dc": dc, "total": total, "passed": passed})
			var branch: Variant = e[3] if passed else e[4]
			if branch is Array: out.append_array(run(branch, state, rng, defs))
			else: push_error("Rules: roll branches must be effect lists")
	return out

## Gives `amount` XP to every party member (shared XP). Returns xp_gained/level_up events.
static func grant_xp(state: GameState, amount: int, defs: Defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if amount <= 0: return out
	for m in state.party:
		out.append_array(m.gain_xp(amount, _class_of(m, defs)))
	return out

static func _class_of(m: Character, defs: Defs) -> Dictionary:
	if defs.has(&"class", m.class_id): return defs.get_def(&"class", m.class_id)
	return {}

## Recruits an NPC as a new party member at the hero's level (CONTRACTS section 4).
static func recruit(state: GameState, npc_id: StringName, defs: Defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _member(state, npc_id) != null: return out
	if state.party.size() >= MAX_PARTY:
		out.append({"type": "toast", "text_key": "party_full"})
		return out
	var npc: Dictionary = defs.get_def(&"npc", npc_id)
	if npc.is_empty(): return out
	var cls: Dictionary = defs.get_def(&"class", StringName(str(npc.get("recruit_class", ""))))
	if cls.is_empty(): return out
	var c: Character = Character.create(npc_id, cls, str(npc.get("name_key", "")))
	var target: int = state.party[0].level if not state.party.is_empty() else 1
	while c.level < target: c.level_up(cls)
	state.party.append(c)
	out.append({"type": "recruited", "unit": npc_id})
	return out

## Reveals every cell within Chebyshev `radius` of `center` that lies inside world.size.
## Returns only the newly revealed cells. Used by ["discover"] and Game.new_game.
static func reveal_around(state: GameState, center: Vector2i, radius: int, defs: Defs) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var world: Variant = defs.json("world")
	var size := Vector2i(1 << 20, 1 << 20)
	if world is Dictionary and world.get("size") is Array and world.size.size() == 2:
		size = Vector2i(int(world.size[0]), int(world.size[1]))
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or y < 0 or x >= size.x or y >= size.y: continue
			var k: String = GameState.cell_key(Vector2i(x, y))
			if state.revealed.has(k): continue
			state.revealed[k] = true
			out.append(Vector2i(x, y))
	return out

## The world.json location with that id, or {}.
static func location(id: StringName, defs: Defs) -> Dictionary:
	var world: Variant = defs.json("world")
	if not (world is Dictionary): return {}
	for l in world.get("locations", []):
		if l is Dictionary and StringName(str(l.get("id", ""))) == id: return l
	return {}

## [x, y] to a cell; anything else is (0, 0).
static func to_cell(v: Variant) -> Vector2i:
	if v is Vector2i: return v
	if v is Array and v.size() == 2: return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO
