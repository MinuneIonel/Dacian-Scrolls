## DialogueBox on fixture data: speaker, typewriter, numbered choices, events and closing.
extends TestCase

var box: DialogueBox
var got: Array[Dictionary] = []
var _old_state: GameState

func before_all() -> void:
	Content.reload("res://tests/fixtures/data")

func after_all() -> void:
	Content.reload("res://data")

func before_each() -> void:
	_old_state = Game.state
	Game.new_game(3, &"fx_knight")
	got.clear()
	box = DialogueBox.new()
	box.events.connect(func(e: Array[Dictionary]) -> void: got.append_array(e))
	add_child(box)

func after_each() -> void:
	if box != null and is_instance_valid(box): box.free()
	Game.state = _old_state

func test_shows_speaker_text_and_choices() -> void:
	box.begin(&"fx_priest", Game.state, Game.rng, Content.defs)
	assert_eq(box.speaker_label.text, tr("fx_npc_priest"))
	assert_eq(box.text_label.text, tr("fx_dlg_hello"))
	assert_eq(box.choices.buttons.size(), 3)
	assert_eq(box.choices.buttons[0].text, "1. " + tr("fx_dlg_heal"))
	assert_eq(count_events(got, "flag_set"), 1, "start events reach the signal")

func test_typewriter_reveals_then_shows_choices() -> void:
	box.begin(&"fx_priest", Game.state, Game.rng, Content.defs)
	assert_false(box.is_revealed())
	assert_false(box.choices.visible)
	box.choose_number(1)
	assert_false(box.is_closed(), "choices wait for the text")
	box.reveal_all()
	assert_true(box.is_revealed())
	assert_true(box.choices.visible)

func test_choice_moves_to_next_node_and_closes_at_end() -> void:
	box.begin(&"fx_priest", Game.state, Game.rng, Content.defs)
	box.reveal_all()
	box.choose_number(2)   # quest
	assert_eq(Game.state.quests.get(&"fx_quest", 0), 10)
	assert_eq(box.text_label.text, tr("fx_dlg_quest_text"))
	assert_true(find_event(got, "quest_changed").size() > 0)
	var closed: Array = [false]
	box.closed.connect(func() -> void: closed[0] = true)
	box.reveal_all()
	box.choose_number(1)
	assert_true(closed[0])
	assert_true(box.is_closed())

func test_number_keys_choose() -> void:
	box.begin(&"fx_priest", Game.state, Game.rng, Content.defs)
	box.reveal_all()
	var e := InputEventKey.new()
	e.keycode = KEY_2
	e.pressed = true
	box._unhandled_key_input(e)
	assert_eq(Game.state.quests.get(&"fx_quest", 0), 10)

func test_unknown_dialogue_closes_at_once() -> void:
	expect_errors(1)
	box.begin(&"fxl_nope", Game.state, Game.rng, Content.defs)
	assert_true(box.is_closed())
