class_name Fog
extends RefCounted

## Fog radius around the party after every step (Chebyshev).
const RADIUS: int = 2

## Reveals every cell within Chebyshev radius of center that is inside the world.
## Returns only the newly revealed cells.
static func reveal(state: GameState, center: Vector2i, radius: int, world_size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or y < 0 or x >= world_size.x or y >= world_size.y: continue
			var c := Vector2i(x, y)
			var k: String = GameState.cell_key(c)
			if state.revealed.has(k): continue
			state.revealed[k] = true
			out.append(c)
	return out

static func is_revealed(state: GameState, c: Vector2i) -> bool:
	return state.revealed.has(GameState.cell_key(c))
