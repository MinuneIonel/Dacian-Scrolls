## Flat cell markings drawn between the ground tiles and the units: hazards, reachable cells,
## the path preview, ability targets and area previews, and the hovered cell.
extends Node2D

const MOVE_FILL := Color(0.92, 0.86, 0.70, 0.18)
const MOVE_EDGE := Color(0.92, 0.86, 0.70, 0.45)
const PATH_FILL := Color(0.88, 0.67, 0.36, 0.55)
const TARGET_FILL := Color(0.80, 0.20, 0.18, 0.30)
const TARGET_EDGE := Color(1.0, 0.45, 0.35, 0.9)
const ALLY_FILL := Color(0.45, 0.80, 0.40, 0.30)
const ALLY_EDGE := Color(0.60, 0.95, 0.50, 0.9)
const AREA_FILL := Color(1.0, 0.60, 0.20, 0.35)
const HOVER_EDGE := Color(1.0, 0.95, 0.75, 0.95)
const HAZARD_COLORS: Dictionary = {
	"acid": Color(0.55, 0.95, 0.25, 0.45),
	"gravity_zone": Color(0.37, 0.95, 0.90, 0.30),
	"specimen_tank": Color(0.37, 0.95, 0.90, 0.20),
}

var move_cells: Dictionary = {}     # Vector2i -> true
var path_cells: Array[Vector2i] = []
var target_cells: Dictionary = {}   # Vector2i -> true
var target_friendly: bool = false
var area_cells: Array[Vector2i] = []
var hover_cell: Vector2i = Vector2i(-99, -99)
var hazards: Dictionary = {}        # Vector2i -> {hazard_kind: turns}
var _tanks: Dictionary = {}         # Vector2i -> Node2D (drawn in the sorted layer)
var sorted_layer: Node2D

func clear_marks() -> void:
	move_cells = {}
	path_cells.clear()
	target_cells = {}
	area_cells.clear()
	queue_redraw()

func set_hover(c: Vector2i) -> void:
	if c == hover_cell: return
	hover_cell = c
	queue_redraw()

## kind "" removes nothing; turns 0 removes the hazard.
func set_hazard(c: Vector2i, kind: String, turns: int) -> void:
	var at: Dictionary = hazards.get(c, {})
	if turns <= 0: at.erase(kind)
	else: at[kind] = turns
	if at.is_empty(): hazards.erase(c)
	else: hazards[c] = at
	if kind == "specimen_tank": _sync_tank(c, turns > 0)
	queue_redraw()

func has_hazard(c: Vector2i, kind: String) -> bool:
	return hazards.has(c) and (hazards[c] as Dictionary).has(kind)

func _sync_tank(c: Vector2i, on: bool) -> void:
	if on and not _tanks.has(c) and sorted_layer != null:
		var b: Node2D = MapBuilder.block(Color("3a6a70"), 26)
		b.modulate = Color(1, 1, 1, 0.85)
		b.position = Iso.cell_to_world(c)
		b.name = "Tank_%d_%d" % [c.x, c.y]
		sorted_layer.add_child(b)
		_tanks[c] = b
	elif not on and _tanks.has(c):
		(_tanks[c] as Node).queue_free()
		_tanks.erase(c)

func _draw() -> void:
	for c in hazards:
		for kind in hazards[c]:
			_diamond(c, HAZARD_COLORS.get(kind, Color(1, 0, 1, 0.3)), Color(0, 0, 0, 0), 0.8)
	for c in move_cells:
		_diamond(c, MOVE_FILL, MOVE_EDGE, 0.86)
	for c in path_cells:
		_diamond(c, PATH_FILL, Color(0, 0, 0, 0), 0.6)
	for c in target_cells:
		_diamond(c, ALLY_FILL if target_friendly else TARGET_FILL, ALLY_EDGE if target_friendly else TARGET_EDGE, 0.9)
	for c in area_cells:
		_diamond(c, AREA_FILL, TARGET_EDGE, 0.8)
	if hover_cell.x > -99:
		_diamond(hover_cell, Color(0, 0, 0, 0), HOVER_EDGE, 1.0)

func _diamond(c: Vector2i, fill: Color, edge: Color, scale_f: float) -> void:
	var o: Vector2 = Iso.cell_to_world(c)
	var hw: float = 32.0 * scale_f
	var hh: float = 16.0 * scale_f
	var pts := PackedVector2Array([o + Vector2(0, -hh), o + Vector2(hw, 0), o + Vector2(0, hh), o + Vector2(-hw, 0)])
	if fill.a > 0.0: draw_colored_polygon(pts, fill)
	if edge.a > 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, edge, 1.0, false)
