## One flying chunk (fx_gib_1..6): arcs from the body to a ground point, spins, bounces once and
## then stays on the map as a decal (moved into the decal layer). Cartoon chunks, never anatomy.
extends Sprite2D

var from: Vector2
var to: Vector2
var height: float = 18.0
var arc: float = 26.0
var decals: Node2D
var _tw: Tween

func launch(duration: float, spin: float) -> void:
	position = from
	_tw = create_tween()
	_tw.tween_method(_fly, 0.0, 1.0, duration)
	_tw.parallel().tween_property(self, "rotation", rotation + spin, duration)
	_tw.tween_method(_hop, 0.0, 1.0, duration * 0.35)
	_tw.tween_callback(land)

## Lands at once (instant playback, or the scene is closing).
func land() -> void:
	if _tw != null and _tw.is_valid(): _tw.kill()
	position = to
	if decals != null and is_instance_valid(decals) and get_parent() != decals:
		var p: Node = get_parent()
		if p != null: p.remove_child(self)
		decals.add_child(self)
	remove_from_group(&"fx_gib_flying")
	add_to_group(&"fx_decal")

func _fly(t: float) -> void:
	var h: float = height * (1.0 - t) + arc * 4.0 * t * (1.0 - t)
	position = from.lerp(to, t) - Vector2(0, h)

func _hop(t: float) -> void:
	position = to - Vector2(0, 4.0 * 4.0 * t * (1.0 - t))
