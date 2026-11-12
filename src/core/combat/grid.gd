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
	push_error("not implemented: Grid.from_map")  # WP-12
	return Grid.new()

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
	push_error("not implemented: Grid.fits")  # WP-12
	return false

## Every cell reachable with `ap` points: Dictionary Vector2i -> cost. Includes `from` at 0.
func reachable(from: Vector2i, ap: int, unit_size: int, occupied: Dictionary = {}, cost_per_cell: int = 1) -> Dictionary:
	push_error("not implemented: Grid.reachable")  # WP-12
	return {}
