## Party overlay: stats, gear, equipping up to 4 abilities, using items. Implemented by WP-24.
## Every state change goes through Rules.run (items, so events fire) and is broadcast on Bus.
## Esc or Close emits `closed`.
class_name PartyScreen
extends Control

signal closed

const KIND_COLORS: Dictionary = {
	"weapon": Color("a6a59f"), "armor": Color("8a5a34"), "trinket": Color("d6a043"),
	"consumable": Color("71913f"), "salvage": Color("3fe3ea"), "quest": Color("963131"),
}
const GEAR_KIND: Dictionary = {"weapon": "weapon", "armor": "armor", "trinket": "trinket"}
const STAT_KEYS: Array[String] = ["might", "agility", "wits", "spirit"]
const PANEL_RECT: Rect2 = Rect2(8, 8, 624, 344)
const COL_W: int = 192
const INK_DARK := Color("3a2318")      # palette brown0
const INK_FADED := Color("8a5a34")     # palette brown2
const INK_RED := Color("963131")       # palette red1

static var _ink_theme: Theme

var member: int = 0
var _body: HBoxContainer
var _tabs: HBoxContainer
var _gold: Label
var _desc: Label
var btn_close: Button
var ability_boxes: Dictionary = {}     # ability id -> CheckBox
var item_rows: Dictionary = {}         # item id -> HBoxContainer
var gear_buttons: Dictionary = {}      # slot -> Button

## Adds the screen on top of `parent` (in its own CanvasLayer) and returns it.
static func show_over(parent: Node) -> PartyScreen:
	var s := PartyScreen.new()
	var layer := CanvasLayer.new()
	layer.layer = 50
	parent.add_child(layer)
	layer.add_child(s)
	s.closed.connect(layer.queue_free)
	return s

## The UiKit theme with ink-coloured text, for labels drawn on the parchment of the panel.
static func ink_theme() -> Theme:
	if _ink_theme != null: return _ink_theme
	var t: Theme = UiKit.theme().duplicate()
	t.set_color("font_color", "Label", INK_DARK)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_color("font_color", "DimLabel", INK_FADED)
	t.set_color("font_color", "TitleLabel", INK_RED)
	t.set_color("font_shadow_color", "TitleLabel", Color("d6a043", 0.6))
	t.set_constant("shadow_offset_x", "TitleLabel", 1)
	t.set_constant("shadow_offset_y", "TitleLabel", 1)
	t.set_color("font_color", "CheckBox", INK_DARK)
	t.set_color("font_pressed_color", "CheckBox", INK_DARK)
	t.set_color("font_hover_color", "CheckBox", INK_RED)
	t.set_color("font_focus_color", "CheckBox", INK_RED)
	t.set_color("font_hover_pressed_color", "CheckBox", INK_RED)
	t.set_icon("checked", "CheckBox", UiKit._icon(["#######", "#.....#", "#.###.#", "#.###.#", "#.###.#", "#.....#", "#######"], INK_RED))
	t.set_icon("unchecked", "CheckBox", UiKit._icon(["#######", "#.....#", "#.....#", "#.....#", "#.....#", "#.....#", "#######"], INK_FADED))
	t.set_stylebox("hover", "CheckBox", UiKit._box(Color("d6a043", 0.35), Color(0, 0, 0, 0), 0))
	_ink_theme = t
	return t

## UiKit.label in ink.
static func ink_label(key: String) -> Label:
	var l: Label = UiKit.label(key)
	l.theme = ink_theme()
	return l

## tr(key) % args, but a missing key (or one without placeholders) never raises a format error.
static func fmt(key: String, args: Array) -> String:
	var t: String = TranslationServer.translate(key)
	if t.count("%") - t.count("%%") * 2 != args.size(): return t
	return t % args

