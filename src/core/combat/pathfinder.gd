## Shortest 4-way paths on a Grid.
class_name Pathfinder
extends RefCounted

## Cells from the step after `from` up to and including `to`. Empty when unreachable or from == to.
static func path(grid: Grid, from: Vector2i, to: Vector2i, unit_size: int, occupied: Dictionary = {}) -> Array[Vector2i]:
	push_error("not implemented: Pathfinder.path")  # WP-12
	return []
