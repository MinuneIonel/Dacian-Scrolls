## WP-11: Narrator (Fanfi) line picking.
extends TestCase

const FIXTURES: String = "res://tests/fixtures/data"

var s: GameState
var rng: Rng

func before_each() -> void:
	s = GameState.new()
	rng = Rng.new(5)

func _defs(fanfi: Dictionary) -> Defs:
	var d := Defs.new()
	d.set_json("fanfi", fanfi)
	return d

func _lines(events: Array[Dictionary], defs: Defs) -> Array[String]:
	return Narrator.lines_for(events, s, rng, defs)

func test_fixture_once_line_only_once() -> void:
	var defs: Defs = ContentLoader.load_root(FIXTURES)
	var ev: Array[Dictionary] = [{"type": "page_found", "page": "fx_page_1"}]
	assert_eq(_lines(ev, defs), ["fx_line"])
	assert_eq(s.flags["fanfi_once:fx_line"], true)
	assert_eq(_lines(ev, defs), [])

func test_fixture_repeatable_line() -> void:
	var defs: Defs = ContentLoader.load_root(FIXTURES)
	var ev: Array[Dictionary] = [{"type": "new_game"}]
	for i in 3: assert_eq(_lines(ev, defs), ["fx_line"])

func test_once_survives_save() -> void:
	var defs: Defs = ContentLoader.load_root(FIXTURES)
	var ev: Array[Dictionary] = [{"type": "page_found", "page": "fx_page_1"}]
	_lines(ev, defs)
	s.party.append(Character.create(&"hero", defs.get_def(&"class", &"fx_knight"), "hero_name"))
	s = SaveCodec.decode(SaveCodec.encode(s)).state
	assert_eq(_lines(ev, defs), [])

func test_no_events_no_lines() -> void:
	assert_eq(_lines([], _defs({"x": [{"if": [], "lines": ["fxs_line_a"], "once": false}]})), [])

func test_unknown_event_type_no_lines() -> void:
	assert_eq(_lines([{"type": "moved"}], _defs({"x": [{"if": [], "lines": ["fxs_line_a"]}]})), [])

func test_missing_fanfi_is_quiet() -> void:
	assert_eq(_lines([{"type": "x"}], Defs.new()), [])

func test_at_most_one_line_first_matching_event() -> void:
	var defs := _defs({
		"a": [{"if": [["gold", ">", 100]], "lines": ["fxs_line_a"], "once": false}],
		"b": [{"if": [], "lines": ["fxs_line_b"], "once": false}],
		"c": [{"if": [], "lines": ["fxs_line_c"], "once": false}],
	})
	var ev: Array[Dictionary] = [{"type": "a"}, {"type": "c"}, {"type": "b"}]
	assert_eq(_lines(ev, defs), ["fxs_line_c"])

func test_conditions_gate_entries_in_order() -> void:
	var defs := _defs({"x": [
		{"if": [["flag", "drunk", "==", true]], "lines": ["fxs_line_a"], "once": false},
		{"if": [], "lines": ["fxs_line_b"], "once": false}]})
	assert_eq(_lines([{"type": "x"}], defs), ["fxs_line_b"])
	s.flags["drunk"] = true
	assert_eq(_lines([{"type": "x"}], defs), ["fxs_line_a"])

func test_random_among_lines_deterministic() -> void:
	var defs := _defs({"x": [{"if": [], "lines": ["fxs_line_a", "fxs_line_b", "fxs_line_c"], "once": false}]})
	var seen: Dictionary = {}
	var first: Array = []
	for i in 60:
		var l: Array[String] = _lines([{"type": "x"}], defs)
		seen[l[0]] = true
		first.append(l[0])
	assert_eq(seen.size(), 3, "every line shows up")
	rng = Rng.new(5)
	var again: Array = []
	for i in 60: again.append(_lines([{"type": "x"}], defs)[0])
	assert_eq(again, first, "same seed, same lines")

func test_once_entry_uses_each_line_then_falls_through() -> void:
	var defs := _defs({"x": [
		{"if": [], "lines": ["fxs_line_a", "fxs_line_b"], "once": true},
		{"if": [], "lines": ["fxs_line_c"], "once": false}]})
	var got: Array = []
	for i in 4: got.append_array(_lines([{"type": "x"}], defs))
	got.sort()
	assert_eq(got, ["fxs_line_a", "fxs_line_b", "fxs_line_c", "fxs_line_c"])

func test_exhausted_once_lets_next_event_speak() -> void:
	var defs := _defs({
		"a": [{"if": [], "lines": ["fxs_line_a"], "once": true}],
		"b": [{"if": [], "lines": ["fxs_line_b"], "once": false}]})
	var ev: Array[Dictionary] = [{"type": "a"}, {"type": "b"}]
	assert_eq(_lines(ev, defs), ["fxs_line_a"])
	assert_eq(_lines(ev, defs), ["fxs_line_b"])

func test_narrator_event_speaks_its_own_line() -> void:
	var defs := _defs({"b": [{"if": [], "lines": ["fxs_line_b"], "once": false}]})
	var ev: Array[Dictionary] = [{"type": "narrator", "line_key": "fxs_line_a"}, {"type": "b"}]
	assert_eq(_lines(ev, defs), ["fxs_line_a"])

func test_bad_entries_are_skipped() -> void:
	var defs := _defs({"x": [42, {"if": [], "lines": []}, {"lines": ["fxs_line_a"]}]})
	assert_eq(_lines([{"type": "x"}], defs), ["fxs_line_a"])
