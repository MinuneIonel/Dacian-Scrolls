## A small cartoon puff (dust, smoke, sparks) drawn from circles: grows, drifts up, fades, frees
## itself. Needs no art. `PuffFx.spawn(parent, pos, color, size, speed)`.
extends Node2D

var color: Color = Color("b8a888")
var radius: float = 10.0
var life: float = 0.6
var count: int = 7
var _t: float = 0.0
var _blobs: Array[Vector3] = []   # x, y = direction, z = size factor

static func spawn(parent: Node, pos: Vector2, col: Color, size: float = 10.0, speed: float = 1.0,
		seed_v: int = 0) -> Node2D:
	var p: Node2D = (load("res://src/ui/fx/puff.gd") as GDScript).new()
	p.position = pos
	p.color = col
	p.radius = size
	p.life = 0.6 / maxf(0.1, speed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in p.count:
		var a: float = TAU * float(i) / p.count + rng.randf_range(-0.3, 0.3)
		p._blobs.append(Vector3(cos(a), sin(a) * 0.5, rng.randf_range(0.5, 1.0)))
	p.add_to_group(&"fx_puff")
	parent.add_child(p)
	return p

func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k: float = clampf(_t / life, 0.0, 1.0)
	var ease_k: float = 1.0 - pow(1.0 - k, 3.0)
	var c: Color = color
	c.a = color.a * (1.0 - k)
	for b in _blobs:
		var off := Vector2(b.x, b.y) * radius * 1.4 * ease_k - Vector2(0, radius * 0.6 * k)
		draw_circle(off, radius * 0.45 * b.z * (0.6 + ease_k * 0.6), c)
