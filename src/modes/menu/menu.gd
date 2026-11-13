## Title screen: New Game (class and optional seed), Continue, Settings, Quit.
## Keyboard: arrows/Tab move, Enter picks, Esc goes back, Left/Right change a setting.
## Router.args {"screen": "new" | "settings"} opens a sub-screen directly (screenshots).
extends Control

const CLASSES: Array[StringName] = [&"knight", &"necromancer"]
const COLUMN_W: int = 236

var background: MenuBackground
var screens: Dictionary = {}          # StringName -> Control
var screen: StringName = &""

# Main screen
var btn_new: Button
var btn_continue: Button
var btn_settings: Button
var btn_quit: Button
# New game screen
var class_buttons: Array[Button] = []
var hero_class: StringName = &"knight"
var seed_edit: LineEdit
var btn_begin: Button
# Settings screen
var gore_button: Button
var gore_desc: Label
var music_slider: HSlider
var sfx_slider: HSlider
var music_value: Label
var sfx_value: Label
var fullscreen_box: Button

func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background = MenuBackground.new()
	add_child(background)

	var column := VBoxContainer.new()
	column.position = Vector2(28, 26)
	column.custom_minimum_size.x = COLUMN_W
	column.add_theme_constant_override(&"separation", 2)
	add_child(column)
	var title: Label = UiKit.label("title")
	title.theme_type_variation = &"TitleLabel"
	column.add_child(title)
	var sub: Label = UiKit.label("menu_subtitle")
	sub.theme_type_variation = &"DimLabel"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 320
	column.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	column.add_child(gap)

	screens[&"main"] = _build_main()
	screens[&"new"] = _build_new()
	screens[&"settings"] = _build_settings()
	for s: StringName in screens:
		(screens[s] as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(screens[s])

	var hint: Label = UiKit.label("menu_hint_keys")
	hint.theme_type_variation = &"DimLabel"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(28, -18)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(hint)
	hint.offset_top = -20; hint.offset_bottom = -8

	add_child(UiKit.toast_layer())
	var start: StringName = StringName(Router.args.get("screen", "main"))
	show_screen(start if screens.has(start) else &"main")

## Shows one sub-screen and puts keyboard focus on its first control.
func show_screen(which: StringName) -> void:
	screen = which
	for s: StringName in screens:
		(screens[s] as Control).visible = s == which
	match which:
		&"main":
			btn_continue.disabled = not Game.has_save(0)
			btn_continue.focus_mode = Control.FOCUS_NONE if btn_continue.disabled else Control.FOCUS_ALL
			btn_continue.tooltip_text = "" if not btn_continue.disabled else tr("menu_no_save")
			_wrap_focus([btn_new, btn_continue, btn_settings, btn_quit])
			(btn_new if btn_continue.disabled else btn_continue).grab_focus.call_deferred()
		&"new":
			_select_class(hero_class)
			class_buttons[CLASSES.find(hero_class)].grab_focus.call_deferred()
		&"settings":
			_sync_settings()
			gore_button.grab_focus.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and screen != &"main":
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	if screen == &"settings": Settings.save()
	show_screen(&"main")

# --- main -------------------------------------------------------------------------------

func _build_main() -> Control:
	var p: PanelContainer = UiKit.panel()
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 112
	p.add_child(box)
	btn_new = _menu_button(box, "menu_new_game", func() -> void: show_screen(&"new"))
	btn_continue = _menu_button(box, "menu_continue", _continue_game)
	btn_settings = _menu_button(box, "menu_settings", func() -> void: show_screen(&"settings"))
	btn_quit = _menu_button(box, "menu_quit", func() -> void: get_tree().quit())
	return p

func _menu_button(parent: Control, key: String, on_press: Callable) -> Button:
	var b: Button = UiKit.button(key)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b

## Up from the first focusable button wraps to the last, and down from the last to the first.
func _wrap_focus(list: Array[Button]) -> void:
	var live: Array[Button] = list.filter(func(b: Button) -> bool: return b.focus_mode != Control.FOCUS_NONE)
	for b in list:
		b.focus_neighbor_top = NodePath(); b.focus_neighbor_bottom = NodePath()
	if live.size() < 2: return
	live[0].focus_neighbor_top = live[0].get_path_to(live[-1])
	live[-1].focus_neighbor_bottom = live[-1].get_path_to(live[0])

func _continue_game() -> void:
	if not Game.has_save(0): return
	if Game.load_slot(0) != OK: return   # Game toasts the reason
	Router.go(Game.state.mode, Router.resume_args())

# --- new game ---------------------------------------------------------------------------

func _build_new() -> Control:
	var p: PanelContainer = UiKit.panel()
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = COLUMN_W - 16
	p.add_child(box)
	box.add_child(UiKit.label("menu_new_heading"))
	var group := ButtonGroup.new()
	for id in CLASSES:
		var b: Button = UiKit.button("menu_class_" + id)
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_select_class.bind(id))
		b.focus_entered.connect(_select_class.bind(id))
		box.add_child(b)
		class_buttons.append(b)
		var d: Label = UiKit.label("menu_class_%s_desc" % id)
		d.theme_type_variation = &"DimLabel"
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = COLUMN_W - 24
		var m := MarginContainer.new()
		m.add_theme_constant_override(&"margin_left", 8)
		m.add_child(d)
		box.add_child(m)
	var row := HBoxContainer.new()
	box.add_child(row)
	var seed_label: Label = UiKit.label("menu_seed")
	row.add_child(seed_label)
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = tr("menu_seed_hint")
	seed_edit.max_length = 16
	seed_edit.custom_minimum_size = Vector2(110, 0)
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.text_submitted.connect(func(_t: String) -> void: _begin())
	row.add_child(seed_edit)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	btn_begin = UiKit.button("menu_begin")
	btn_begin.pressed.connect(_begin)
	buttons.add_child(btn_begin)
	var back: Button = UiKit.button("menu_back")
	back.pressed.connect(_back)
	buttons.add_child(back)
	return p

