## Scroll mode: the Dacian Scrolls on a parchment (12 page slots in page `order`, found pages
## open to their text with Fanfi's margin note, missing ones are torn gaps), the quest log, and
## the save/load screen (3 manual slots). Router.args: {tab?: "pages"|"quests"|"saves",
## page?: page id to open, return_mode?, return_args?}. Esc or Back returns to the world.
class_name ScrollMode
extends Control

const PARCHMENT_PATH: String = "res://assets/screens/parchment.png"
const TABS: Array[StringName] = [&"pages", &"quests", &"saves"]
const MANUAL_SLOTS: Array[int] = [1, 2, 3]
const PAGE_COUNT: int = 12
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
const INK_DARK := Color("3a2318")      # palette brown0
const INK_MID := Color("5e3b25")       # palette brown1
const INK_FADED := Color("8a5a34")     # palette brown2
const INK_RED := Color("963131")       # palette red1
const HOLE := Color("1a1218")          # palette outline
const SHEET_RECT: Rect2 = Rect2(16, 12, 608, 336)
const CONTENT_RECT: Rect2 = Rect2(40, 66, 560, 254)

var tab: StringName = &"pages"
var page_defs: Array[Dictionary] = []   # sorted by order, at most 12
var slots: Array[Button] = []           # one per page slot, in order
var save_cards: Dictionary = {}         # slot -> {panel, status, save, load}
var reading: StringName = &""
var reader_title: Label
var reader_body: Label
var reader_note: Label
var btn_back: Button
var tab_buttons: Dictionary = {}
var _views: Dictionary = {}
var _count_label: Label
var _confirm_slot: int = -1
var _return_mode: StringName = &"worldmap"
var _return_args: Dictionary = {}

func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pick_return()
	var bg := _Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sheet := TextureRect.new()
	sheet.texture = Assets.load_png(PARCHMENT_PATH)
	sheet.position = SHEET_RECT.position
	sheet.size = SHEET_RECT.size
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)

	var title: Label = _ink(UiKit.label("scroll_title"), INK_DARK)
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_color_override(&"font_color", INK_DARK)
	title.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	title.position = Vector2(40, 24)
	add_child(title)
	_count_label = _ink(UiKit.label(""), INK_FADED)
	_count_label.position = Vector2(42, 48)
	add_child(_count_label)

	var bar := HBoxContainer.new()
	bar.position = Vector2(352, 28)
	bar.add_theme_constant_override(&"separation", 3)
	add_child(bar)
	for t in TABS:
		var b: Button = _ink_button("scroll_tab_" + t)
		b.toggle_mode = true
		b.pressed.connect(show_tab.bind(t))
		bar.add_child(b)
		tab_buttons[t] = b
	var gap := Control.new()
	gap.custom_minimum_size.x = 6
	bar.add_child(gap)
	btn_back = _ink_button("scroll_back")
	btn_back.pressed.connect(go_back)
	bar.add_child(btn_back)
	bar.position.x = SHEET_RECT.end.x - 30 - bar.get_combined_minimum_size().x

	var hint: Label = _ink(UiKit.label("scroll_hint"), INK_FADED)
	hint.position = Vector2(42, 322)
	add_child(hint)

	page_defs = _sorted_pages()
	_views[&"pages"] = _build_pages()
	_views[&"reader"] = _build_reader()
	_views[&"quests"] = _build_quests()
	_views[&"saves"] = _build_saves()
	for k in _views: add_child(_views[k])
	refresh_count()
	var want: StringName = StringName(str(Router.args.get("tab", "pages")))
	show_tab(want if TABS.has(want) else &"pages")
	var page: StringName = StringName(str(Router.args.get("page", "")))
	if page != &"": open_page(page)

## Where Back goes: explicit return args, else the mode the game was in, else the world map.
func _pick_return() -> void:
	if Router.args.has("return_mode"):
		_return_mode = StringName(str(Router.args.return_mode))
		_return_args = Router.args.get("return_args", {})
		return
	var m: StringName = Game.state.mode
	if m == &"scroll" or m == &"menu" or m == &"combat" or m == &"":
		m = &"location" if Game.state.location_id != &"" else &"worldmap"
	_return_mode = m
	_return_args = {}
	if m == &"location":
		_return_args = {"location_id": Game.state.location_id, "cell": Game.state.location_cell}

