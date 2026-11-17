## Everything that is saved. Every mode reads and writes this one object.
class_name GameState
extends RefCounted

const VERSION: int = 1

var version: int = VERSION
var seed: int = 0
var rng_state: int = 0
var day: int = 1
var hour: int = 8                      # 0..23; night is hour >= 20 or hour <= 5
var food: int = 0
var gold: int = 0
var party: Array[Character] = []       # index 0 is the hero, max 4
var inventory: Dictionary = {}         # StringName item_id -> int count
var flags: Dictionary = {}             # String -> Variant
var quests: Dictionary = {}            # StringName quest_id -> int stage (0 none, 100 done)
var pages: Array[StringName] = []      # scroll pages in the order found
var world_pos: Vector2i = Vector2i.ZERO
var revealed: Dictionary = {}          # "x,y" -> true
var discovered: Array[StringName] = [] # location ids
var ufos: Array[Dictionary] = []       # {id: StringName, pos: Vector2i, state: "patrol"|"chase"|"gone", route_i: int}
var mode: StringName = &"worldmap"     # the mode to resume in
var location_id: StringName = &""
var location_cell: Vector2i = Vector2i.ZERO

func is_night() -> bool:
	return hour >= 20 or hour <= 5

static func cell_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]

## JSON-safe: Vector2i become [x, y], ids strings, and seed/rng_state decimal strings
## (64-bit ints do not survive JSON numbers).
func to_dict() -> Dictionary:
	var inv: Dictionary = {}
	for k in inventory: inv[str(k)] = int(inventory[k])
	var q: Dictionary = {}
	for k in quests: q[str(k)] = int(quests[k])
	var u: Array = []
	for x in ufos:
		var pos: Vector2i = x.get("pos", Vector2i.ZERO)
		u.append({"id": str(x.get("id", "")), "pos": [pos.x, pos.y],
			"state": str(x.get("state", "patrol")), "route_i": int(x.get("route_i", 0))})
	return {
		"version": version, "seed": str(seed), "rng_state": str(rng_state),
		"day": day, "hour": hour, "food": food, "gold": gold,
		"party": party.map(func(c: Character) -> Dictionary: return c.to_dict()),
		"inventory": inv, "flags": flags.duplicate(true), "quests": q,
		"pages": pages.map(func(p: StringName) -> String: return str(p)),
		"world_pos": [world_pos.x, world_pos.y], "revealed": revealed.duplicate(),
		"discovered": discovered.map(func(p: StringName) -> String: return str(p)),
		"ufos": u, "mode": str(mode), "location_id": str(location_id),
		"location_cell": [location_cell.x, location_cell.y],
	}

## Lenient: missing fields get defaults. SaveCodec validates untrusted input first.
static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.version = int(d.get("version", VERSION))
	s.seed = _to_int(d.get("seed", 0))
	s.rng_state = _to_int(d.get("rng_state", 0))
	s.day = int(d.get("day", 1))
	s.hour = int(d.get("hour", 8))
	s.food = int(d.get("food", 0))
	s.gold = int(d.get("gold", 0))
	for c in d.get("party", []): s.party.append(Character.from_dict(c))
	var inv: Dictionary = d.get("inventory", {})
	for k in inv: s.inventory[StringName(str(k))] = int(inv[k])
	var fl: Dictionary = d.get("flags", {})
	for k in fl: s.flags[str(k)] = fl[k]
	var q: Dictionary = d.get("quests", {})
	for k in q: s.quests[StringName(str(k))] = int(q[k])
	for p in d.get("pages", []): s.pages.append(StringName(str(p)))
	s.world_pos = _to_cell(d.get("world_pos", []))
	var rv: Dictionary = d.get("revealed", {})
	for k in rv: s.revealed[str(k)] = true
	for p in d.get("discovered", []): s.discovered.append(StringName(str(p)))
	for x in d.get("ufos", []):
		s.ufos.append({"id": StringName(str(x.get("id", ""))), "pos": _to_cell(x.get("pos", [])),
			"state": str(x.get("state", "patrol")), "route_i": int(x.get("route_i", 0))})
	s.mode = StringName(str(d.get("mode", "worldmap")))
	s.location_id = StringName(str(d.get("location_id", "")))
	s.location_cell = _to_cell(d.get("location_cell", []))
	return s

## [x, y] (or a Vector2i) to a cell; anything else is (0, 0).
static func _to_cell(v: Variant) -> Vector2i:
	if v is Vector2i: return v
	if v is Array and v.size() == 2: return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO

static func _to_int(v: Variant) -> int:
	if v is String: return (v as String).to_int()
	if v is int or v is float: return int(v)
	return 0