func _select_class(id: StringName) -> void:
	hero_class = id
	for i in class_buttons.size():
		class_buttons[i].set_pressed_no_signal(CLASSES[i] == id)

## Seed from the field: a number is used as is, any other text is hashed, blank is random.
func parse_seed(text: String) -> int:
	var s: String = text.strip_edges()
	if s == "": return randi()
	if s.is_valid_int(): return s.to_int()
	return hash(s)

func _begin() -> void:
	Flow.start_new_game(parse_seed(seed_edit.text), hero_class)

# --- settings ---------------------------------------------------------------------------

func _build_settings() -> Control:
	var p: PanelContainer = UiKit.panel()
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = COLUMN_W - 16
	p.add_child(box)
	var head: Label = UiKit.label("settings_title")
	head.add_theme_color_override(&"font_color", UiKit.BRONZE_LIGHT)
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)

	grid.add_child(_row_label("settings_gore"))
	gore_button = UiKit.button("")
	gore_button.custom_minimum_size.x = 96
	gore_button.pressed.connect(_cycle_gore.bind(1))
	gore_button.gui_input.connect(_on_gore_input)
	grid.add_child(gore_button)
	grid.add_child(Control.new())

	grid.add_child(_row_label("settings_music"))
	music_slider = _slider(grid)
	music_value = UiKit.label("")
	grid.add_child(music_value)
	music_slider.value_changed.connect(func(v: float) -> void:
		Settings.music_volume = v; Settings.apply(); _sync_values())

	grid.add_child(_row_label("settings_sfx"))
	sfx_slider = _slider(grid)
	sfx_value = UiKit.label("")
	grid.add_child(sfx_value)
	sfx_slider.value_changed.connect(func(v: float) -> void:
		Settings.sfx_volume = v; Settings.apply(); _sync_values()
		Audio.sfx(&"click"))

	grid.add_child(_row_label("settings_fullscreen"))
	fullscreen_box = UiKit.button("")
	fullscreen_box.custom_minimum_size.x = 96
	fullscreen_box.toggle_mode = true
	fullscreen_box.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on; Settings.apply(); _sync_values())
	fullscreen_box.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed(&"ui_left") or e.is_action_pressed(&"ui_right"):
			fullscreen_box.button_pressed = not fullscreen_box.button_pressed
			fullscreen_box.accept_event())
	grid.add_child(fullscreen_box)
	grid.add_child(Control.new())

	gore_desc = UiKit.label("")
	gore_desc.theme_type_variation = &"DimLabel"
	gore_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gore_desc.custom_minimum_size = Vector2(COLUMN_W - 24, 24)
	box.add_child(gore_desc)
	var row := HBoxContainer.new()
	box.add_child(row)
	var back: Button = UiKit.button("menu_back")
	back.pressed.connect(_back)
	row.add_child(back)
	var note: Label = UiKit.label("settings_hint")
	note.theme_type_variation = &"DimLabel"
	row.add_child(note)
	return p

func _row_label(key: String) -> Label:
	var l: Label = UiKit.label(key)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	return l

func _slider(parent: Control) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0; s.max_value = 1.0; s.step = 0.05
	s.custom_minimum_size = Vector2(96, 9)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	parent.add_child(s)
	return s

func _on_gore_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		_cycle_gore(-1); gore_button.accept_event()
	elif event.is_action_pressed(&"ui_right"):
		_cycle_gore(1); gore_button.accept_event()

func _cycle_gore(step: int) -> void:
	Settings.gore = posmod(Settings.gore + step, 3)
	_sync_values()

## Copies Settings into the widgets.
func _sync_settings() -> void:
	music_slider.set_value_no_signal(Settings.music_volume)
	sfx_slider.set_value_no_signal(Settings.sfx_volume)
	fullscreen_box.set_pressed_no_signal(Settings.fullscreen)
	_sync_values()

func _sync_values() -> void:
	gore_button.text = "< %s >" % tr(Settings.gore_key())
	fullscreen_box.text = "< %s >" % tr("settings_on" if Settings.fullscreen else "settings_off")
	gore_desc.text = tr(Settings.gore_key() + "_desc")
	music_value.text = tr("ui_percent") % roundi(Settings.music_volume * 100.0)
	sfx_value.text = tr("ui_percent") % roundi(Settings.sfx_volume * 100.0)
