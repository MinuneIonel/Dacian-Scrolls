## The abduction: a saucer's tractor beam over the party on the world map, then a white-out.
## At full white it emits `whited_out` (Flow switches to the saucer battle underneath), holds a
## moment, fades the white away over the new scene and frees itself. Blocks input meanwhile.
extends CanvasLayer

signal whited_out

const BEAM_S: float = 1.3
const WHITE_IN: Vector2 = Vector2(0.9, 1.7)    # start, full
const HOLD_UNTIL: float = 2.0
const WHITE_OUT_S: float = 0.8
const BEAM := Color("5ff2e6")                  # UiKit.CYAN: alien things only
const WHITE := Color("f4efe2")

## Where the party stands, in screen pixels.
var screen_pos: Vector2 = Vector2(320, 200)
## Skip the animation: emit whited_out at once and free (tests).
var instant: bool = false
var t: float = 0.0
var emitted: bool = false

var root: Control
var white: ColorRect
var beam_sprite: AnimatedSprite2D
var saucer: Sprite2D

func _ready() -> void:
	layer = 85
	name = "Beam"
	if instant:
		_emit()
		queue_free()
		return
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.draw.connect(_draw_cone)
	add_child(root)
	var top := Vector2(screen_pos.x, maxf(24.0, screen_pos.y - 120.0))
	beam_sprite = AnimatedSprite2D.new()
	beam_sprite.sprite_frames = Assets.frames(&"fx_tractor_beam")
	beam_sprite.centered = false
	beam_sprite.offset = Vector2(-24, 0)
	beam_sprite.position = top
	beam_sprite.scale = Vector2(1.0, (screen_pos.y - top.y + 8.0) / 128.0)
	if beam_sprite.sprite_frames.has_animation(&"play"): beam_sprite.play(&"play")
	beam_sprite.modulate.a = 0.0
	add_child(beam_sprite)
	saucer = Sprite2D.new()
	saucer.texture = Assets.tex(&"marker_ufo")
	saucer.position = top + Vector2(0, -6)
	saucer.scale = Vector2(2, 2)
	add_child(saucer)
	white = ColorRect.new()
	white.color = Color(WHITE, 0.0)
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(white)

func _process(delta: float) -> void:
	if instant: return
	t += delta
	var grow: float = clampf(t / BEAM_S, 0.0, 1.0)
	beam_sprite.modulate.a = grow * (0.8 + 0.2 * sin(t * 20.0))
	saucer.position.y += sin(t * 6.0) * 0.15
	var w: float = 0.0
	if t < HOLD_UNTIL:
		w = clampf((t - WHITE_IN.x) / (WHITE_IN.y - WHITE_IN.x), 0.0, 1.0)
	else:
		w = 1.0 - clampf((t - HOLD_UNTIL) / WHITE_OUT_S, 0.0, 1.0)
	white.color = Color(WHITE, w)
	if t >= WHITE_IN.y and not emitted:
		_emit()
		beam_sprite.visible = false
		saucer.visible = false
		root.visible = false
	if t >= HOLD_UNTIL + WHITE_OUT_S: queue_free()
	root.queue_redraw()

func _emit() -> void:
	if emitted: return
	emitted = true
	whited_out.emit()

func _input(event: InputEvent) -> void:
	if not instant and (event is InputEventKey or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()

## A soft cone under the saucer and rings where the party stands.
func _draw_cone() -> void:
	var grow: float = clampf(t / BEAM_S, 0.0, 1.0)
	var top := Vector2(screen_pos.x, maxf(24.0, screen_pos.y - 120.0))
	var hw_top: float = 8.0
	var hw_bot: float = 10.0 + 18.0 * grow
	root.draw_colored_polygon(PackedVector2Array([top + Vector2(-hw_top, 0), top + Vector2(hw_top, 0),
		Vector2(screen_pos.x + hw_bot, screen_pos.y + 4), Vector2(screen_pos.x - hw_bot, screen_pos.y + 4)]),
		Color(BEAM, 0.22 * grow))
	for i in 3:
		var ph: float = fposmod(t * 1.6 + i / 3.0, 1.0)
		root.draw_set_transform(screen_pos + Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
		root.draw_arc(Vector2.ZERO, 6.0 + 22.0 * ph, 0.0, TAU, 24, Color(BEAM, (1.0 - ph) * grow), 1.0)
	root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
