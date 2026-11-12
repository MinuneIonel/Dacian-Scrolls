## Title screen backdrop, drawn with polygons: a dusk sky, the Carpathians, the walls of
## Sarmizegetusa on a hill, and a saucer drifting across with a cyan beam it should not have.
class_name MenuBackground
extends Control

const SKY: Array[Color] = [Color("0d0a12"), Color("140e18"), Color("1d131d"), Color("2a1a22"), Color("3a2228"), Color("4e2c2a")]
const FAR := Color("2b1c22")
const MID := Color("1f1418")
const NEAR := Color("150e10")
const STAR := Color("eadbb4")
const MOON := Color("e8d8b0")
const SAUCER := Color("0b080a")
const SAUCER_RIM := Color("6d7a7c")
const CYAN := UiKit.CYAN
const CROSS_S: float = 38.0   # seconds for the saucer to cross the screen

var t: float = 0.0
var _stars: PackedVector2Array = PackedVector2Array()
var _far: PackedVector2Array
var _mid: PackedVector2Array
var _near: PackedVector2Array
var _built_for: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t = 9.0   # start with the saucer already on screen

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _build(sz: Vector2) -> void:
	_built_for = sz
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	_stars.clear()
	for i in 70:
		_stars.append(Vector2(rng.randi_range(0, int(sz.x) - 1), rng.randi_range(0, int(sz.y * 0.55))))
	_far = _ridge(sz, sz.y * 0.60, 58.0, 0.017, 1.3)
	_mid = _ridge(sz, sz.y * 0.72, 30.0, 0.029, 4.1)
	_near = _ridge(sz, sz.y * 0.84, 12.0, 0.05, 7.7)

## Jagged ridge line closed along the bottom edge. Points snap to whole pixels.
func _ridge(sz: Vector2, base_y: float, amp: float, freq: float, phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, sz.y))
	var x: float = 0.0
	var step: float = 8.0
	while x <= sz.x + step:
		var h: float = sin(x * freq + phase) * 0.6 + sin(x * freq * 2.7 + phase * 2.0) * 0.3 + sin(x * freq * 6.1) * 0.1
		pts.append(Vector2(floorf(x), floorf(base_y - absf(h) * amp)))
		x += step
	pts.append(Vector2(sz.x + step, sz.y))
	return pts

func _draw() -> void:
	var sz: Vector2 = size
	if sz.x < 2 or sz.y < 2: return
	if sz != _built_for: _build(sz)
	# Sky in flat bands, the way a palette-limited game would draw a gradient.
	var band: float = ceilf(sz.y * 0.75 / SKY.size())
	for i in SKY.size():
		draw_rect(Rect2(0, i * band, sz.x, band + 1), SKY[i])
	for i in _stars.size():
		var tw: bool = int(t * 2.0 + i * 7) % 11 != 0
		if tw: draw_rect(Rect2(_stars[i], Vector2.ONE), Color(STAR, 0.35 + 0.5 * float(i % 3) / 2.0))
	# Moon with a bite out of it.
	var moon_c := Vector2(floorf(sz.x * 0.86), floorf(sz.y * 0.16))
	draw_circle(moon_c, 9, MOON, true, -1.0, false)
	draw_circle(moon_c + Vector2(4, -2), 8, SKY[0], true, -1.0, false)
	draw_colored_polygon(_far, FAR)
	_draw_saucer(sz)
	draw_colored_polygon(_mid, MID)
	_draw_fortress(Vector2(floorf(sz.x * 0.72), floorf(sz.y * 0.70) - 6))
	draw_colored_polygon(_near, NEAR)

## The saucer crosses right to left, bobbing; while over the middle it lowers a beam.
func _draw_saucer(sz: Vector2) -> void:
	var u: float = fmod(t, CROSS_S) / CROSS_S
	var x: float = floorf(lerpf(sz.x + 40.0, -60.0, u))
	var y: float = floorf(sz.y * 0.22 + sin(t * 1.3) * 3.0)
	var beam_on: bool = u > 0.45 and u < 0.62
	if beam_on:
		var k: float = 0.25 + 0.1 * sin(t * 9.0)
		var beam := PackedVector2Array([Vector2(x - 4, y + 4), Vector2(x + 4, y + 4),
			Vector2(x + 18, sz.y * 0.66), Vector2(x - 18, sz.y * 0.66)])
		draw_colored_polygon(beam, Color(CYAN, k))
	# Dome, hull, rim, running lights.
	draw_colored_polygon(_ellipse(Vector2(x, y - 3), 8, 6, true), Color("2c5a5e"))
	draw_rect(Rect2(x - 3, y - 7, 2, 1), Color(CYAN, 0.7))
	draw_colored_polygon(_ellipse(Vector2(x, y), 24, 5, false), SAUCER)
	draw_line(Vector2(x - 23, y - 1), Vector2(x + 23, y - 1), SAUCER_RIM, 1.0)
	for i in 7:
		var lx: float = x - 18 + i * 6
		var on: bool = (int(t * 4.0) + i) % 7 < 2
		draw_rect(Rect2(lx, y + 1, 2, 1), CYAN if on else Color(CYAN, 0.3))

func _ellipse(c: Vector2, rx: float, ry: float, top_only: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = 20
	for i in n + 1:
		var a: float = PI + PI * float(i) / n if top_only else TAU * float(i) / n
		pts.append(Vector2(roundf(c.x + cos(a) * rx), roundf(c.y + sin(a) * ry)))
	return pts

## A wall with towers and a few lit windows, sitting on the middle ridge.
func _draw_fortress(at: Vector2) -> void:
	var c := MID.darkened(0.25)
	draw_rect(Rect2(at.x - 30, at.y, 60, 10), c)
	for tx in [-32, -12, 10, 28]:
		draw_rect(Rect2(at.x + tx, at.y - 7, 6, 17), c)
		draw_colored_polygon(PackedVector2Array([Vector2(at.x + tx - 1, at.y - 7),
			Vector2(at.x + tx + 3, at.y - 12), Vector2(at.x + tx + 7, at.y - 7)]), c)
	for wx in [-29, -9, 13, 31]:
		if int(t * 0.5 + wx) % 7 != 0:
			draw_rect(Rect2(at.x + wx, at.y - 3, 1, 1), Color("e0aa5c"))
