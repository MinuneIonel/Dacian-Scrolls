class_name Ufo
extends RefCounted

const DETECT_RADIUS: int = 5
const DETECT_RADIUS_NIGHT: int = 2
const LOSE_RADIUS: int = 8
const CHASE_SPEED: int = 2
## After a lost or fled UFO battle: party steps during which no UFO can spot the party.
const GRACE_FLAG: String = "ufo_grace"
const GRACE_STEPS: int = 6

## Advances every UFO one party-step. Emits ufo_moved and possibly abducted.
## patrol: 1 cell (8-way) toward route[route_i], advancing route_i on arrival, looping.
## Detection (Chebyshev <= 5, 2 at night, party not on hiding terrain) switches to chase,
## unless flags["decoy_charm"] is true, which is cleared instead. chase: 2 cells toward the
## party; back to patrol when the party hides or is >= 8 cells away. A chasing UFO on the
## party's cell abducts (at most one abducted event per tick). "gone" UFOs never act.
## While flags["ufo_grace"] > 0 (counted down once per tick) the party counts as hidden.
static func tick(state: GameState, rng: Rng, defs: Defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var party: Vector2i = state.world_pos
	var grace: int = int(state.flags.get(GRACE_FLAG, 0))
	if grace > 0:
		if grace > 1: state.flags[GRACE_FLAG] = grace - 1
		else: state.flags.erase(GRACE_FLAG)
	var hidden: bool = Travel.hides(party, defs) or grace > 0
	var radius: int = DETECT_RADIUS_NIGHT if state.is_night() else DETECT_RADIUS
	var abducted: bool = false
	for u in state.ufos:
		var st: String = str(u.get("state", "patrol"))
		if st == "gone": continue
		var pos: Vector2i = Rules.to_cell(u.get("pos", Vector2i.ZERO))
		var old_pos: Vector2i = pos
		var old_st: String = st
		var dist: int = Travel._cheb(pos, party)
		if st == "chase" and (hidden or dist >= LOSE_RADIUS):
			st = "patrol"
		elif st == "patrol" and not hidden and dist <= radius:
			if state.flags.get("decoy_charm", false) == true:
				state.flags["decoy_charm"] = false
				out.append({"type": "flag_set", "flag": "decoy_charm", "value": false})
			else:
				st = "chase"
		if st == "chase":
			pos = _toward(pos, party, CHASE_SPEED)
		else:
			var route: Array = _route(u, defs)
			if not route.is_empty():
				var ri: int = posmod(int(u.get("route_i", 0)), route.size())
				if pos == Rules.to_cell(route[ri]): ri = (ri + 1) % route.size()
				pos = _toward(pos, Rules.to_cell(route[ri]), 1)
				u["route_i"] = ri
		u["pos"] = pos
		u["state"] = st
		if pos != old_pos or st != old_st:
			out.append({"type": "ufo_moved", "id": u.get("id", &""), "pos": pos, "state": st})
		if st == "chase" and pos == party and not abducted:
			abducted = true
			out.append({"type": "abducted", "ufo": u.get("id", &""), "encounter": _encounter(u, defs)})
	return out

## Moves up to `cells` 8-way steps from a toward b.
static func _toward(a: Vector2i, b: Vector2i, cells: int) -> Vector2i:
	var p: Vector2i = a
	for i in cells:
		if p == b: break
		p += Vector2i(signi(b.x - p.x), signi(b.y - p.y))
	return p

## The world.json ufo entry with this UFO's id, or {}.
static func def_of(u: Dictionary, defs: Defs) -> Dictionary:
	var w: Variant = defs.json("world")
	if not (w is Dictionary): return {}
	for d in w.get("ufos", []):
		if d is Dictionary and str(d.get("id", "")) == str(u.get("id", "")): return d
	return {}

static func _route(u: Dictionary, defs: Defs) -> Array:
	var r: Variant = def_of(u, defs).get("route", [])
	return r if r is Array else []

static func _encounter(u: Dictionary, defs: Defs) -> StringName:
	return StringName(str(def_of(u, defs).get("encounter", "")))