## A small square in the colour of an item kind (shared with ShopScreen).
static func kind_swatch(kind: String) -> Control:
	var c := ColorRect.new()
	c.color = KIND_COLORS.get(kind, UiKit.PARCHMENT_DIM)
	c.custom_minimum_size = Vector2(6, 6)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## "+2 Damage, -1 Agility" for an item's mods.
static func mods_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	var mods: Variant = item.get("mods", {})
	if mods is Dictionary:
		for k in mods:
			var n: int = int(mods[k])
			parts.append("%s%d %s" % ["+" if n >= 0 else "", n, TranslationServer.translate("stat_" + str(k))])
	return ", ".join(parts)

func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p: PanelContainer = UiKit.panel()
	p.position = PANEL_RECT.position
	p.custom_minimum_size = PANEL_RECT.size
	p.size = PANEL_RECT.size
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 4)
	p.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var title: Label = ink_label("party_title")
	title.theme_type_variation = &"TitleLabel"
	head.add_child(title)
	_tabs = HBoxContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tabs)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_gold = ink_label("")
	_gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_gold)

	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 10)
	v.add_child(_body)

	var foot := HBoxContainer.new()
	v.add_child(foot)
	_desc = ink_label("party_hint")
	_desc.theme_type_variation = &"DimLabel"
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc.custom_minimum_size = Vector2(0, 24)
	foot.add_child(_desc)
	btn_close = UiKit.button("screen_close")
	btn_close.size_flags_vertical = Control.SIZE_SHRINK_END
	btn_close.pressed.connect(close)
	foot.add_child(btn_close)
	refresh()
	btn_close.grab_focus.call_deferred()

func close() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func current() -> Character:
	var party: Array[Character] = Game.state.party
	if party.is_empty(): return null
	return party[clampi(member, 0, party.size() - 1)]

func select_member(i: int) -> void:
	member = clampi(i, 0, maxi(0, Game.state.party.size() - 1))
	refresh()

# ---- actions -------------------------------------------------------------------------------

## Equips or unequips an ability for the current member. Refuses a 5th with a toast.
func toggle_ability(ability: StringName) -> bool:
	var c: Character = current()
	if c == null or not c.known.has(ability): return false
	if c.equipped.has(ability):
		c.equipped.erase(ability)
	elif c.equipped.size() >= Character.MAX_EQUIPPED:
		Bus.toast.emit("party_abilities_full")
		refresh()
		return false
	else:
		c.equipped.append(ability)
	refresh()
	return true

## Moves a weapon, armour or trinket from the pack onto the current member; the old one goes
## back into the pack.
func equip(item_id: StringName) -> bool:
	var c: Character = current()
	var def: Dictionary = Content.get_def(&"item", item_id) if Content.has(&"item", item_id) else {}
	var slot: String = GEAR_KIND.get(str(def.get("kind", "")), "")
	if c == null or slot == "" or int(Game.state.inventory.get(item_id, 0)) <= 0: return false
	var fx: Array = [["take_item", str(item_id), 1]]
	var old: StringName = c.gear.get(slot, &"")
	if old != &"": fx.append(["give_item", str(old), 1])
	var events: Array[Dictionary] = Rules.run(fx, Game.state, Game.rng, Content.defs)
	c.gear[slot] = item_id
	Bus.emit_events(events)
	refresh()
	return true

func unequip(slot: String) -> bool:
	var c: Character = current()
	if c == null: return false
	var old: StringName = c.gear.get(slot, &"")
	if old == &"": return false
	c.gear[slot] = &""
	Bus.emit_events(Rules.run([["give_item", str(old), 1]], Game.state, Game.rng, Content.defs))
	refresh()
	return true

