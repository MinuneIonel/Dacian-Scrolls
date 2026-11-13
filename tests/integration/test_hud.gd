## WP-24 Hud: Fanfi's caption queue, narrator wiring, empty-party safety, the ending card.
extends TestCase

var _old_state: GameState
var _old_rng: Rng
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
	Game.rng = Rng.new(3)
	Game.state = GameState.new()
	Hud.caption.clear()

func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n): n.free()
	_nodes.clear()
	Game.state = _old_state
	Game.rng = _old_rng
	Hud.caption.clear()
	if Hud.ending != null and is_instance_valid(Hud.ending): Hud.ending.close()

func _keep(n: Node) -> Node:
	add_child(n)
	_nodes.append(n)
	return n

func _party_state() -> void:
	Game.state.party.append(Character.create(&"hero", Content.get_def(&"class", &"fx_knight"), "hero_name"))

func test_caption_queues_two_lines_and_shows_them_one_after_another() -> void:
	var c: NarratorCaption = _keep(NarratorCaption.new())
	c.queue_line("fx_line")
	c.queue_line("fanfi_caption_name")
	assert_true(c.is_showing())
	assert_eq(c.current_key, "fx_line")
	assert_eq(c.queue.size(), 1, "the second line waits")
	assert_eq(c.shown_text(), tr("fx_line"))
	c.time_left = 0.01
	await wait_frames(3)
	assert_eq(c.current_key, "fanfi_caption_name", "next line after the first times out")
	assert_eq(c.queue.size(), 0)
	c.skip()
	assert_false(c.is_showing())
	assert_false(c.visible)

func test_caption_click_skips() -> void:
	var c: NarratorCaption = _keep(NarratorCaption.new())
	c.queue_line("fx_line")
	c.queue_line("fanfi_caption_name")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	c._gui_input(click)
	assert_eq(c.current_key, "fanfi_caption_name")

func test_caption_shows_longer_lines_for_longer() -> void:
	var c: NarratorCaption = _keep(NarratorCaption.new())
	c.queue_line("fx_line")
	assert_true(c.time_left >= NarratorCaption.SHOW_S)

func test_hud_builds_with_an_empty_party() -> void:
	var h: CanvasLayer = _keep(load("res://src/ui/hud_overlay.gd").new())
	await wait_frames(2)
	assert_eq(h.layer, 90)
	assert_not_null(h.caption)
	assert_not_null(h.toasts)
	var evs: Array[Dictionary] = [{"type": "new_game"}, {"type": "page_found", "page": &"fx_page_1"}]
	Bus.emit_events(evs)
	await wait_frames(1)
	assert_false(h.caption.is_showing(), "no party, no narration")
	assert_null(h.ending)

func test_hud_asks_the_narrator_for_fanfis_line() -> void:
	_party_state()
	var evs: Array[Dictionary] = [{"type": "new_game"}]
	Bus.emit_events(evs)
	assert_eq(Hud.caption.current_key, "fx_line")

func test_narrator_events_speak_without_a_party() -> void:
	var evs: Array[Dictionary] = [{"type": "narrator", "line_key": "fx_line"}]
	Bus.emit_events(evs)
	assert_eq(Hud.caption.current_key, "fx_line")

func test_twelfth_page_opens_the_ending_card() -> void:
	_party_state()
	Game.state.day = 14
	for i in 11: Game.state.pages.append(StringName("p%d" % i))
	var evs: Array[Dictionary] = [{"type": "page_found", "page": &"p10"}]
	Bus.emit_events(evs)
	assert_null(Hud.ending, "11 pages is not the end")
	Game.state.pages.append(&"p11")
	evs = [{"type": "page_found", "page": &"p11"}]
	Bus.emit_events(evs)
	assert_not_null(Hud.ending)
	await wait_frames(1)
	assert_has(Hud.ending.lines, tr("ending_days") % 14)
	assert_has(Hud.ending.lines, tr("ending_alone"))

func test_recap_counts_abductions_and_companions() -> void:
	_party_state()
	Game.state.party.append(Character.create(&"fx_priest", Content.get_def(&"class", &"fx_necro"), "fx_npc_priest"))
	Game.state.flags["times_abducted"] = 2
	Game.state.flags["ozo_freed"] = true
	Game.state.quests[&"fx_quest"] = 100
	var lines: Array[String] = EndingCard.recap_lines(Game.state, Content.defs)
	assert_has(lines, tr("ending_abducted_many") % 2)
	assert_has(lines, tr("ending_companions") % tr("fx_npc_priest"))
	assert_has(lines, tr("ending_ozo_freed"))
	assert_has(lines, tr("ending_quest_done") % tr("fx_quest_name"))
