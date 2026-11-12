## World map movement. Terrain costs and chances come from Defs.json("world").
class_name Travel
extends RefCounted

## Path from state.world_pos to `to`, excluding the start. Empty when unreachable.
static func path(state: GameState, to: Vector2i, defs: Defs) -> Array[Vector2i]:
	push_error("not implemented: Travel.path")  # WP-13
	return []

## Moves one cell. Advances time, eats food, reveals fog, discovers, rolls encounters,
## ticks UFOs. Callers stop the journey on an encounter, abducted or discovered event.
static func step(state: GameState, next: Vector2i, rng: Rng, defs: Defs) -> Array[Dictionary]:
	push_error("not implemented: Travel.step")  # WP-13
	return []

## Terrain id at a world cell ("road", "plains", "forest", "mountain", "river").
static func terrain_at(c: Vector2i, defs: Defs) -> String:
	push_error("not implemented: Travel.terrain_at")  # WP-13
	return ""
