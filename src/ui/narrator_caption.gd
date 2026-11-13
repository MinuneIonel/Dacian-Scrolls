## Fanfi's séance caption: a dark smoky panel with a candle-lit border at the bottom of the
## screen. Shows one line at a time for SHOW_S seconds plus reading time; later lines wait in
## `queue`. Click (or skip()) moves on at once.
class_name NarratorCaption
extends Control

const SHOW_S: float = 4.0
const PER_CHAR_S: float = 0.035
const FADE_S: float = 0.25
const WIDTH: int = 448
const PAD: Vector2i = Vector2i(14, 8)
const BOTTOM_GAP: int = 10

const SMOKE := Color("0e0a12")
const SMOKE_EDGE := Color("2a2236")
const SEANCE := Color("8e83ad")       # palette silk0
const FLAME := Color("efd391")        # palette straw
const FLAME_HOT := Color("f4efe2")    # palette white
const CANDLE := Color("d5d2c6")       # palette grey4

var queue: Array[String] = []
var current_key: String = ""
var time_left: float = 0.0
var _name_label: Label
var _text: Label
var _t: float = 0.0
var _fade: float = 0.0

func _init() -> void:
	name = "NarratorCaption"
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visible = false
	_name_label = UiKit.label("fanfi_caption_name")
	_name_label.add_theme_color_override(&"font_color", SEANCE)
	_name_label.position = Vector2(PAD.x + 2, PAD.y - 1)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	_text = UiKit.label("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(PAD.x, PAD.y + 12)
	_text.custom_minimum_size.x = WIDTH - PAD.x * 2
	_text.size.x = WIDTH - PAD.x * 2
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)

## Adds a string key to the queue; shows it now if nothing is showing.
func queue_line(key: String) -> void:
	if key == "": return
	queue.append(key)
	if current_key == "": _next()

func is_showing() -> bool:
	return current_key != ""

## Ends the current line and shows the next one, if any.
func skip() -> void:
	_next()

## Removes everything (shown and queued).
func clear() -> void:
	queue.clear()
	current_key = ""
	visible = false

func shown_text() -> String:
	return _text.text

func _next() -> void:
	if queue.is_empty():
		current_key = ""
		visible = false
		return
	current_key = queue.pop_front()
	_text.text = tr(current_key)
	time_left = SHOW_S + PER_CHAR_S * _text.text.length()
	_fade = 0.0
	visible = true
	_layout()

func _layout() -> void:
	var lines: int = maxi(1, _text.get_line_count())
	var h: int = PAD.y * 2 + 12 + lines * _text.get_line_height() + 2
	var vp: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(640, 360)
	size = Vector2(WIDTH, h)
	position = Vector2(roundf((vp.x - WIDTH) / 2.0), vp.y - h - BOTTOM_GAP)

func _process(delta: float) -> void:
	if current_key == "": return
	_t += delta
	_fade = minf(1.0, _fade + delta / FADE_S)
	time_left -= delta
	modulate.a = _fade if time_left > FADE_S else clampf(time_left / FADE_S, 0.0, 1.0)
	if time_left <= 0.0:
		_next()
		return
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _text != null:
		_text.size.x = WIDTH - PAD.x * 2

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		skip()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# Smoke: stepped, fading halo around a near-black core.
	for i in range(4, 0, -1):
		var a: float = 0.16 * (5 - i) / 4.0
		var wob: float = sin(_t * 1.3 + i) * 1.0
		draw_rect(r.grow(i * 2 + wob), Color(SMOKE, a))
	draw_rect(r, Color(SMOKE, 0.92))
	# Drifting smoke wisps inside the panel.
	for k in 5:
		var x: float = fposmod(k * 97.0 + _t * (6.0 + k), size.x + 60.0) - 30.0
		var y: float = size.y * (0.25 + 0.15 * k) + sin(_t * 0.8 + k) * 3.0
		draw_rect(Rect2(x, y, 26 + k * 4, 2), Color(SMOKE_EDGE, 0.35))
	# Candle-flicker border.
	var flick: float = 0.55 + 0.25 * sin(_t * 9.0) + 0.2 * sin(_t * 23.0 + 1.7)
	var border := Color(UiKit.BRONZE_LIGHT, clampf(flick, 0.3, 1.0))
	draw_rect(r, border, false, 1.0)
	draw_rect(r.grow(-2), Color(SEANCE, 0.35), false, 1.0)
	# Candles on the top corners.
	_candle(Vector2(5, -6), 0.0)
	_candle(Vector2(size.x - 9, -6), 2.1)

func _candle(at: Vector2, phase: float) -> void:
	# Wax stub with a drip, a swaying two-tone flame and a soft glow.
	var glow: float = 0.10 + 0.05 * sin(_t * 9.0 + phase)
	draw_rect(Rect2(at + Vector2(-1, -6), Vector2(6, 7)), Color(FLAME, glow * 0.6))
	draw_rect(Rect2(at + Vector2(0, 2), Vector2(4, 9)), CANDLE)
	draw_rect(Rect2(at + Vector2(3, 2), Vector2(1, 9)), Color("a6a59f"))
	draw_rect(Rect2(at + Vector2(0, 4), Vector2(1, 3)), Color("f4efe2"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2(1, 1)), UiKit.INK)
	var h: int = 3 + int(1.5 + 1.5 * sin(_t * 11.0 + phase))
	var sway: int = int(round(sin(_t * 5.0 + phase) * 0.7))
	draw_rect(Rect2(at + Vector2(sway, 1 - h), Vector2(3, h)), Color("d6a043"))
	draw_rect(Rect2(at + Vector2(sway + 1, 1 - h - 1), Vector2(1, 1)), Color("d6a043"))
	draw_rect(Rect2(at + Vector2(1 + sway, 2 - h), Vector2(1, maxi(1, h - 2))), FLAME_HOT)
