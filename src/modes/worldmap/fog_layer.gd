## Fog of war over the world map: unrevealed cells fully dark, with a dithered soft edge that
## creeps half a cell into the revealed side. Rebuilt from Game.state.revealed by rebuild().
extends Node2D

const CELL: int = 16
## Fog texels per cell (each texel is CELL / SUB pixels wide).
const SUB: int = 4
const COLOR := Color("120c09")
const BAYER: Array[float] = [0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0]

var size: Vector2i = Vector2i.ZERO
var image: Image
var texture: ImageTexture

func setup(world_size: Vector2i) -> void:
	size = world_size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rebuild()

func rebuild() -> void:
	if size.x <= 0 or size.y <= 0: return
	var st: GameState = Game.state
	var cells := PackedFloat32Array()
	cells.resize(size.x * size.y)
	for y in size.y:
		for x in size.x:
			cells[y * size.x + x] = 0.0 if st.revealed.has(GameState.cell_key(Vector2i(x, y))) else 1.0
	var w: int = size.x * SUB
	var h: int = size.y * SUB
	if image == null or image.get_width() != w or image.get_height() != h:
		image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for py in h:
		var v: float = (py + 0.5) / SUB - 0.5
		var y0: int = floori(v)
		var ty: float = v - y0
		for px in w:
			var u: float = (px + 0.5) / SUB - 0.5
			var x0: int = floori(u)
			var tx: float = u - x0
			var f: float = lerpf(lerpf(_at(cells, x0, y0), _at(cells, x0 + 1, y0), tx),
				lerpf(_at(cells, x0, y0 + 1), _at(cells, x0 + 1, y0 + 1), tx), ty)
			var own: float = cells[clampi(py / SUB, 0, size.y - 1) * size.x + clampi(px / SUB, 0, size.x - 1)]
			var a: float
			if own >= 1.0:
				a = 1.0   # an unrevealed cell is always fully dark
			else:
				var b: float = (BAYER[(py % 4) * 4 + (px % 4)] + 0.5) / 16.0
				a = minf(1.0, floorf(minf(1.0, f * 1.8) * 4.0 + b) / 4.0) * 0.94
			image.set_pixel(px, py, Color(COLOR, a))
	if texture == null: texture = ImageTexture.create_from_image(image)
	else: texture.update(image)
	queue_redraw()

## Fog opacity at a cell's centre (0 clear, 1 dark). For tests and UFO visibility.
func alpha_at(c: Vector2i) -> float:
	if image == null or c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y: return 1.0
	return image.get_pixel(c.x * SUB + SUB / 2, c.y * SUB + SUB / 2).a

func _at(cells: PackedFloat32Array, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= size.x or y >= size.y: return 1.0
	return cells[y * size.x + x]

func _draw() -> void:
	if texture == null: return
	draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(size * CELL)), false)
