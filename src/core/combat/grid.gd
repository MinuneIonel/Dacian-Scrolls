## A rectangular tactical grid: walkability and cover per cell. 4-way movement only.
class_name Grid
extends RefCounted

var size: Vector2i
var _walkable: PackedByteArray
var _cover: PackedByteArray   # 0, 20 or 40

func _init(grid_size: Vector2i = Vector2i(1, 1)) -> void:
	size = grid_size
	_walkable = PackedByteArray(); _walkable.resize(size.x * size.y); _walkable.fill(1)
	_cover = PackedByteArray(); _cover.resize(size.x * size.y); _cover.fill(0)

## Builds a grid from a map definition and data/tiles.json (Defs.json("tiles")).
static func from_map(map_def: Dictionary, tiles: Dictionary) -> Grid:
	var rows: Array = map_def.get("ground", [])
	var legend: Dictionary = map_def.get("legend", {})
	var w: int = 0
	for r in rows: w = maxi(w, str(r).length())
	var g := Grid.new(Vector2i(maxi(1, w), maxi(1, rows.size())))
	for y in rows.size():
		var row: String = str(rows[y])
		for x in g.size.x:
			var tile: Dictionary = {}
			if x < row.length():
				var tid: String = str(legend.get(row[x], ""))
				var t: Variant = tiles.get(tid, {})
				if t is Dictionary: tile = t
			g.set_walkable(Vector2i(x, y), bool(tile.get("walkable", false)))
			g.set_cover(Vector2i(x, y), int(tile.get("cover", 0)))
	return g

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y

func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and _walkable[c.y * size.x + c.x] == 1

func set_walkable(c: Vector2i, v: bool) -> void:
	if in_bounds(c): _walkable[c.y * size.x + c.x] = 1 if v else 0

func cover_at(c: Vector2i) -> int:
	return _cover[c.y * size.x + c.x] if in_bounds(c) else 0

func set_cover(c: Vector2i, v: int) -> void:
	if in_bounds(c): _cover[c.y * size.x + c.x] = v

## Can a unit of footprint `unit_size` (1 or 2, anchored at its top-left cell) stand at c,
## ignoring the cells in `occupied` (Dictionary Vector2i -> true)?
func fits(c: Vector2i, unit_size: int, occupied: Dictionary = {}) -> bool:
	for dy in unit_size:
		for dx in unit_size:
			var p := Vector2i(c.x + dx, c.y + dy)
			if not is_walkable(p) or occupied.has(p): return false
	return true

## Every cell reachable with `ap` points: Dictionary Vector2i -> cost. Includes `from` at 0.
func reachable(from: Vector2i, ap: int, unit_size: int, occupied: Dictionary = {}, cost_per_cell: int = 1) -> Dictionary:
	return search(from, ap, unit_size, occupied, cost_per_cell)["cost"]

## The 4 step directions, in the fixed order every search uses (keeps results deterministic).
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Dijkstra from `from` within `budget` (budget < 0: unlimited). `extra` maps a cell to an added
## cost for stepping onto it. Returns {cost: {cell: int}, parent: {cell: previous cell}}.
func search(from: Vector2i, budget: int, unit_size: int, occupied: Dictionary = {},
		cost_per_cell: int = 1, extra: Dictionary = {}) -> Dictionary:
	var cost: Dictionary = {from: 0}
	var parent: Dictionary = {}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var best_i: int = 0
		for i in range(1, frontier.size()):
			if cost[frontier[i]] < cost[frontier[best_i]]: best_i = i
		var cur: Vector2i = frontier[best_i]
		frontier.remove_at(best_i)
		for d in DIRS:
			var nxt: Vector2i = cur + d
			var nc: int = cost[cur] + cost_per_cell + int(extra.get(nxt, 0))
			if budget >= 0 and nc > budget: continue
			if cost.has(nxt) and cost[nxt] <= nc: continue
			if not fits(nxt, unit_size, occupied): continue
			if not cost.has(nxt): frontier.append(nxt)
			cost[nxt] = nc
			parent[nxt] = cur
	return {"cost": cost, "parent": parent}

## Rebuilds the steps (excluding the start) to `to` from a search() parent map.
static func path_from(parent: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if to == from or not parent.has(to): return out
	var c: Vector2i = to
	while c != from:
		out.push_front(c)
		c = parent[c]
	return out
