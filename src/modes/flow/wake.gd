## The wake-up card after a lost battle or a saucer fight: a full-screen colour (white after
## the saucer, black at the temple) with one line, which fades away over the mode underneath.
## Then it broadcasts `wake_events` (Fanfi's line) and frees itself. A click skips the hold.
extends CanvasLayer

const HOLD_S: float = 1.6
const FADE_S: float = 1.2
const WHITE := Color("f4efe2")
const INK := Color("120c09")

## "forest", "crash" or "temple".
var kind: String = "temple"
var wake_events: Array[Dictionary] = []
var instant: bool = false
var t: float = 0.0
var broadcast_done: bool = false

var cover: ColorRect
var title: Label

func _ready() -> void:
	layer = 85
	name = "Wake"
	if instant:
		_broadcast()
		queue_free()
		return
	var dark: bool = kind == "temple"
	cover = ColorRect.new()
	cover.color = INK if dark else WHITE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.gui_input.connect(_on_gui_input)
	add_child(cover)
	title = UiKit.label(title_key())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(420, 40)
	title.position = Vector2(110, 160)
	if not dark:
		title.add_theme_color_override(&"font_color", Color("3a2318"))
		title.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	cover.add_child(title)

func title_key() -> String:
	return "flow_wake_%s_title" % kind

func _process(delta: float) -> void:
	if instant: return
	t += delta
	if t > HOLD_S:
		cover.modulate.a = 1.0 - clampf((t - HOLD_S) / FADE_S, 0.0, 1.0)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t >= HOLD_S + FADE_S:
		_broadcast()
		queue_free()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		t = maxf(t, HOLD_S)

func _broadcast() -> void:
	if broadcast_done: return
	broadcast_done = true
	Bus.emit_events(wake_events)
