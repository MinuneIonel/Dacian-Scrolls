## A Lobizi saucer seen from above: a dark elliptical shadow with a faint cyan rim and a slow
## wobble. Pulses while chasing. Always drawn (a menacing shadow even over the fog); over fog
## it is fainter and loses its rim.
extends Node2D

const CELL: int = 16
const RADIUS: float = 22.0
const SHADOW := Color(0.07, 0.05, 0.04, 0.62)
const RIM := Color("3fe3ea")   # palette cyan, reserved for alien things

var ufo_id: StringName = &""
var state: String = "patrol"
var fogged: bool = false
var _t: float = 0.0
var _tween: Tween

func _init(id: StringName = &"") -> void:
	ufo_id = id
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func place(cell: Vector2i, animate_s: float = 0.0) -> void:
	var to := Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)
	if _tween != null: _tween.kill()
	if animate_s <= 0.0 or not is_inside_tree():
		position = to
		return
	_tween = create_tween()
	_tween.tween_property(self, "position", to, animate_s).set_trans(Tween.TRANS_SINE)

func set_state(s: String) -> void:
	state = s
	visible = s != "gone"
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var chase: bool = state == "chase"
	var pulse: float = 0.5 + 0.5 * sin(_t * 7.0) if chase else 0.0
	var wob := Vector2(sin(_t * 1.3) * 1.5, cos(_t * 0.9) * 1.0).round()
	var squash: float = 0.42 + 0.04 * sin(_t * 1.7)
	var r: float = RADIUS + (2.0 * pulse if chase else 0.0)
	var shadow := Color(SHADOW, SHADOW.a * (0.55 if fogged else 1.0))
	draw_set_transform(wob, sin(_t * 0.6) * 0.08, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, r, shadow)
	draw_circle(Vector2.ZERO, r * 0.55, Color(shadow, minf(1.0, shadow.a + 0.15)))
	if not fogged:
		var rim_a: float = 0.5 + (0.5 * pulse if chase else 0.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(RIM, rim_a), 1.0)
		# Running lights around the rim, slowly circling.
		for k in 6:
			var a: float = _t * 0.8 + k * TAU / 6.0
			draw_rect(Rect2(Vector2(cos(a), sin(a)) * (r - 2.0) - Vector2(1, 1), Vector2(2, 2)),
				Color(RIM, 0.55 + 0.4 * pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
