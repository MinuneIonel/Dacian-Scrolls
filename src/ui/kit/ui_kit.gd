## Small UI kit: the game's theme and the widget builders every view uses. Static only.
## Buttons and labels take string keys and show tr(key); the key stays in meta "text_key".
class_name UiKit
extends RefCounted

const FONT_PATH: String = "res://assets/fonts/dacian.fnt"
const TITLE_FONT_PATH: String = "res://assets/fonts/dacian_title.fnt"
const FONT_SIZE: int = 11
const TITLE_SIZE: int = 22

# Palette. Cyan is reserved for alien things (saucers, beams, Lobizi tech).
const INK := Color("120c09")
const UMBER_DARK := Color("1e1611")
const UMBER := Color("2d211a")
const WOOD := Color("4a3426")
const WOOD_LIGHT := Color("6b4b33")
const BRONZE := Color("a8743a")
const BRONZE_LIGHT := Color("e0aa5c")
const PARCHMENT := Color("eadbb4")
const PARCHMENT_DIM := Color("a8957a")
const DISABLED := Color("6b5a48")
const CYAN := Color("5ff2e6")
const BLOOD := Color("b03030")

static var _font: Font
static var _title_font: Font
static var _theme: Theme

## The pixel font (11 px line, 5x7 glyphs).
static func font() -> Font:
	if _font == null: _font = _load_font(FONT_PATH)
	return _font

## The same font drawn at 2x, for titles.
static func title_font() -> Font:
	if _title_font == null: _title_font = _load_font(TITLE_FONT_PATH)
	return _title_font

## Imported resource when available (export-safe), else the raw BMFont file.
static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path, "FontFile"):
		var f: Variant = load(path)
		if f is Font: return f
	var ff := FontFile.new()
	if ff.load_bitmap_font(path) != OK:
		push_error("UiKit: cannot load font " + path)
		return ThemeDB.fallback_font
	return ff

## The game theme, built once. Set it on a view's root Control (`theme = UiKit.theme()`).
static func theme() -> Theme:
	if _theme != null: return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FONT_SIZE

	t.set_stylebox("panel", "PanelContainer", _panel_style())
	t.set_stylebox("panel", "Panel", _panel_style())

	t.set_color("font_color", "Label", PARCHMENT)
	t.set_color("font_shadow_color", "Label", Color(INK, 0.8))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", 1)

	t.add_type("TitleLabel")
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", title_font())
	t.set_font_size("font_size", "TitleLabel", TITLE_SIZE)
	t.set_color("font_color", "TitleLabel", BRONZE_LIGHT)
	t.set_color("font_shadow_color", "TitleLabel", INK)
	t.set_constant("shadow_offset_x", "TitleLabel", 2)
	t.set_constant("shadow_offset_y", "TitleLabel", 2)

	t.add_type("DimLabel")
	t.set_type_variation("DimLabel", "Label")
	t.set_color("font_color", "DimLabel", PARCHMENT_DIM)

	t.add_type("AlienLabel")
	t.set_type_variation("AlienLabel", "Label")
	t.set_color("font_color", "AlienLabel", CYAN)

	for type_name in ["Button", "CheckBox"]:
		t.set_color("font_color", type_name, PARCHMENT)
		t.set_color("font_hover_color", type_name, BRONZE_LIGHT)
		t.set_color("font_focus_color", type_name, BRONZE_LIGHT)
		t.set_color("font_pressed_color", type_name, PARCHMENT)
		t.set_color("font_hover_pressed_color", type_name, BRONZE_LIGHT)
		t.set_color("font_disabled_color", type_name, DISABLED)
		t.set_color("font_outline_color", type_name, INK)
		t.set_constant("h_separation", type_name, 4)
	t.set_stylebox("normal", "Button", _box(UMBER, WOOD, 1))
	t.set_stylebox("hover", "Button", _box(WOOD, BRONZE, 1))
	t.set_stylebox("pressed", "Button", _box(UMBER_DARK, BRONZE_LIGHT, 1))
	t.set_stylebox("hover_pressed", "Button", _box(WOOD, BRONZE_LIGHT, 1))
	t.set_stylebox("disabled", "Button", _box(Color(UMBER_DARK, 0.85), Color(WOOD, 0.6), 1))
	t.set_stylebox("focus", "Button", _focus_style())

	# CheckBox: flat row with a pixel tick box.
	var flat := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	for s in ["normal", "pressed", "disabled", "hover_pressed"]:
		t.set_stylebox(s, "CheckBox", flat)
	t.set_stylebox("hover", "CheckBox", _box(Color(WOOD, 0.5), Color(0, 0, 0, 0), 0))
	t.set_stylebox("focus", "CheckBox", _focus_style())
	t.set_icon("checked", "CheckBox", _icon(["#######", "#.....#", "#.###.#", "#.###.#", "#.###.#", "#.....#", "#######"], BRONZE_LIGHT))
	t.set_icon("unchecked", "CheckBox", _icon(["#######", "#.....#", "#.....#", "#.....#", "#.....#", "#.....#", "#######"], BRONZE))
	t.set_icon("checked_disabled", "CheckBox", _icon(["#######", "#.....#", "#.###.#", "#.###.#", "#.###.#", "#.....#", "#######"], DISABLED))
	t.set_icon("unchecked_disabled", "CheckBox", _icon(["#######", "#.....#", "#.....#", "#.....#", "#.....#", "#.....#", "#######"], DISABLED))

	# Sliders: thin track, bronze fill, square grabber.
	var track := _box(INK, WOOD, 1)
	track.content_margin_top = 2; track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(BRONZE, Color(0, 0, 0, 0), 0)
	fill.content_margin_top = 2; fill.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hi := _box(BRONZE_LIGHT, Color(0, 0, 0, 0), 0)
	fill_hi.content_margin_top = 2; fill_hi.content_margin_bottom = 2
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	t.set_icon("grabber", "HSlider", _icon(["#####", "#...#", "#...#", "#...#", "#####"], PARCHMENT, BRONZE))
	t.set_icon("grabber_highlight", "HSlider", _icon(["#####", "#...#", "#...#", "#...#", "#####"], BRONZE_LIGHT, PARCHMENT))
	t.set_icon("grabber_disabled", "HSlider", _icon(["#####", "#...#", "#...#", "#...#", "#####"], DISABLED, UMBER))
	t.set_icon("tick", "HSlider", _icon(["#"], WOOD))
	t.set_stylebox("focus", "HSlider", _focus_style())

	# Bars.
	t.set_stylebox("background", "ProgressBar", _box(INK, WOOD, 1))
	t.set_stylebox("fill", "ProgressBar", _box(BLOOD, Color(0, 0, 0, 0), 0))
	t.set_color("font_color", "ProgressBar", PARCHMENT)

	# Text entry.
	var le := _box(INK, WOOD, 1)
	le.content_margin_left = 4; le.content_margin_right = 4
	t.set_stylebox("normal", "LineEdit", le)
	var le_focus := _box(INK, BRONZE_LIGHT, 1)
	le_focus.content_margin_left = 4; le_focus.content_margin_right = 4
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_color("font_color", "LineEdit", PARCHMENT)
	t.set_color("font_placeholder_color", "LineEdit", DISABLED)
	t.set_color("caret_color", "LineEdit", BRONZE_LIGHT)
	t.set_color("selection_color", "LineEdit", Color(BRONZE, 0.5))
	t.set_constant("caret_width", "LineEdit", 1)

	t.set_stylebox("panel", "TooltipPanel", _box(UMBER_DARK, BRONZE, 1))
	t.set_color("font_color", "TooltipLabel", PARCHMENT)
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("h_separation", "GridContainer", 8)
	t.set_constant("v_separation", "GridContainer", 4)
	_theme = t
	return t

