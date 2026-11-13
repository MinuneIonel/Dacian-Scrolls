## Combat HUD (640x360): turn order strip, round/timer, the active unit's bars and AP pips, the
## ability bar, end turn / flee, a hover tip, big banners and the result panel. Display only.
extends CanvasLayer

const Txt := preload("res://src/modes/combat/combat_text.gd")

signal ability_pressed(index: int)
signal end_turn_pressed
signal flee_pressed
signal result_closed

const BAR_H: int = 54
const MAX_BUTTONS: int = 8

var root: Control
var order_box: HBoxContainer
var round_label: Label
var timer_label: Label
var speed_label: Label
var name_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var mana_bar: ProgressBar
var mana_text: Label
var charge_bar: ProgressBar
var charge_text: Label
var ap_pips: Control
var ability_box: HBoxContainer
var ability_buttons: Array[Button] = []
var end_button: Button
var flee_button: Button
var tip_panel: PanelContainer
var tip_label: Label
var banner_label: Label
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var result_button: Button
var ap: int = 0
var ap_max: int = 0
var _banner_tween: Tween

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.name = "HudRoot"
	root.theme = UiKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	_build_bottom()
	_build_overlays()

static func flat(bg: Color, border: Color, pad: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.anti_aliasing = false
	s.set_content_margin_all(pad)
	return s

func _build_top() -> void:
	order_box = HBoxContainer.new()
	order_box.name = "TurnOrder"
	order_box.position = Vector2(4, 4)
	order_box.add_theme_constant_override("separation", 2)
	order_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(order_box)
	var right := VBoxContainer.new()
	right.name = "TopRight"
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-4, 4)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.add_theme_constant_override("separation", 1)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	round_label = _lbl("", HORIZONTAL_ALIGNMENT_RIGHT)
	timer_label = _lbl("", HORIZONTAL_ALIGNMENT_RIGHT)
	timer_label.theme_type_variation = &"AlienLabel"
	timer_label.visible = false
	speed_label = _lbl(tr("cbt_fast"), HORIZONTAL_ALIGNMENT_RIGHT)
	speed_label.theme_type_variation = &"DimLabel"
	speed_label.visible = false
	right.add_child(round_label); right.add_child(timer_label); right.add_child(speed_label)

func _build_bottom() -> void:
	var bar := PanelContainer.new()
	bar.name = "BottomBar"
	bar.add_theme_stylebox_override("panel", flat(UiKit.UMBER_DARK, UiKit.BRONZE, 4))
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BAR_H
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	# Active unit: name, bars, AP pips.
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(124, 0)
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)
	name_label = _lbl("", HORIZONTAL_ALIGNMENT_LEFT)
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(124, 0)
	info.add_child(name_label)
	var r := _bar_row(Color("b03030"), "cbt_hp"); hp_bar = r[0]; hp_text = r[1]; info.add_child(r[2])
	r = _bar_row(Color("3a6ac0"), "cbt_mana"); mana_bar = r[0]; mana_text = r[1]; info.add_child(r[2])
	r = _bar_row(Color("c8a030"), "cbt_charge"); charge_bar = r[0]; charge_text = r[1]; info.add_child(r[2])
	ap_pips = Control.new()
	ap_pips.name = "ApPips"
	ap_pips.custom_minimum_size = Vector2(0, 0)
	ap_pips.draw.connect(_draw_pips)
	# Pips sit at the right of the name line.
	name_label.add_child(ap_pips)
	ap_pips.position = Vector2(64, 2)
	# Abilities.
	ability_box = HBoxContainer.new()
	ability_box.name = "Abilities"
	ability_box.add_theme_constant_override("separation", 2)
	ability_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ability_box)
	for i in MAX_BUTTONS:
		var b: Button = UiKit.button("")
		b.custom_minimum_size = Vector2(52, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.visible = false
		b.add_theme_stylebox_override("normal", flat(UiKit.UMBER, UiKit.WOOD, 3))
		b.add_theme_stylebox_override("hover", flat(UiKit.WOOD, UiKit.BRONZE, 3))
		b.add_theme_stylebox_override("pressed", flat(UiKit.WOOD, UiKit.BRONZE_LIGHT, 3))
		b.add_theme_stylebox_override("disabled", flat(Color(UiKit.UMBER_DARK, 0.8), Color(UiKit.WOOD, 0.5), 3))
		b.pressed.connect(func() -> void: ability_pressed.emit(i))
		ability_box.add_child(b)
		ability_buttons.append(b)
	# End turn / flee.
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 2)
	row.add_child(side)
	end_button = UiKit.button("cbt_end_turn")
	end_button.custom_minimum_size = Vector2(66, 21)
	end_button.focus_mode = Control.FOCUS_NONE
	end_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	flee_button = UiKit.button("cbt_flee")
	flee_button.custom_minimum_size = Vector2(66, 21)
	flee_button.focus_mode = Control.FOCUS_NONE
	flee_button.pressed.connect(func() -> void: flee_pressed.emit())
	side.add_child(end_button); side.add_child(flee_button)