func return_target() -> Array:
	return [_return_mode, _return_args]

func go_back() -> void:
	Router.go(_return_mode, _return_args)

func show_tab(t: StringName) -> void:
	tab = t
	reading = &""
	_confirm_slot = -1
	for k in _views: (_views[k] as Control).visible = k == t
	for k in tab_buttons: (tab_buttons[k] as Button).set_pressed_no_signal(k == t)
	if t == &"saves": refresh_saves()
	var first: Control = null
	match t:
		&"pages": first = slots[0] if not slots.is_empty() else null
		&"saves": first = save_cards[1].save if save_cards.has(1) else null
	if first == null: first = tab_buttons[t]
	PartyScreen.focus_later(first)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if reading != &"": show_tab(&"pages")
		else: go_back()

func refresh_count() -> void:
	var n: int = 0
	for d in page_defs:
		if Game.state.pages.has(StringName(str(d.id))): n += 1
	_count_label.text = PartyScreen.fmt("scroll_count", [n, PAGE_COUNT])

# ---- pages ---------------------------------------------------------------------------------

func _sorted_pages() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if Content.defs != null: out = Content.all(&"page").duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	if out.size() > PAGE_COUNT: out.resize(PAGE_COUNT)
	return out

func _build_pages() -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = CONTENT_RECT.position
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	for i in PAGE_COUNT:
		var d: Dictionary = page_defs[i] if i < page_defs.size() else {}
		var id := StringName(str(d.get("id", "")))
		var s := _PageSlot.new()
		s.numeral = ROMAN[i]
		s.found = id != &"" and Game.state.pages.has(id)
		s.page_id = id
		s.custom_minimum_size = Vector2(134, 78)
		s.focus_mode = Control.FOCUS_ALL
		s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if s.found else Control.CURSOR_ARROW
		var l: Label = _ink(UiKit.label(str(d.get("title_key", "")) if s.found else "scroll_missing"), INK_DARK if s.found else INK_FADED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.position = Vector2(8, 24)
		l.size = Vector2(118, 44)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not s.found: l.add_theme_color_override(&"font_color", UiKit.PARCHMENT_DIM)
		s.add_child(l)
		s.title_label = l
		s.pressed.connect(_on_slot_pressed.bind(s))
		grid.add_child(s)
		slots.append(s)
	return grid

func _build_reader() -> Control:
	var root := Control.new()
	root.position = CONTENT_RECT.position
	root.size = CONTENT_RECT.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reader_title = _ink(UiKit.label(""), INK_DARK)
	reader_title.theme_type_variation = &"TitleLabel"
	reader_title.add_theme_color_override(&"font_color", INK_MID)
	reader_title.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	reader_title.position = Vector2(0, -4)
	root.add_child(reader_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 26)
	scroll.size = Vector2(352, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	reader_body = _ink(UiKit.label(""), INK_DARK)
	reader_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reader_body.custom_minimum_size.x = 340
	reader_body.add_theme_constant_override(&"line_spacing", 2)
	scroll.add_child(reader_body)
	# Fanfi's note in the margin, in red ink, set off by a ruled line.
	var rule := ColorRect.new()
	rule.color = Color(INK_FADED, 0.6)
	rule.position = Vector2(366, 28)
	rule.size = Vector2(1, 190)
	root.add_child(rule)
	var who: Label = _ink(UiKit.label("scroll_fanfi_margin"), INK_RED)
	who.position = Vector2(376, 26)
	root.add_child(who)
	reader_note = _ink(UiKit.label(""), INK_RED)
	reader_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reader_note.position = Vector2(376, 40)
	reader_note.custom_minimum_size.x = 180
	reader_note.size.x = 180
	root.add_child(reader_note)
	var nav := HBoxContainer.new()
	nav.position = Vector2(0, 234)
	nav.add_theme_constant_override(&"separation", 4)
	root.add_child(nav)
	var prev: Button = _ink_button("scroll_prev")
	prev.pressed.connect(_step_page.bind(-1))
	nav.add_child(prev)
	var all: Button = _ink_button("scroll_all_pages")
	all.pressed.connect(show_tab.bind(&"pages"))
	nav.add_child(all)
	var next: Button = _ink_button("scroll_next")
	next.pressed.connect(_step_page.bind(1))
	nav.add_child(next)
	return root

func _on_slot_pressed(s: _PageSlot) -> void:
	if s.found: open_page(s.page_id)

## Opens a found page in the reader. Missing pages do not open.
func open_page(id: StringName) -> bool:
	if not Game.state.pages.has(id): return false
	var d: Dictionary = {}
	var idx: int = -1
	for i in page_defs.size():
		if StringName(str(page_defs[i].id)) == id:
			d = page_defs[i]; idx = i
	if d.is_empty(): return false
	show_tab(&"pages")
	(_views[&"pages"] as Control).visible = false
	(_views[&"reader"] as Control).visible = true
	reading = id
	reader_title.text = "%s. %s" % [ROMAN[idx], tr(str(d.get("title_key", "")))]
	reader_body.text = tr(str(d.get("body_key", "")))
	var note_key: String = "scroll_fanfi_" + str(id)
	reader_note.text = tr(note_key) if tr(note_key) != note_key else tr("scroll_fanfi_default")
	return true

func _step_page(dir: int) -> void:
	var found: Array[StringName] = []
	for d in page_defs:
		var id := StringName(str(d.id))
		if Game.state.pages.has(id): found.append(id)
	if found.is_empty(): return
	var i: int = found.find(reading)
	open_page(found[posmod(i + dir, found.size())])

# ---- quests --------------------------------------------------------------------------------

func _build_quests() -> Control:
	var scroll := ScrollContainer.new()
	scroll.position = CONTENT_RECT.position
	scroll.size = CONTENT_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	scroll.add_child(v)
	var entries: Array[Dictionary] = QuestLog.entries(Game.state, Content.defs) if Content.defs != null else []
	if entries.is_empty():
		v.add_child(_ink(UiKit.label("scroll_quests_none"), INK_FADED))
	for e in entries:
		var name_l: Label = _ink(UiKit.label(""), INK_FADED if e.done else INK_DARK)
		name_l.text = tr(str(e.name_key)) + ("  " + tr("scroll_quest_done") if e.done else "")
		if not e.done: name_l.add_theme_color_override(&"font_color", INK_RED)
		v.add_child(name_l)
		var d: Label = _ink(UiKit.label(str(e.desc_key)), INK_FADED if e.done else INK_DARK)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 540
		v.add_child(d)
		var sp := Control.new()
		sp.custom_minimum_size.y = 6
		v.add_child(sp)
	return scroll

# ---- saves ---------------------------------------------------------------------------------

## What a save slot holds, read safely: {state: "empty"|"ok"|"damaged"|"too_new", day, pages, level}.
static func slot_info(slot: int) -> Dictionary:
	if not Game.has_save(slot): return {"state": "empty"}
	var text: String = FileAccess.get_file_as_string(Game.save_path(slot))
	var r: Dictionary = SaveCodec.decode(text)
	if not r.ok:
		return {"state": "too_new" if r.error_key == SaveCodec.TOO_NEW else "damaged"}
	var s: GameState = r.state
	var level: int = 1
	for m in s.party: level = maxi(level, m.level)
	return {"state": "ok", "day": s.day, "pages": s.pages.size(), "level": level}

func _build_saves() -> Control:
	var root := VBoxContainer.new()
	root.position = CONTENT_RECT.position + Vector2(0, 4)
	root.add_theme_constant_override(&"separation", 8)
	var intro: Label = _ink(UiKit.label("scroll_saves_intro"), INK_FADED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 556
	root.add_child(intro)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	root.add_child(row)
	for slot in MANUAL_SLOTS:
		var card := _SlotCard.new()
		card.custom_minimum_size = Vector2(178, 112)
		row.add_child(card)
		var v := VBoxContainer.new()
		v.position = Vector2(10, 8)
		v.custom_minimum_size.x = 158
		v.add_theme_constant_override(&"separation", 2)
		card.add_child(v)
		var t: Label = _ink(UiKit.label(""), INK_MID)
		t.text = PartyScreen.fmt("scroll_slot", [ROMAN[slot - 1]])
		v.add_child(t)
		var status: Label = _ink(UiKit.label(""), INK_DARK)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.custom_minimum_size = Vector2(158, 58)
		v.add_child(status)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override(&"separation", 4)
		v.add_child(btns)
		var sb: Button = _ink_button("scroll_save")
		sb.pressed.connect(save_to.bind(slot))
		btns.add_child(sb)
		var lb: Button = _ink_button("scroll_load")
		lb.pressed.connect(load_from.bind(slot))
		btns.add_child(lb)
		save_cards[slot] = {"panel": card, "status": status, "save": sb, "load": lb}
	return root

func refresh_saves() -> void:
	for slot in save_cards:
		var c: Dictionary = save_cards[slot]
		var info: Dictionary = slot_info(slot)
		var st: String = info.state
		var status: Label = c.status
		var card: _SlotCard = c.panel
		card.damaged = st == "damaged" or st == "too_new"
		card.empty = st == "empty"
		card.queue_redraw()
		match st:
			"empty": status.text = tr("scroll_slot_empty")
			"damaged": status.text = tr("scroll_slot_damaged")
			"too_new": status.text = tr("scroll_slot_too_new")
			_: status.text = PartyScreen.fmt("scroll_slot_info", [info.day, info.pages, PAGE_COUNT, info.level])
		status.add_theme_color_override(&"font_color", INK_RED if card.damaged else (INK_FADED if card.empty else INK_DARK))
		(c.load as Button).disabled = st != "ok"
		(c.save as Button).disabled = Game.state.party.is_empty()
		(c.save as Button).text = tr("scroll_save")

## Saves the game into a manual slot (asks once before overwriting). The slot resumes in the
## mode the scroll returns to, not in the scroll itself.
func save_to(slot: int, confirmed: bool = false) -> Error:
	if Game.state.party.is_empty(): return ERR_UNAVAILABLE
	if Game.has_save(slot) and not confirmed and _confirm_slot != slot:
		_confirm_slot = slot
		(save_cards[slot].save as Button).text = tr("scroll_overwrite")
		return ERR_BUSY
	_confirm_slot = -1
	var was: StringName = Game.state.mode
	Game.state.mode = _return_mode
	var err: Error = Game.save(slot)
	Game.state.mode = was
	if err == OK:
		var ev: Array[Dictionary] = [{"type": "saved", "slot": slot}]
		Bus.emit_events(ev)
	else:
		Bus.toast.emit("scroll_save_failed")
	refresh_saves()
	return err

func load_from(slot: int) -> Error:
	var err: Error = Game.load_slot(slot)
	if err != OK:
		refresh_saves()
		return err
	var m: StringName = Game.state.mode
	if m == &"location":
		Router.go(m, {"location_id": Game.state.location_id, "cell": Game.state.location_cell})
	elif m == &"scroll" or m == &"menu" or m == &"combat":
		Router.go(&"worldmap")
	else:
		Router.go(m)
	return OK

# ---- helpers -------------------------------------------------------------------------------

func _ink(l: Label, c: Color) -> Label:
	l.add_theme_color_override(&"font_color", c)
	l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	return l

## Buttons drawn in ink on the parchment.
func _ink_button(key: String) -> Button:
	var b: Button = UiKit.button(key)
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(1)
		s.anti_aliasing = false
		s.content_margin_left = 6; s.content_margin_right = 6
		s.content_margin_top = 2; s.content_margin_bottom = 2
		return s
	b.add_theme_stylebox_override(&"normal", mk.call(Color(UiKit.PARCHMENT, 0.0), INK_FADED))
	b.add_theme_stylebox_override(&"hover", mk.call(Color("d6a043", 0.35), INK_MID))
	b.add_theme_stylebox_override(&"pressed", mk.call(Color("d6a043", 0.6), INK_DARK))
	b.add_theme_stylebox_override(&"hover_pressed", mk.call(Color("d6a043", 0.7), INK_DARK))
	b.add_theme_stylebox_override(&"disabled", mk.call(Color(0, 0, 0, 0), Color(INK_FADED, 0.4)))
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.border_color = INK_RED
	f.set_border_width_all(1)
	f.expand_margin_left = 1; f.expand_margin_right = 1; f.expand_margin_top = 1; f.expand_margin_bottom = 1
	b.add_theme_stylebox_override(&"focus", f)
	for k in [&"font_color", &"font_pressed_color"]: b.add_theme_color_override(k, INK_DARK)
	for k in [&"font_hover_color", &"font_focus_color", &"font_hover_pressed_color"]: b.add_theme_color_override(k, INK_RED)
	b.add_theme_color_override(&"font_disabled_color", Color(INK_FADED, 0.6))
	return b

## Dark wood desk behind the scroll, with a candle glow.
class _Backdrop extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.UMBER_DARK)
		var y: int = 0
		var i: int = 0
		while y < int(size.y):
			draw_rect(Rect2(0, y, size.x, 1), Color(UiKit.INK, 0.5))
			for k in 3:
				var x: float = fposmod(i * 131.0 + k * 211.0, size.x)
				draw_rect(Rect2(x, y + 4, 40 + k * 12, 1), Color(UiKit.WOOD, 0.35))
			y += 18; i += 1
		draw_rect(Rect2(Vector2(20, 20), size - Vector2(40, 40)), Color(UiKit.INK, 0.0))

## One page slot: a pinned page when found, a torn gap when missing.
class _PageSlot extends Button:
	var numeral: String = ""
	var found: bool = false
	var page_id: StringName = &""
	var title_label: Label
	func _init() -> void:
		flat = true
		var empty := StyleBoxEmpty.new()
		for s in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			add_theme_stylebox_override(s, empty)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT \
				or what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var f: Font = UiKit.font()
		var hot: bool = has_focus() or is_hovered()
		if found:
			draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color("8a5a34", 0.45))
			draw_rect(r, Color("f4efe2") if hot else Color("efd391"))
			draw_rect(r.grow(-3), Color("d6a043", 0.18))
			draw_rect(r, Color("5e3b25") if not hot else Color("963131"), false, 1.0)
			# Red wax seal with the numeral.
			draw_rect(Rect2(size.x / 2 - 12, 4, 24, 13), Color("963131"))
			draw_rect(Rect2(size.x / 2 - 12, 4, 24, 13), Color("5a1d22"), false, 1.0)
			var w: float = f.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE).x
			draw_string(f, Vector2(size.x / 2 - w / 2, 14), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE, Color("efd391"))
		else:
			# A ragged hole torn out of the parchment.
			var pts := PackedVector2Array()
			var n: int = 18
			var seed_v: int = numeral.hash()
			for k in n:
				var t: float = TAU * k / n
				var jag: float = 0.78 + 0.22 * float(absi((seed_v >> (k % 16)) * 7 + k * 13) % 10) / 10.0
				pts.append(size / 2 + Vector2(cos(t) * size.x * 0.47, sin(t) * size.y * 0.45) * jag)
			var edge := PackedVector2Array()
			for p in pts: edge.append(size / 2 + (p - size / 2) * 1.07)
			draw_colored_polygon(edge, Color("b88550"))
			draw_colored_polygon(pts, Color("1a1218"))
			draw_colored_polygon(_shrink(pts, 0.75), Color("1e1611"))
			var w: float = f.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE).x
			draw_string(f, Vector2(size.x / 2 - w / 2, 22), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE, Color("6b5a48"))
			if hot: draw_polyline(edge + PackedVector2Array([edge[0]]), Color("963131"), 1.0)
	func _shrink(pts: PackedVector2Array, k: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts: out.append(size / 2 + (p - size / 2) * k)
		return out

## A save slot drawn as a pinned card on the parchment; damaged slots are scorched.
class _SlotCard extends Control:
	var damaged: bool = false
	var empty: bool = true
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color("8a5a34", 0.45))
		draw_rect(r, Color("efd391") if not empty else Color("efd391", 0.55))
		draw_rect(r, Color("5e3b25"), false, 1.0)
		if damaged:
			# A burnt corner: charred ragged edge, scorched halo.
			var c := Vector2(size.x, size.y)
			var halo := PackedVector2Array([c, c - Vector2(78, 0), c - Vector2(70, 12), c - Vector2(52, 22), c - Vector2(40, 40), c - Vector2(20, 52), c - Vector2(0, 64)])
			var burn := PackedVector2Array([c, c - Vector2(60, 0), c - Vector2(54, 9), c - Vector2(40, 16), c - Vector2(30, 30), c - Vector2(14, 40), c - Vector2(0, 50)])
			draw_colored_polygon(halo, Color("8a5a34", 0.55))
			draw_colored_polygon(burn, Color("1a1218"))
			draw_polyline(burn, Color("d6a043", 0.8), 1.0)
		draw_rect(Rect2(size.x / 2 - 2, -3, 5, 5), Color("77787e"))
		draw_rect(Rect2(size.x / 2 - 1, -2, 3, 3), Color("d5d2c6"))