## A framed panel (parchment-on-wood). Uses the ui_panel texture once the art exists.
static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = theme()
	return p

static func button(text_key: String) -> Button:
	var b := Button.new()
	b.theme = theme()
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.set_meta(&"text_key", text_key)
	b.text = TranslationServer.translate(text_key)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

static func label(text_key: String) -> Label:
	var l := Label.new()
	l.theme = theme()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.set_meta(&"text_key", text_key)
	l.text = TranslationServer.translate(text_key) if text_key != "" else ""
	return l

## A thin bar (HP, mana, charge). Set max_value/value on it.
static func bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.theme = theme()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(40, 5)
	b.add_theme_stylebox_override("fill", _box(color, Color(0, 0, 0, 0), 0))
	return b

## Vertical list of buttons, one per item (string keys); emits chosen(index).
static func choice_list(items: Array[String]) -> VBoxContainer:
	var c: ChoiceList = ChoiceList.new()
	c.theme = theme()
	c.set_items(items)
	return c

## Shows Bus.toast messages (and `toast` events) for about 2.5 s, stacked under the top edge.
static func toast_layer() -> CanvasLayer:
	return ToastLayer.new()

static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.anti_aliasing = false
	s.content_margin_left = 6; s.content_margin_right = 6
	s.content_margin_top = 2; s.content_margin_bottom = 2
	return s

static func _focus_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = BRONZE_LIGHT
	s.set_border_width_all(1)
	s.expand_margin_left = 2; s.expand_margin_right = 2
	s.expand_margin_top = 1; s.expand_margin_bottom = 1
	s.anti_aliasing = false
	return s

static func _panel_style() -> StyleBox:
	if Engine.get_main_loop() != null and Assets.has_tex(&"ui_panel"):
		var st := StyleBoxTexture.new()
		st.texture = Assets.tex(&"ui_panel")
		st.set_texture_margin_all(12)
		st.set_content_margin_all(12)
		return st
	var s := _box(UMBER_DARK, BRONZE, 1)
	s.set_content_margin_all(8)
	return s

## Tiny texture from an ASCII pattern: '#' = fg, '.' = fill (transparent unless given).
static func _icon(rows: Array, fg: Color, fill: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			img.set_pixel(x, y, fg if r[x] == "#" else fill)
	return ImageTexture.create_from_image(img)