## Runs the item's use_effects, then takes one. Returns the events (also broadcast).
func use_item(item_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if int(Game.state.inventory.get(item_id, 0)) <= 0 or not Content.has(&"item", item_id): return out
	var fx: Variant = Content.get_def(&"item", item_id).get("use_effects", [])
	if not (fx is Array) or (fx as Array).is_empty(): return out
	out = Rules.run(fx, Game.state, Game.rng, Content.defs)
	out.append_array(Rules.run([["take_item", str(item_id), 1]], Game.state, Game.rng, Content.defs))
	Bus.emit_events(out)
	refresh()
	return out

# ---- building ------------------------------------------------------------------------------

func refresh() -> void:
	if _body == null: return
	_gold.text = fmt("screen_gold_food", [Game.state.gold, Game.state.food])
	for n in _tabs.get_children(): n.queue_free()
	for i in Game.state.party.size():
		var m: Character = Game.state.party[i]
		var b: Button = UiKit.button(m.name_key)
		b.toggle_mode = true
		b.button_pressed = i == member
		b.pressed.connect(select_member.bind(i))
		_tabs.add_child(b)
	for n in _body.get_children():
		_body.remove_child(n)
		n.queue_free()
	ability_boxes.clear(); item_rows.clear(); gear_buttons.clear()
	var c: Character = current()
	if c == null: return
	_body.add_child(_column_stats(c))
	_body.add_child(_column_gear(c))
	_body.add_child(_column_pack())

func _column(w: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = w
	v.add_theme_constant_override(&"separation", 2)
	return v

func _header(key: String, extra: String = "") -> Label:
	var l: Label = ink_label(key)
	l.add_theme_color_override(&"font_color", INK_RED)
	if extra != "": l.text += " " + extra
	return l

func _column_stats(c: Character) -> VBoxContainer:
	var col := _column(COL_W)
	var cls: Dictionary = Content.get_def(&"class", c.class_id) if Content.has(&"class", c.class_id) else {}
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 6)
	col.add_child(top)
	top.add_child(_portrait(cls))
	var who := VBoxContainer.new()
	who.add_theme_constant_override(&"separation", 1)
	top.add_child(who)
	who.add_child(ink_label(c.name_key))
	var cl: Label = ink_label(str(cls.get("name_key", "")))
	cl.theme_type_variation = &"DimLabel"
	who.add_child(cl)
	var lv: Label = ink_label("")
	lv.text = fmt("party_level", [c.level])
	lv.add_theme_color_override(&"font_color", INK_RED)
	who.add_child(lv)
	var need: int = Formulas.xp_to_next(c.level)
	who.add_child(_bar_row("party_xp", c.xp, need, INK_RED, 74))
	col.add_child(_gap(2))
	col.add_child(_bar_row("party_hp", c.hp, c.max_hp, UiKit.BLOOD, 110))
	col.add_child(_bar_row("party_mana", c.mana, c.max_mana, Color("6f8ebe"), 110))
	col.add_child(_bar_row("party_charge", c.charge, c.max_charge, Color("efd391"), 110))
	col.add_child(_gap(4))
	col.add_child(_header("party_stats"))
	var bonus: Dictionary = _gear_bonus(c)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 1)
	col.add_child(grid)
	for k in STAT_KEYS:
		var name_l: Label = ink_label("stat_" + k)
		name_l.theme_type_variation = &"DimLabel"
		name_l.custom_minimum_size.x = 70
		grid.add_child(name_l)
		var val: Label = ink_label("")
		var b: int = int(bonus.get(k, 0))
		val.text = str(int(c.stats.get(k, 0))) + ("" if b == 0 else " (%s%d)" % ["+" if b > 0 else "", b])
		grid.add_child(val)
	var dmg: int = int(bonus.get("damage", 0))
	var arm: int = int(bonus.get("armor", 0))
	for pair in [["stat_damage", dmg], ["stat_armor", arm]]:
		var nl: Label = ink_label(pair[0])
		nl.theme_type_variation = &"DimLabel"
		grid.add_child(nl)
		var vl: Label = ink_label("")
		vl.text = "+%d" % pair[1]
		grid.add_child(vl)
	return col

