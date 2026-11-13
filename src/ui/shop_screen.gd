## Shop overlay for data/shops/<shop_id>. Implemented by WP-24.
## Buys from the shop's stock (sold counts in Game.state.flags "shop_<id>_<item>") and sells
## from the pack at half price, floored. Every change goes through Rules.run, broadcast on Bus.
class_name ShopScreen
extends Control

signal closed

const PANEL_RECT: Rect2 = Rect2(40, 14, 560, 332)
const COL_W: int = 262

var shop_id: StringName
var buy_rows: Dictionary = {}      # item id -> HBoxContainer
var sell_rows: Dictionary = {}     # item id -> HBoxContainer
var btn_close: Button
var _gold: Label
var _desc: Label
var _buy_list: VBoxContainer
var _sell_list: VBoxContainer

static func show_over(parent: Node, id: StringName) -> ShopScreen:
	var s := ShopScreen.new()
	s.shop_id = id
	var layer := CanvasLayer.new()
	layer.layer = 50
	parent.add_child(layer)
	layer.add_child(s)
	s.closed.connect(layer.queue_free)
	return s

static func sold_flag(shop: StringName, item: StringName) -> String:
	return "shop_%s_%s" % [shop, item]

static func sell_price(price: int) -> int:
	return int(floor(price / 2.0))

func shop_def() -> Dictionary:
	return Content.get_def(&"shop", shop_id) if Content.has(&"shop", shop_id) else {}

## How many of `item` the shop still has.
func remaining(item: StringName) -> int:
	for s in shop_def().get("stock", []):
		if StringName(str(s.get("item", ""))) == item:
			return maxi(0, int(s.get("count", 0)) - int(Game.state.flags.get(sold_flag(shop_id, item), 0)))
	return 0

func price_of(item: StringName) -> int:
	return int(Content.get_def(&"item", item).get("price", 0)) if Content.has(&"item", item) else 0

## Buys one. Too little gold or sold out: a toast and nothing changes.
func buy(item: StringName) -> bool:
	var price: int = price_of(item)
	if remaining(item) <= 0:
		Bus.toast.emit("shop_sold_out")
		return false
	if Game.state.gold < price:
		Bus.toast.emit("not_enough_gold")
		return false
	var flag: String = sold_flag(shop_id, item)
	var events: Array[Dictionary] = Rules.run([["gold", -price], ["give_item", str(item), 1],
		["set_flag", flag, int(Game.state.flags.get(flag, 0)) + 1]], Game.state, Game.rng, Content.defs)
	Bus.emit_events(events)
	refresh()
	return true

## Sells one from the pack for half its price. Items worth nothing (quest items) are refused.
func sell(item: StringName) -> bool:
	if int(Game.state.inventory.get(item, 0)) <= 0: return false
	var def: Dictionary = Content.get_def(&"item", item) if Content.has(&"item", item) else {}
	if def.is_empty() or str(def.get("kind", "")) == "quest" or price_of(item) <= 0:
		Bus.toast.emit("shop_wont_buy")
		return false
	var events: Array[Dictionary] = Rules.run([["take_item", str(item), 1], ["gold", sell_price(price_of(item))]],
		Game.state, Game.rng, Content.defs)
	Bus.emit_events(events)
	refresh()
	return true

func close() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

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
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 4)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title: Label = PartyScreen.ink_label(str(shop_def().get("name_key", "shop_title")))
	title.theme_type_variation = &"TitleLabel"
	head.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_gold = PartyScreen.ink_label("")
	_gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gold.add_theme_color_override(&"font_color", PartyScreen.INK_RED)
	head.add_child(_gold)
	var pitch: Label = PartyScreen.ink_label("shop_pitch")
	pitch.theme_type_variation = &"DimLabel"
	v.add_child(pitch)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override(&"separation", 12)
	v.add_child(cols)
	_buy_list = _list_column(cols, "shop_for_sale")
	_sell_list = _list_column(cols, "shop_your_pack")

	var foot := HBoxContainer.new()
	v.add_child(foot)
	_desc = PartyScreen.ink_label("shop_hint")
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

func _list_column(parent: Control, key: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = COL_W
	parent.add_child(col)
	var h: Label = PartyScreen.ink_label(key)
	h.add_theme_color_override(&"font_color", PartyScreen.INK_RED)
	col.add_child(h)
	var line := ColorRect.new()
	line.color = PartyScreen.INK_FADED
	line.custom_minimum_size = Vector2(COL_W, 1)
	col.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 1)
	scroll.add_child(list)
	return list

func refresh() -> void:
	if _buy_list == null: return
	_gold.text = PartyScreen.fmt("shop_gold", [Game.state.gold])
	for list in [_buy_list, _sell_list]:
		for n in list.get_children():
			list.remove_child(n)
			n.queue_free()
	buy_rows.clear(); sell_rows.clear()
	for s in shop_def().get("stock", []):
		var item := StringName(str(s.get("item", "")))
		var left: int = remaining(item)
		var row := _row(item, "shop_left" if left > 0 else "shop_sold_out_short", left, price_of(item), "shop_buy")
		var b: Button = row.get_child(row.get_child_count() - 1)
		b.disabled = left <= 0
		b.pressed.connect(func() -> void: buy(item))
		_buy_list.add_child(row)
		buy_rows[item] = row
	var ids: Array = Game.state.inventory.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for id in ids:
		var item := StringName(str(id))
		var def: Dictionary = Content.get_def(&"item", item) if Content.has(&"item", item) else {}
		var sellable: bool = not def.is_empty() and str(def.get("kind", "")) != "quest" and price_of(item) > 0
		var row := _row(item, "shop_have", int(Game.state.inventory[id]), sell_price(price_of(item)), "shop_sell")
		var b: Button = row.get_child(row.get_child_count() - 1)
		b.disabled = not sellable
		b.pressed.connect(func() -> void: sell(item))
		_sell_list.add_child(row)
		sell_rows[item] = row
	if ids.is_empty():
		var e: Label = PartyScreen.ink_label("party_pack_empty")
		e.theme_type_variation = &"DimLabel"
		_sell_list.add_child(e)

func _row(item: StringName, count_key: String, count: int, price: int, action_key: String) -> HBoxContainer:
	var def: Dictionary = Content.get_def(&"item", item) if Content.has(&"item", item) else {}
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(PartyScreen.kind_swatch(str(def.get("kind", ""))))
	var nl: Label = PartyScreen.ink_label(str(def.get("name_key", item)))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	nl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(nl)
	var cl: Label = PartyScreen.ink_label("")
	cl.text = PartyScreen.fmt(count_key, [count]) if count_key != "shop_sold_out_short" else tr(count_key)
	cl.theme_type_variation = &"DimLabel"
	cl.custom_minimum_size.x = 50
	row.add_child(cl)
	var pl: Label = PartyScreen.ink_label("")
	pl.text = PartyScreen.fmt("shop_price", [price])
	pl.add_theme_color_override(&"font_color", PartyScreen.INK_RED)
	pl.custom_minimum_size.x = 40
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pl)
	var b: Button = UiKit.button(action_key)
	b.custom_minimum_size.x = 34
	b.mouse_entered.connect(_describe.bind(def))
	b.focus_entered.connect(_describe.bind(def))
	nl.mouse_entered.connect(_describe.bind(def))
	row.add_child(b)
	return row

func _describe(def: Dictionary) -> void:
	if def.is_empty(): return
	var t: String = tr(str(def.get("name_key", ""))) + ": " + tr(str(def.get("desc_key", "")))
	var m: String = PartyScreen.mods_text(def)
	if m != "": t += " (" + m + ")"
	_desc.text = t
