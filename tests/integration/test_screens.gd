## WP-24 screens on fixture data: shop, party, scroll (pages and save slots).
extends TestCase

const SAVE_DIR: String = "user://test_screens_saves"
var _old_state: GameState
var _old_rng: Rng
var _toasts: Array[String] = []
var _nodes: Array[Node] = []

var _strings: Translation

func before_all() -> void:
	Content.reload("res://tests/fixtures/data")
	_strings = ContentLoader.load_strings("res://data/strings/view_screens.csv")
	TranslationServer.add_translation(_strings)

func after_all() -> void:
	TranslationServer.remove_translation(_strings)
	Content.reload("res://data")

func before_each() -> void:
	_old_state = Game.state
	_old_rng = Game.rng
	Game.rng = Rng.new(7)
	Game.state = _fresh_state()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_clear_dir()
	Game.save_dir_override = SAVE_DIR
	Router.switch_scenes = false
	Router.autosave_enabled = false
	Router.args = {}
	_toasts.clear()
	Bus.toast.connect(_on_toast)

func after_each() -> void:
	Bus.toast.disconnect(_on_toast)
	for n in _nodes:
		if is_instance_valid(n): n.free()
	_nodes.clear()
	_clear_dir()
	Game.save_dir_override = ""
	Game.state = _old_state
	Game.rng = _old_rng
	Router.switch_scenes = true
	Router.autosave_enabled = true
	Router.args = {}
	Hud.caption.clear()

func _on_toast(key: String) -> void:
	_toasts.append(key)

func _clear_dir() -> void:
	for f in DirAccess.get_files_at(SAVE_DIR): DirAccess.remove_absolute(SAVE_DIR.path_join(f))

func _fresh_state() -> GameState:
	var s := GameState.new()
	s.party.append(Character.create(&"hero", Content.get_def(&"class", &"fx_knight"), "hero_name"))
	s.gold = 100
	s.food = 1
	s.day = 3
	s.mode = &"location"
	s.location_id = &"fx_town"
	s.location_cell = Vector2i(2, 3)
	return s

func _host() -> Node:
	var n := Node.new()
	add_child(n)
	_nodes.append(n)
	return n

func _shop() -> ShopScreen:
	var s: ShopScreen = ShopScreen.show_over(_host(), &"fx_shop")
	await wait_frames(1)
	return s

func _party() -> PartyScreen:
	var s: PartyScreen = PartyScreen.show_over(_host())
	await wait_frames(1)
	return s

func _scroll(args: Dictionary = {}) -> Control:
	Router.args = args
	var sc: Control = load("res://src/modes/scroll/scroll.tscn").instantiate()
	_host().add_child(sc)
	await wait_frames(1)
	return sc

# ---- shop ----------------------------------------------------------------------------------

func test_buying_with_too_little_gold_is_refused_and_nothing_changes() -> void:
	Game.state.gold = 5
	var s: ShopScreen = await _shop()
	assert_false(s.buy(&"fx_bread"))
	assert_eq(Game.state.gold, 5)
	assert_false(Game.state.inventory.has(&"fx_bread"))
	assert_false(Game.state.flags.has(ShopScreen.sold_flag(&"fx_shop", &"fx_bread")))
	assert_eq(s.remaining(&"fx_bread"), 5)
	assert_eq(_toasts, ["not_enough_gold"])

func test_buy_then_sell_round_trip_costs_half_the_price() -> void:
	var s: ShopScreen = await _shop()
	var price: int = 24
	assert_true(s.buy(&"fx_sword"))
	assert_eq(Game.state.gold, 100 - price)
	assert_eq(Game.state.inventory.get(&"fx_sword", 0), 1)
	assert_eq(s.remaining(&"fx_sword"), 0)
	assert_eq(Game.state.flags.get("shop_fx_shop_fx_sword"), 1)
	assert_true(s.sell(&"fx_sword"))
	assert_eq(Game.state.gold, 100 - (price - int(floor(price / 2.0))))
	assert_false(Game.state.inventory.has(&"fx_sword"))
	assert_eq(s.remaining(&"fx_sword"), 0, "selling back does not restock")
	assert_true(_toasts.is_empty())

func test_sold_out_is_refused() -> void:
	var s: ShopScreen = await _shop()
	assert_true(s.buy(&"fx_sword"))
	assert_false(s.buy(&"fx_sword"))
	assert_eq(Game.state.gold, 76)
	assert_eq(_toasts, ["shop_sold_out"])

func test_shop_events_are_broadcast() -> void:
	var seen: Array = []
	var cb := func(evs: Array[Dictionary]) -> void: seen.append_array(evs)
	Bus.events_emitted.connect(cb)
	var s: ShopScreen = await _shop()
	s.buy(&"fx_bread")
	Bus.events_emitted.disconnect(cb)
	var types: Array = seen.map(func(e: Dictionary) -> String: return str(e.type))
	assert_has(types, "gold_changed")
	assert_has(types, "item_changed")

func test_shop_closes_on_close() -> void:
	var s: ShopScreen = await _shop()
	var layer: Node = s.get_parent()
	s.close()
	await wait_frames(1)
	assert_false(is_instance_valid(layer))

# ---- party ---------------------------------------------------------------------------------