func _column_gear(c: Character) -> VBoxContainer:
	var col := _column(COL_W)
	col.add_child(_header("party_gear"))
	for slot in Character.GEAR_SLOTS:
		var row := HBoxContainer.new()
		col.add_child(row)
		var sl: Label = ink_label("party_slot_" + slot)
		sl.theme_type_variation = &"DimLabel"
		sl.custom_minimum_size.x = 50
		row.add_child(sl)
		var id: StringName = c.gear.get(slot, &"")
		var def: Dictionary = Content.get_def(&"item", id) if id != &"" and Content.has(&"item", id) else {}
		var b: Button = UiKit.button(str(def.get("name_key", "party_slot_empty")))
		b.custom_minimum_size.x = 134
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = id == &""
		b.pressed.connect(unequip.bind(slot))
		b.mouse_entered.connect(_describe.bind(def, "party_click_unequip"))
		b.focus_entered.connect(_describe.bind(def, "party_click_unequip"))
		row.add_child(b)
		gear_buttons[slot] = b
	col.add_child(_gap(4))
	col.add_child(_header("party_abilities", "%d/%d" % [c.equipped.size(), Character.MAX_EQUIPPED]))
	for a in c.known:
		var ad: Dictionary = Content.get_def(&"ability", a) if Content.has(&"ability", a) else {}
		var box := CheckBox.new()
		box.theme = ink_theme()
		box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.text = tr(str(ad.get("name_key", a)))
		box.button_pressed = c.equipped.has(a)
		box.focus_mode = Control.FOCUS_ALL
		box.toggled.connect(func(_on: bool) -> void: toggle_ability(a))
		box.mouse_entered.connect(_describe_ability.bind(ad))
		box.focus_entered.connect(_describe_ability.bind(ad))
		col.add_child(box)
		ability_boxes[a] = box
	return col

func _column_pack() -> VBoxContainer:
	var col := _column(COL_W + 18)
	col.add_child(_header("party_pack"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 1)
	scroll.add_child(list)
	var ids: Array = Game.state.inventory.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return _sort_key(a) < _sort_key(b))
	if ids.is_empty():
		var e: Label = ink_label("party_pack_empty")
		e.theme_type_variation = &"DimLabel"
		list.add_child(e)
	for id in ids:
		var item := StringName(str(id))
		var def: Dictionary = Content.get_def(&"item", item) if Content.has(&"item", item) else {}
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 3)
		list.add_child(row)
		row.add_child(kind_swatch(str(def.get("kind", ""))))
		var nl: Label = ink_label("")
		nl.text = "%s x%d" % [tr(str(def.get("name_key", item))), int(Game.state.inventory[id])]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		nl.mouse_entered.connect(_describe.bind(def, ""))
		row.add_child(nl)
		var kind: String = str(def.get("kind", ""))
		if GEAR_KIND.has(kind):
			var eb: Button = UiKit.button("party_equip")
			eb.pressed.connect(func() -> void: equip(item))
			eb.mouse_entered.connect(_describe.bind(def, ""))
			eb.focus_entered.connect(_describe.bind(def, ""))
			row.add_child(eb)
		var fx: Variant = def.get("use_effects", [])
		if (fx is Array and not (fx as Array).is_empty()) or kind == "consumable":
			var ub: Button = UiKit.button("party_use")
			ub.disabled = not (fx is Array and not (fx as Array).is_empty())
			ub.pressed.connect(func() -> void: use_item(item))
			ub.mouse_entered.connect(_describe.bind(def, "party_battle_only" if ub.disabled else ""))
			ub.focus_entered.connect(_describe.bind(def, "party_battle_only" if ub.disabled else ""))
			row.add_child(ub)
		item_rows[item] = row
	return col

func _sort_key(id: Variant) -> String:
	var order: Array[String] = ["consumable", "weapon", "armor", "trinket", "salvage", "quest"]
	var def: Dictionary = Content.get_def(&"item", StringName(str(id))) if Content.has(&"item", StringName(str(id))) else {}
	return "%d_%s" % [order.find(str(def.get("kind", ""))) + 1, str(id)]

