class_name Fog
extends RefCounted

## Reveals every cell within Chebyshev radius of center that is inside the world.
## Returns only the newly revealed cells.
static func reveal(state: GameState, center: Vector2i, radius: int, world_size: Vector2i) -> Array[Vector2i]:
	push_error("not implemented: Fog.reveal")  # WP-13
	return []

static func is_revealed(state: GameState, c: Vector2i) -> bool:
	return state.revealed.has(GameState.cell_key(c))
