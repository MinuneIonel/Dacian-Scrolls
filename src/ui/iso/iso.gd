## Isometric projection for 64x32 diamond tiles. Cell (0,0) is the top corner of the map.
class_name Iso
extends RefCounted

const TILE_W: int = 64
const TILE_H: int = 32

## Diamond centre of a cell, in map-local pixels.
static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2((c.x - c.y) * (TILE_W / 2), (c.x + c.y) * (TILE_H / 2))

## Centre of a footprint of size n anchored at its top-left cell (n = 2 for giants).
static func footprint_center(c: Vector2i, n: int) -> Vector2:
	return (cell_to_world(c) + cell_to_world(c + Vector2i(n - 1, n - 1))) / 2.0

static func world_to_cell(p: Vector2) -> Vector2i:
	var fx: float = p.x / float(TILE_W / 2)
	var fy: float = p.y / float(TILE_H / 2)
	return Vector2i(roundi((fy + fx) / 2.0), roundi((fy - fx) / 2.0))

## Screen-facing direction from a to b: "se", "sw", "ne" or "nw". Sprites are drawn SE and NE;
## SW and NW are their horizontal flips.
static func facing(a: Vector2i, b: Vector2i) -> String:
	var d: Vector2 = cell_to_world(b) - cell_to_world(a)
	var south: bool = d.y >= 0
	var east: bool = d.x >= 0
	return ("s" if south else "n") + ("e" if east else "w")

## Draw order for y-sorting tall things and units: larger is in front.
static func depth(c: Vector2i) -> int:
	return (c.x + c.y) * 16