func _gear_bonus(c: Character) -> Dictionary:
	var out: Dictionary = {}
	for slot in Character.GEAR_SLOTS:
		var id: StringName = c.gear.get(slot, &"")
		if id == &"" or not Content.has(&"item", id): continue
		var mods: Variant = Content.get_def(&"item", id).get("mods", {})
		if mods is Dictionary:
			for k in mods: out[str(k)] = int(out.get(str(k), 0)) + int(mods[k])
	return out

func _bar_row(key: String, value: int, max_value: int, color: Color, w: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var l: Label = ink_label(key)
	l.theme_type_variation = &"DimLabel"
	l.custom_minimum_size.x = 18 if w < 100 else 44
	row.add_child(l)
	var b: ProgressBar = UiKit.bar(color)
	b.max_value = maxi(1, max_value)
	b.value = clampi(value, 0, maxi(1, max_value))
	b.custom_minimum_size = Vector2(w - 44 if w >= 100 else w - 30, 5)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	var n: Label = ink_label("")
	n.text = "%d/%d" % [value, max_value]
	row.add_child(n)
	return row

func _portrait(cls: Dictionary) -> Control:
	var frame := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = UiKit.INK
	st.border_color = UiKit.BRONZE
	st.set_border_width_all(1)
	st.set_content_margin_all(2)
	frame.add_theme_stylebox_override(&"panel", st)
	frame.custom_minimum_size = Vector2(44, 56)
	var tex: Texture2D = null
	var pid := StringName(str(cls.get("portrait", "")))
	var sid := StringName(str(cls.get("sprite", "")))
	if pid != &"" and Assets.has_tex(pid): tex = Assets.tex(pid)
	elif sid != &"" and Assets.manifest.frames.has(String(sid)):
		var sf: SpriteFrames = Assets.frames(sid)
		if sf.has_animation(&"idle") and sf.get_frame_count(&"idle") > 0:
			tex = sf.get_frame_texture(&"idle", 0)
	if tex != null:
		var tr_ := TextureRect.new()
		tr_.texture = tex
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tr_.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.add_child(tr_)
	else:
		frame.add_child(_Silhouette.new())
	return frame

func _describe(def: Dictionary, extra_key: String) -> void:
	if def.is_empty():
		_desc.text = tr("party_hint")
		return
	var t: String = tr(str(def.get("name_key", ""))) + ": " + tr(str(def.get("desc_key", "")))
	var m: String = mods_text(def)
	if m != "": t += " (" + m + ")"
	if extra_key != "": t += " " + tr(extra_key)
	_desc.text = t

func _describe_ability(ad: Dictionary) -> void:
	if ad.is_empty(): return
	var src: String = str(ad.get("source", "steel"))
	var cost: String = fmt("party_ability_cost", [int(ad.get("ap", 0)), int(ad.get("cost", 0)), tr("source_" + src)])
	_desc.text = "%s: %s %s" % [tr(str(ad.get("name_key", ""))), tr(str(ad.get("desc_key", ""))), cost]

static func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c

## Hooded bust drawn in code, for members whose portrait art does not exist yet.
class _Silhouette extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(40, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Color("4d4e58")
		var cx: float = size.x / 2.0
		draw_rect(Rect2(cx - 15, size.y - 18, 30, 18), c)
		draw_rect(Rect2(cx - 12, size.y - 22, 24, 6), c)
		draw_rect(Rect2(cx - 8, size.y - 40, 16, 18), c)
		draw_rect(Rect2(cx - 6, size.y - 44, 12, 4), c)
		draw_rect(Rect2(cx - 4, size.y - 34, 2, 2), Color("a8957a"))
		draw_rect(Rect2(cx + 2, size.y - 34, 2, 2), Color("a8957a"))
