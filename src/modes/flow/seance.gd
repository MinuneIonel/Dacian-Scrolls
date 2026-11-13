## Fanfi's opening séance (Bucharest, 1953), shown over the first location of a new game.
## A candle-lit table, Fanfi's portrait in the smoke and one line at a time in a parchment
## panel, typed out. Click / Enter: finish the line, then the next one. Esc: skip everything.
## Fades out at the end, emits `finished` and frees itself.
extends CanvasLayer

signal finished

const CHARS_PER_S: float = 55.0
const FADE_S: float = 0.9
const PANEL_W: int = 456
const SMOKE := Color("0e0a12")
const SMOKE_EDGE := Color("2a2236")
const SEANCE := Color("8e83ad")
const FLAME := Color("efd391")
const FLAME_HOT := Color("f4efe2")
const TABLE := Color("2b1d17")
const TABLE_TOP := Color("4a3426")

## String keys, in order. Keys starting with "fanfi_" are spoken by Fanfi, the rest is staging.
var lines: Array[String] = []
var index: int = -1
var shown: float = 0.0
var done: bool = false

var root: Control
var bg: Control
var speaker: Label
var text: Label
var hint: Label
var _t: float = 0.0
var _fanfi: Texture2D

func _ready() -> void:
	layer = 80
	name = "Seance"
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_gui_input)
	add_child(root)
	bg = Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(_draw_bg)
	root.add_child(bg)
	_fanfi = Assets.tex(&"portrait_fanfi")

	var title: Label = UiKit.label("flow_seance_title")
	title.theme_type_variation = &"TitleLabel"
	title.position = Vector2(20, 14)
	root.add_child(title)

	var panel: PanelContainer = UiKit.panel()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(PANEL_W, 84)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2((640 - PANEL_W) / 2.0, 360 - 84 - 24)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	speaker = UiKit.label("fanfi_caption_name")
	speaker.add_theme_color_override(&"font_color", Color("963131"))
	box.add_child(speaker)
	text = UiKit.label("")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(PANEL_W - 28, 44)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	hint = UiKit.label("flow_seance_hint")
	hint.theme_type_variation = &"DimLabel"
	hint.position = Vector2((640 - PANEL_W) / 2.0 + 4, 360 - 20)
	root.add_child(hint)
	next_line()

func _process(delta: float) -> void:
	_t += delta
	if index >= 0 and index < lines.size() and not done:
		var full: int = tr(lines[index]).length()
		if shown < full:
			shown = minf(full, shown + CHARS_PER_S * delta)
			text.visible_characters = int(shown)
	bg.queue_redraw()

## The current line's key, or "".
func current() -> String:
	return lines[index] if index >= 0 and index < lines.size() else ""

func line_complete() -> bool:
	return current() == "" or text.visible_characters < 0 or int(shown) >= tr(current()).length()

## Click / Enter: shows the whole line, or moves to the next one, or ends after the last.
func advance() -> void:
	if done: return
	if not line_complete():
		reveal()
	else:
		next_line()

func reveal() -> void:
	shown = tr(current()).length()
	text.visible_characters = -1

func next_line() -> void:
	index += 1
	if index >= lines.size():
		finish()
		return
	var key: String = lines[index]
	var fanfi: bool = key.begins_with("fanfi_")
	speaker.text = tr("fanfi_caption_name") if fanfi else " "
	text.text = tr(key)
	text.theme_type_variation = &"" if fanfi else &"DimLabel"
	shown = 0.0
	text.visible_characters = 0

## Ends the séance: fades out, emits `finished`, frees itself. Safe to call twice.
func finish() -> void:
	if done: return
	done = true
	var tw: Tween = create_tween()
	tw.tween_property(root, "modulate:a", 0.0, FADE_S)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())

## Ends it at once, without the fade (tests, Esc twice).
func skip_all() -> void:
	if done:
		return
	done = true
	finished.emit()
	queue_free()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		root.accept_event()

func _input(event: InputEvent) -> void:
	if done: return
	if event.is_action_pressed(&"ui_cancel"):
		finish()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()   # nothing reaches the town underneath

func _draw_bg() -> void:
	var s: Vector2 = bg.size
	bg.draw_rect(Rect2(Vector2.ZERO, s), SMOKE)
	var flick: float = 0.75 + 0.15 * sin(_t * 9.0) + 0.1 * sin(_t * 23.0 + 1.7)
	var c := Vector2(s.x * 0.5, s.y * 0.62)
	# candle light on the room
	for i in 7:
		var r: float = 210.0 - i * 26.0
		bg.draw_circle(c + Vector2(0, -6), r, Color(FLAME, 0.025 * flick * (i + 1)))
	# smoke wisps
	for k in 5:
		var x: float = s.x * (0.2 + 0.15 * k) + sin(_t * 0.6 + k) * 14.0
		var y: float = s.y * 0.3 + sin(_t * 0.9 + k * 2.0) * 10.0
		bg.draw_circle(Vector2(x, y), 26.0 + 6.0 * sin(_t + k), Color(SMOKE_EDGE, 0.35))
	# Fanfi in the smoke
	var p := Vector2(c.x, s.y * 0.30 + sin(_t * 1.4) * 3.0)
	for i in 4:
		bg.draw_circle(p, 44.0 - i * 8.0, Color(SEANCE, 0.06 + 0.04 * i))
	if _fanfi != null:
		var a: float = 0.78 + 0.12 * sin(_t * 2.1)
		bg.draw_texture_rect(_fanfi, Rect2(p - Vector2(48, 48), Vector2(96, 96)), false, Color(1, 1, 1, a))
	# the round table
	bg.draw_set_transform(c + Vector2(0, 20), 0.0, Vector2(1.0, 0.32))
	bg.draw_circle(Vector2.ZERO, 120.0, TABLE)
	bg.draw_circle(Vector2(0, -12), 116.0, TABLE_TOP)
	bg.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the candle
	var base := c + Vector2(0, 12)
	bg.draw_rect(Rect2(base + Vector2(-3, -18), Vector2(6, 18)), Color("d5d2c6"))
	var h: float = 7.0 + 2.0 * sin(_t * 11.0)
	var sway: float = sin(_t * 5.0) * 1.0
	bg.draw_colored_polygon(PackedVector2Array([base + Vector2(-3, -19), base + Vector2(sway, -19 - h),
		base + Vector2(3, -19)]), FLAME)
	bg.draw_circle(base + Vector2(0, -21), 1.5, FLAME_HOT)
