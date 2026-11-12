## WP-11: DialogueRunner and QuestLog.
extends TestCase

const FIXTURES: String = "res://tests/fixtures/data"

var defs: Defs
var s: GameState
var rng: Rng

func before_all() -> void:
	defs = ContentLoader.load_root(FIXTURES)

func before_each() -> void:
	s = GameState.new()
	s.party.append(Character.create(&"hero", defs.get_def(&"class", &"fx_knight"), "hero_name"))
	rng = Rng.new(3)

func _keys(cur: Dictionary) -> Array:
	return cur.choices.map(func(c: Dictionary) -> String: return c.text_key)

func test_start_runs_first_node_do() -> void:
	var d := DialogueRunner.new(&"fxs_gate", s, rng, defs)
	assert_false(d.is_done())
	var ev: Array[Dictionary] = d.start()
	assert_eq(ev, [{"type": "narrator", "line_key": "fx_line"}])
	var cur: Dictionary = d.current()
	assert_eq(cur.speaker, "fx_npc_priest")
	assert_eq(cur.text_key, "fxs_dlg_a")

func test_choice_hidden_until_flag_then_visible() -> void:
	var d := DialogueRunner.new(&"fxs_gate", s, rng, defs)
	d.start()
	assert_eq(_keys(d.current()), ["fxs_dlg_next", "fxs_dlg_bye"])
	var next_index: int = d.current().choices[0].index
	var ev: Array[Dictionary] = d.choose(next_index)
	assert_eq(ev[0], {"type": "flag_set", "flag": "fxs_met", "value": true})
	assert_eq(ev[1], {"type": "gold_changed", "delta": 12}, "entering b runs its do")
	assert_eq(d.current().text_key, "fxs_dlg_b")
	d.choose(d.current().choices[0].index)   # back to a
	assert_eq(d.current().text_key, "fxs_dlg_a")
	assert_eq(_keys(d.current()), ["fxs_dlg_secret", "fxs_dlg_next", "fxs_dlg_bye"])
	assert_eq(d.current().choices[0].index, 0)

func test_choose_end_finishes() -> void:
	s.flags["fxs_met"] = true
	var d := DialogueRunner.new(&"fxs_gate", s, rng, defs)
	d.start()
	d.choose(0)
	assert_eq(d.current().text_key, "fxs_dlg_c")
	var ev: Array[Dictionary] = d.choose(0)
	assert_eq(ev, [{"type": "item_changed", "item": "fx_cell", "delta": 1}])
	assert_true(d.is_done())
	assert_eq(d.current(), {})
	assert_eq(d.choose(0), [], "nothing after the end")

func test_hidden_or_bad_choice_does_nothing() -> void:
	var d := DialogueRunner.new(&"fxs_gate", s, rng, defs)
	d.start()
	assert_eq(d.choose(0), [], "hidden by its if")
	assert_eq(d.choose(9), [])
	assert_eq(d.choose(-1), [])
	assert_eq(d.current().text_key, "fxs_dlg_a")
	assert_false(s.flags.has("fxs_met"))

func test_fixture_priest_dialogue() -> void:
	var d := DialogueRunner.new(&"fx_priest", s, rng, defs)
	d.start()
	assert_eq(s.flags["fx_met"], true)
	assert_eq(d.current().choices.size(), 3)
	var ev: Array[Dictionary] = d.choose(2)
	assert_eq(ev, [{"type": "recruited", "unit": &"fx_priest"}])
	assert_true(d.is_done())

func test_goto_missing_node_ends_with_error() -> void:
	expect_errors(1)
	var hand := Defs.new()
	hand.add(&"dialogue", {"id": "broken", "start": "a", "nodes": {
		"a": {"speaker": "x", "text_key": "y", "do": [],
			"choices": [{"text_key": "z", "if": [], "do": [["gold", 1]], "goto": "nowhere"}]}}})
	var d := DialogueRunner.new(&"broken", s, rng, hand)
	d.start()
	var ev: Array[Dictionary] = d.choose(0)
	assert_eq(ev, [{"type": "gold_changed", "delta": 1}])
	assert_true(d.is_done())
	assert_eq(d.current(), {})

func test_unknown_dialogue_is_done() -> void:
	expect_errors(1)
	var d := DialogueRunner.new(&"nope", s, rng, defs)
	assert_true(d.is_done())
	assert_eq(d.start(), [])
	assert_eq(d.current(), {})

func test_start_twice_runs_once() -> void:
	var d := DialogueRunner.new(&"fxs_gate", s, rng, defs)
	assert_eq(d.start().size(), 1)
	assert_eq(d.start(), [])

# ---- QuestLog -----------------------------------------------------------------

func test_quest_log_empty() -> void:
	assert_eq(QuestLog.entries(s, defs), [])

func test_quest_log_started_and_done() -> void:
	s.quests[&"fx_quest"] = 10
	assert_eq(QuestLog.entries(s, defs), [{"quest": &"fx_quest", "stage": 10,
		"name_key": "fx_quest_name", "desc_key": "fx_quest_10", "done": false}])
	s.quests[&"fx_quest"] = 100
	var e: Dictionary = QuestLog.entries(s, defs)[0]
	assert_eq(e.desc_key, "fx_quest_done")
	assert_true(e.done)

func test_quest_log_stage_between_uses_last_reached() -> void:
	s.quests[&"fx_quest"] = 50
	assert_eq(QuestLog.entries(s, defs)[0].desc_key, "fx_quest_10")

func test_quest_log_skips_unknown_and_unstarted() -> void:
	s.quests[&"ghost_quest"] = 10
	s.quests[&"fx_quest"] = 0
	assert_eq(QuestLog.entries(s, defs), [])