func _bar_row(col: Color, key: String) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	var tag := _lbl(tr(key), HORIZONTAL_ALIGNMENT_LEFT)
	tag.theme_type_variation = &"DimLabel"
	tag.custom_minimum_size = Vector2(14, 0)
	var b: ProgressBar = UiKit.bar(col)
	b.custom_minimum_size = Vector2(50, 5)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var t := _lbl("", HORIZONTAL_ALIGNMENT_LEFT)
	h.add_child(tag); h.add_child(b); h.add_child(t)
	return [b, t, h]

func _build_overlays() -> void:
	banner_label = Label.new()
	banner_label.name = "Banner"
	banner_label.theme_type_variation = &"TitleLabel"
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_label.position = Vector2(-320, 64)
	banner_label.size = Vector2(640, 30)
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_label.modulate.a = 0.0
	root.add_child(banner_label)
	tip_panel = PanelContainer.new()
	tip_panel.name = "Tip"
	tip_panel.add_theme_stylebox_override("panel", flat(Color(UiKit.UMBER_DARK, 0.92), UiKit.BRONZE, 3))
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.visible = false
	tip_label = _lbl("", HORIZONTAL_ALIGNMENT_LEFT)
	tip_panel.add_child(tip_label)
	root.add_child(tip_panel)
	result_panel = PanelContainer.new()
	result_panel.name = "Result"
	result_panel.add_theme_stylebox_override("panel", flat(Color(UiKit.UMBER_DARK, 0.96), UiKit.BRONZE_LIGHT, 10))
	result_panel.visible = false
	result_panel.custom_minimum_size = Vector2(300, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	result_panel.add_child(v)
	result_title = Label.new()
	result_title.theme_type_variation = &"TitleLabel"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body = _lbl("", HORIZONTAL_ALIGNMENT_CENTER)
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.custom_minimum_size = Vector2(280, 0)
	result_button = UiKit.button("cbt_continue")
	result_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result_button.pressed.connect(func() -> void: result_closed.emit())
	v.add_child(result_title); v.add_child(result_body); v.add_child(result_button)
	root.add_child(result_panel)

func _lbl(text: String, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ---- updates --------------------------------------------------------------------

## entries: [{uid, name, side, summoned, active, downed}] in initiative order.
func set_turn_order(entries: Array) -> void:
	for c in order_box.get_children():
		order_box.remove_child(c)
		c.queue_free()
	for e in entries:
		var chip := PanelContainer.new()
		var col: Color = Color("8fd06a") if e.get("summoned", false) else (UiKit.BRONZE if e.side == "party" else Color("c04040"))
		var active: bool = e.get("active", false)
		chip.add_theme_stylebox_override("panel", flat(UiKit.WOOD if active else Color(UiKit.UMBER_DARK, 0.85),
			UiKit.PARCHMENT if active else col, 2))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _lbl(str(e.get("name", "")).get_slice(",", 0), HORIZONTAL_ALIGNMENT_CENTER)
		if e.get("downed", false): l.theme_type_variation = &"DimLabel"
		else: l.add_theme_color_override("font_color", UiKit.PARCHMENT if active else col.lightened(0.3))
		chip.add_child(l)
		chip.set_meta(&"uid", int(e.get("uid", -1)))
		order_box.add_child(chip)

func set_round(n: int) -> void:
	round_label.text = Txt.trf("cbt_round", n)

func set_timer(turns_left: int) -> void:
	timer_label.visible = turns_left > 0
	timer_label.text = Txt.trf("cbt_timer", turns_left)

func set_fast(on: bool) -> void:
	speed_label.visible = on

## info: {name, hp, max_hp, mana, max_mana, charge, max_charge, ap, ap_max}
func set_active_unit(info: Dictionary) -> void:
	name_label.text = str(info.get("name", ""))
	_set_bar(hp_bar, hp_text, int(info.get("hp", 0)), int(info.get("max_hp", 0)))
	_set_bar(mana_bar, mana_text, int(info.get("mana", 0)), int(info.get("max_mana", 0)))
	_set_bar(charge_bar, charge_text, int(info.get("charge", 0)), int(info.get("max_charge", 0)))
	set_ap(int(info.get("ap", 0)), int(info.get("ap_max", 0)))

func _set_bar(b: ProgressBar, t: Label, v: int, mx: int) -> void:
	b.get_parent().visible = mx > 0
	b.max_value = maxi(1, mx)
	b.value = v
	t.text = "%d/%d" % [v, mx]

func set_ap(value: int, max_value: int) -> void:
	ap = value
	ap_max = maxi(max_value, value)
	ap_pips.queue_redraw()

func _draw_pips() -> void:
	for i in ap_max:
		var x: float = i * 5.0
		ap_pips.draw_rect(Rect2(x, 0, 4, 6), UiKit.INK, true)
		ap_pips.draw_rect(Rect2(x, 0, 4, 6), UiKit.BRONZE_LIGHT if i < ap else UiKit.WOOD, i < ap)

## items: [{label, sub, enabled, tooltip, selected}] up to MAX_BUTTONS.
func set_abilities(items: Array) -> void:
	for i in ability_buttons.size():
		var b: Button = ability_buttons[i]
		if i >= items.size():
			b.visible = false
			continue
		var it: Dictionary = items[i]
		b.visible = true
		b.text = "%d %s\n  %s" % [i + 1, it.get("label", ""), it.get("sub", "")]
		b.disabled = not it.get("enabled", false)
		b.tooltip_text = str(it.get("tooltip", ""))
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		var sel: bool = it.get("selected", false)
		b.add_theme_stylebox_override("normal", flat(UiKit.WOOD if sel else UiKit.UMBER, UiKit.BRONZE_LIGHT if sel else UiKit.WOOD, 3))

func set_controls(enabled: bool, can_flee: bool) -> void:
	end_button.disabled = not enabled
	flee_button.disabled = not (enabled and can_flee)
	if not enabled:
		for b in ability_buttons: b.disabled = true

func show_tip(text: String, screen_pos: Vector2) -> void:
	if text == "":
		tip_panel.visible = false
		return
	tip_label.text = text
	tip_panel.visible = true
	tip_panel.reset_size()
	var p: Vector2 = screen_pos + Vector2(10, -tip_panel.size.y - 4)
	var vp: Vector2 = root.get_viewport_rect().size
	p.x = clampf(p.x, 2, vp.x - tip_panel.size.x - 2)
	p.y = clampf(p.y, 20, vp.y - BAR_H - tip_panel.size.y - 2)
	tip_panel.position = p

func show_banner(text: String, alien: bool, hold: float, speed: float) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", UiKit.CYAN if alien else UiKit.BRONZE_LIGHT)
	if _banner_tween != null: _banner_tween.kill()
	banner_label.modulate.a = 1.0
	_banner_tween = banner_label.create_tween()
	_banner_tween.tween_interval(hold / speed)
	_banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.4 / speed)

func show_result(title: String, body: String) -> void:
	result_title.text = title
	result_body.text = body
	result_panel.visible = true
	tip_panel.visible = false
	result_panel.reset_size()
	var vp: Vector2 = root.get_viewport_rect().size
	result_panel.position = ((vp - Vector2(0, BAR_H)) - result_panel.size) / 2.0
