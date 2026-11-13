## Shortest 4-way paths on a Grid.
class_name Pathfinder
extends RefCounted

## Cells from the step after `from` up to and including `to`. Empty when unreachable or from == to.
static func path(grid: Grid, from: Vector2i, to: Vector2i, unit_size: int, occupied: Dictionary = {}) -> Array[Vector2i]:
	if from == to or not grid.fits(to, unit_size, occupied): return []
	var res: Dictionary = grid.search(from, -1, unit_size, occupied)
	return Grid.path_from(res["parent"], from, to)
