## World map terrain, route and location markers. Draws terrain only on revealed cells;
## everything else stays the dark backdrop. Reads Game.state; never changes it.
extends Node2D

const CELL: int = 16
const ROUTE := Color("c40e2c")       # palette blood: a hand-inked route
const ROUTE_HI := Color("f4efe2")    # palette white
const PLATE := Color(0.118, 0.086, 0.067, 0.82)
## Flat colours when the generated map texture is missing.
const FALLBACK: Dictionary = {
	"road": Color("b88550"), "plains": Color("efd391"), "forest": Color("466a32"),
	"mountain": Color("8a5a34"), "river": Color("344f86"),
}

var defs: Defs
var terrain_tex: Texture2D
var marker_tex: Dictionary = {}      # marker id -> Texture2D
## The previewed or remaining route, in cells (excluding the party's cell).
var route: Array[Vector2i] = []
## Cells drawn with terrain on the last _draw (for tests: equals the revealed count).
var drawn_cells: int = 0
## false: terrain on revealed cells (below the fog). true: route and markers (above it).
var overlay: bool = false

func setup(d: Defs, terrain: Texture2D, markers: Dictionary) -> void:
	defs = d
	terrain_tex = terrain
	marker_tex = markers
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func world_size() -> Vector2i:
	return Travel.world_size(defs) if defs != null else Vector2i.ZERO

func _draw() -> void:
	drawn_cells = 0
	if defs == null: return
	var size: Vector2i = world_size()
	var st: GameState = Game.state
	if overlay:
		_draw_route(st)
		_draw_markers(st)
		return
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if not Fog.is_revealed(st, c): continue
			var r := Rect2(c * CELL, Vector2(CELL, CELL))
			if terrain_tex != null:
				draw_texture_rect_region(terrain_tex, r, r)
			else:
				draw_rect(r, FALLBACK.get(Travel.terrain_at(c, defs), Color.BLACK))
			drawn_cells += 1

func _draw_route(st: GameState) -> void:
	if route.is_empty(): return
	var prev: Vector2 = _center(st.world_pos)
	var carry: float = 0.0
	for c in route:
		var p: Vector2 = _center(c)
		var seg: float = prev.distance_to(p)
		var t: float = carry
		while t < seg:
			var q: Vector2 = prev.lerp(p, t / seg).floor()
			draw_rect(Rect2(q - Vector2(1, 1), Vector2(4, 4)), ROUTE_HI)
			draw_rect(Rect2(q, Vector2(2, 2)), ROUTE)
			t += 6.0
		carry = t - seg
		prev = p
	# An X marks the destination.
	var d: Vector2 = _center(route[-1]).floor()
	for k in range(-4, 5):
		draw_rect(Rect2(d + Vector2(k - 1, k - 1), Vector2(4, 4)), ROUTE_HI)
		draw_rect(Rect2(d + Vector2(k - 1, -k - 1), Vector2(4, 4)), ROUTE_HI)
	for k in range(-4, 5):
		draw_rect(Rect2(d + Vector2(k, k), Vector2(2, 2)), ROUTE)
		draw_rect(Rect2(d + Vector2(k, -k), Vector2(2, 2)), ROUTE)

func _draw_markers(st: GameState) -> void:
	var font: Font = UiKit.font()
	for loc in visible_locations():
		var cell: Vector2i = Rules.to_cell(loc.get("cell", []))
		var tex: Texture2D = marker_tex.get(str(loc.get("marker", "")))
		var base := Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL - 1)
		if tex != null:
			var s: Vector2 = tex.get_size()
			draw_texture(tex, (base - Vector2(s.x / 2.0, s.y)).floor())
		else:
			draw_rect(Rect2(base - Vector2(5, 10), Vector2(10, 10)), UiKit.BRONZE)
		var text: String = tr(str(loc.get("name_key", "")))
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE).x
		var top := Vector2(floorf(base.x - w / 2.0), base.y + 3)
		draw_rect(Rect2(top - Vector2(3, 1), Vector2(w + 6, 11)), PLATE)
		draw_rect(Rect2(top - Vector2(3, 1), Vector2(w + 6, 11)), Color(UiKit.BRONZE, 0.9), false, 1.0)
		draw_string(font, top + Vector2(0, font.get_ascent(UiKit.FONT_SIZE)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE, UiKit.PARCHMENT)

## Discovered locations only: hidden or undiscovered ones are never drawn.
func visible_locations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var w: Variant = defs.json("world") if defs != null else null
	if not (w is Dictionary): return out
	for loc in w.get("locations", []):
		if loc is Dictionary and Game.state.discovered.has(StringName(str(loc.get("id", "")))):
			out.append(loc)
	return out

static func _center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0)