func test_equipping_a_fifth_ability_is_refused() -> void:
	var c: Character = Game.state.party[0]
	c.known = [&"a1", &"a2", &"a3", &"a4", &"a5"]
	c.equipped = [&"a1", &"a2", &"a3", &"a4"]
	var p: PartyScreen = await _party()
	assert_false(p.toggle_ability(&"a5"))
	assert_eq(c.equipped.size(), Character.MAX_EQUIPPED)
	assert_not_has(c.equipped, &"a5")
	assert_eq(_toasts, ["party_abilities_full"])
	assert_true(p.toggle_ability(&"a1"))
	assert_true(p.toggle_ability(&"a5"))
	assert_eq(c.equipped, [&"a2", &"a3", &"a4", &"a5"])

func test_using_bread_restores_food_via_its_use_effects() -> void:
	Game.state.inventory[&"fx_bread"] = 2
	var p: PartyScreen = await _party()
	var events: Array[Dictionary] = p.use_item(&"fx_bread")
	assert_eq(Game.state.food, 4)
	assert_eq(Game.state.inventory.get(&"fx_bread", 0), 1)
	assert_not_null(find_event(events, "food_changed"))
	assert_not_null(find_event(events, "item_changed"))

func test_items_without_use_effects_do_nothing() -> void:
	Game.state.inventory[&"fx_cell"] = 1
	var p: PartyScreen = await _party()
	assert_true(p.use_item(&"fx_cell").is_empty())
	assert_eq(Game.state.inventory.get(&"fx_cell", 0), 1)

func test_equip_and_unequip_move_gear_through_the_pack() -> void:
	Game.state.inventory[&"fx_sword"] = 1
	var p: PartyScreen = await _party()
	assert_true(p.equip(&"fx_sword"))
	assert_eq(Game.state.party[0].gear.weapon, &"fx_sword")
	assert_false(Game.state.inventory.has(&"fx_sword"))
	assert_true(p.unequip("weapon"))
	assert_eq(Game.state.party[0].gear.weapon, &"")
	assert_eq(Game.state.inventory.get(&"fx_sword", 0), 1)
	assert_false(p.equip(&"fx_bread"), "bread is not gear")

func test_party_screen_shows_every_member() -> void:
	var c2: Character = Character.create(&"fx_priest", Content.get_def(&"class", &"fx_necro"), "fx_priest_name")
	Game.state.party.append(c2)
	var p: PartyScreen = await _party()
	assert_eq(p._tabs.get_child_count(), 2)
	p.select_member(1)
	assert_eq(p.current(), c2)
	assert_eq(p.ability_boxes.size(), c2.known.size())

# ---- scroll --------------------------------------------------------------------------------

func test_scroll_lists_12_slots_and_a_found_page_opens() -> void:
	Game.state.pages = [&"fx_page_2"]
	var sc: Control = await _scroll()
	assert_eq(sc.slots.size(), 12)
	assert_false(sc.slots[0].found)
	assert_true(sc.slots[1].found, "slots follow page order")
	assert_false(sc.slots[5].found)
	assert_false(sc.open_page(&"fx_page_1"), "missing pages do not open")
	assert_true(sc.open_page(&"fx_page_2"))
	assert_eq(sc.reading, &"fx_page_2")
	assert_eq(sc.reader_body.text, tr("fx_page_2_body"))
	assert_ne(sc.reader_note.text, "")

func test_corrupt_save_slot_renders_as_damaged() -> void:
	var f := FileAccess.open(Game.save_path(2), FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"party\": oops")
	f.close()
	assert_eq(ScrollMode.slot_info(2).state, "damaged")
	var sc: Control = await _scroll({"tab": "saves"})
	assert_eq(sc.tab, &"saves")
	assert_eq(sc.save_cards[2].status.text, tr("scroll_slot_damaged"))
	assert_true(sc.save_cards[2].load.disabled)
	assert_eq(sc.save_cards[1].status.text, tr("scroll_slot_empty"))

func test_save_then_load_a_manual_slot() -> void:
	var sc: Control = await _scroll({"tab": "saves"})
	Game.state.mode = &"scroll"
	assert_eq(sc.save_to(1), OK)
	var info: Dictionary = ScrollMode.slot_info(1)
	assert_eq(info.state, "ok")
	assert_eq(info.day, 3)
	assert_eq(info.level, 1)
	assert_eq(Game.state.mode, &"scroll", "the live mode is left alone")
	assert_eq(sc.save_to(1), ERR_BUSY, "overwriting asks first")
	assert_eq(sc.save_to(1), OK)
	Game.state.day = 40
	assert_eq(sc.load_from(1), OK)
	assert_eq(Game.state.day, 3)
	assert_eq(Router.current, &"location", "the slot resumes where the scroll returns to")
	assert_eq(Router.args.get("location_id"), &"fx_town")

func test_back_returns_to_the_location() -> void:
	var sc: Control = await _scroll()
	sc.go_back()
	assert_eq(Router.current, &"location")
	assert_eq(Router.args.location_id, &"fx_town")
	assert_eq(Router.args.cell, Vector2i(2, 3))

func test_back_from_the_world_map() -> void:
	Game.state.mode = &"worldmap"
	var sc: Control = await _scroll()
	assert_eq(sc.return_target()[0], &"worldmap")

func test_quest_log_lists_started_quests() -> void:
	Game.state.quests[&"fx_quest"] = 10
	var sc: Control = await _scroll({"tab": "quests"})
	assert_eq(sc.tab, &"quests")
