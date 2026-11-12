## World map movement. Terrain costs and chances come from Defs.json("world").
class_name Travel
extends RefCounted

## Steps without an encounter roll after an encounter or abduction (flags["enc_cooldown"]).
const ENC_COOLDOWN: int = 3
## Chebyshev radius in which non-hidden locations are discovered.
const DISCOVER_RADIUS: int = 1
## HP each party member loses per day without food (never below 1).
const STARVE_HP: int = 2
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

## Path from state.world_pos to `to`, excluding the start. Empty when unreachable.
## 4-way, over passable terrain, fewest hours first (Dijkstra; ties resolved deterministically).
static func path(state: GameState, to: Vector2i, defs: Defs) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var from: Vector2i = state.world_pos
	if from == to or not passable(to, defs) or not in_world(from, defs): return out
	var size: Vector2i = world_size(defs)
	var n: int = size.x * size.y
	var dist := PackedInt32Array(); dist.resize(n); dist.fill(-1)
	var prev := PackedInt32Array(); prev.resize(n); prev.fill(-1)
	var done := PackedByteArray(); done.resize(n); done.fill(0)
	var start_i: int = from.y * size.x + from.x
	var goal_i: int = to.y * size.x + to.x
	dist[start_i] = 0
	var open: Array[int] = [start_i]
	while not open.is_empty():
		# Pick the open cell with the lowest cost (first one on ties): small grids, O(n^2) is fine.
		var bi: int = 0
		for i in range(1, open.size()):
			if dist[open[i]] < dist[open[bi]]: bi = i
		var cur: int = open[bi]
		open.remove_at(bi)
		if done[cur] == 1: continue
		done[cur] = 1
		if cur == goal_i: break
		var cc := Vector2i(cur % size.x, cur / size.x)
		for d in DIRS:
			var nc: Vector2i = cc + d
			if not passable(nc, defs): continue
			var ni: int = nc.y * size.x + nc.x
			if done[ni] == 1: continue
			var nd: int = dist[cur] + hours_at(nc, defs)
			if dist[ni] == -1 or nd < dist[ni]:
				dist[ni] = nd
				prev[ni] = cur
				open.append(ni)
	if dist[goal_i] == -1: return out
	var i: int = goal_i
	while i != start_i:
		out.push_front(Vector2i(i % size.x, i / size.x))
		i = prev[i]
	return out

## Moves one cell. Advances time, eats food, reveals fog, discovers, rolls encounters,
## ticks UFOs. Callers stop the journey on an encounter, abducted or discovered event.
## A step that is not to a passable 4-neighbour of world_pos does nothing and returns [].
static func step(state: GameState, next: Vector2i, rng: Rng, defs: Defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not passable(next, defs) or not DIRS.has(next - state.world_pos): return out
	var terrain: String = terrain_at(next, defs)
	var rule: Dictionary = _rule(terrain, defs)
	var hours: int = maxi(0, int(rule.get("hours", 1)))
	state.world_pos = next
	out.append({"type": "stepped", "pos": next, "hours": hours})
	out.append_array(advance_time(state, hours))
	var cells: Array[Vector2i] = Fog.reveal(state, next, Fog.RADIUS, world_size(defs))
	if not cells.is_empty(): out.append({"type": "revealed", "cells": cells})
	var on_location: bool = false
	for loc in _locations(defs):
		var id := StringName(str(loc.get("id", "")))
		var lc: Vector2i = Rules.to_cell(loc.get("cell", []))
		if not bool(loc.get("hidden", false)) and not state.discovered.has(id) \
				and _cheb(lc, next) <= DISCOVER_RADIUS:
			state.discovered.append(id)
			out.append({"type": "discovered", "location": id})
		if lc == next:
			on_location = true
			if state.discovered.has(id): out.append({"type": "arrived", "location": id})
	var cooldown: int = int(state.flags.get("enc_cooldown", 0))
	if cooldown > 0:
		state.flags["enc_cooldown"] = cooldown - 1
	elif not on_location and rng.chance(float(rule.get("encounter_chance", 0.0))):
		var table: Variant = _world(defs).get("tables", {}).get(terrain, [])
		var pick: Dictionary = rng.pick_weighted(table) if table is Array else {}
		if not pick.is_empty():
			state.flags["enc_cooldown"] = ENC_COOLDOWN
			out.append({"type": "encounter", "encounter": StringName(str(pick.get("encounter", "")))})
	var ufo_events: Array[Dictionary] = Ufo.tick(state, rng, defs)
	for e in ufo_events:
		if e.type == "abducted": state.flags["enc_cooldown"] = ENC_COOLDOWN
	out.append_array(ufo_events)
	return out

## Advances the clock. Each midnight crossed: day + 1 and the party eats 1 food each;
## when short, food goes to 0 and every member loses STARVE_HP (never below 1).
static func advance_time(state: GameState, hours: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if hours <= 0: return out
	for h in hours:
		state.hour += 1
		if state.hour < 24: continue
		state.hour = 0
		state.day += 1
		var need: int = state.party.size()
		var before: int = state.food
		state.food = maxi(0, state.food - need)
		if state.food != before:
			out.append({"type": "food_changed", "food": state.food, "delta": state.food - before})
		if before < need:
			for m in state.party:
				if m.hp > 1: m.hp = maxi(1, m.hp - STARVE_HP)
			out.append({"type": "starved", "amount": STARVE_HP})
	out.append({"type": "time_changed", "day": state.day, "hour": state.hour})
	return out

## Terrain id at a world cell ("road", "plains", "forest", "mountain", "river").
## "" outside the world or for an unknown legend char.
static func terrain_at(c: Vector2i, defs: Defs) -> String:
	if not in_world(c, defs): return ""
	var world: Dictionary = _world(defs)
	var rows: Variant = world.get("terrain", [])
	if not (rows is Array) or c.y >= rows.size(): return ""
	var row: String = str(rows[c.y])
	if c.x >= row.length(): return ""
	return str(world.get("legend", {}).get(row[c.x], ""))

static func passable(c: Vector2i, defs: Defs) -> bool:
	var t: String = terrain_at(c, defs)
	if t == "": return false
	return bool(_rule(t, defs).get("passable", false))

static func hours_at(c: Vector2i, defs: Defs) -> int:
	return maxi(0, int(_rule(terrain_at(c, defs), defs).get("hours", 1)))

## True when the terrain at c hides the party from UFOs.
static func hides(c: Vector2i, defs: Defs) -> bool:
	return bool(_rule(terrain_at(c, defs), defs).get("hides", false))

static func in_world(c: Vector2i, defs: Defs) -> bool:
	var s: Vector2i = world_size(defs)
	return c.x >= 0 and c.y >= 0 and c.x < s.x and c.y < s.y

static func world_size(defs: Defs) -> Vector2i:
	var size: Variant = _world(defs).get("size", [])
	if size is Array and size.size() == 2: return Vector2i(int(size[0]), int(size[1]))
	return Vector2i.ZERO

static func _world(defs: Defs) -> Dictionary:
	var w: Variant = defs.json("world")
	return w if w is Dictionary else {}

static func _rule(terrain: String, defs: Defs) -> Dictionary:
	var r: Variant = _world(defs).get("terrain_rules", {}).get(terrain, {})
	return r if r is Dictionary else {}

static func _locations(defs: Defs) -> Array:
	var l: Variant = _world(defs).get("locations", [])
	return l if l is Array else []

static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
