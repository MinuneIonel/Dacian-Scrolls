## Location mode on fixture data: walking, containers, triggers, exits and talking.
## Router never switches scenes here; autosaves are recorded, not written.
extends TestCase

var loc: Node2D
var saves: Array[int] = []
var _old_state: GameState
var _old_save_fn: Callable

func before_all() -> void:
	Content.reload("res://tests/fixtures/data")
	var town: Dictionary = Content.get_def(&"map", &"fx_town").duplicate(true)
	town["id"] = "fxl_trig"
	town["entities"].append({"id": "fxl_ambush", "kind": "trigger", "cell": [3, 2], "once": true,
		"if": [], "effects": [["battle", "fx_wolves"]]})
	Content.defs.add(&"map", town)

func after_all() -> void:
	Audio.stop_music(0.0)
	Content.reload("res://data")

func before_each() -> void:
	_old_state = Game.state
	_old_save_fn = Router.save_fn
	Router.switch_scenes = false
	saves.clear()
	Router.save_fn = func(slot: int) -> Error:
		saves.append(slot)
		return OK
	Game.new_game(7, &"fx_knight")
	Router.current = &"location"

func after_each() -> void:
	if loc != null and is_instance_valid(loc): loc.free()
	loc = null
	Game.state = _old_state
	Router.save_fn = _old_save_fn
	Router.switch_scenes = true
	Router.args = {}
	Router.current = &""

func _open(args: Dictionary) -> void:
	Router.args = args
	loc = load("res://src/modes/location/location.tscn").instantiate()
	add_child(loc)
	await wait_frames(2)

func test_spawns_at_world_entry_cell() -> void:
	await _open({"location_id": "fx_town"})
	assert_eq(loc.map_id, &"fx_town")
	assert_eq(loc.leader_cell(), Vector2i(3, 3))
	assert_eq(Game.state.location_id, &"fx_town")
	assert_eq(Game.state.location_cell, Vector2i(3, 3))

func test_map_id_and_explicit_cell() -> void:
	await _open({"location_id": "fxl_trig", "cell": [4, 1]})
	assert_eq(loc.map_id, &"fxl_trig")
	assert_eq(loc.leader_cell(), Vector2i(4, 1))

func test_walking_follows_a_path_and_updates_state() -> void:
	await _open({"location_id": "fx_town"})
	assert_true(loc.walk_to(Vector2i(4, 2)))
	assert_eq(loc._path.size(), 2, "two 4-way steps")
	loc.finish_walk()
	assert_eq(loc.leader_cell(), Vector2i(4, 2))
	assert_eq(Game.state.location_cell, Vector2i(4, 2))
	assert_false(loc.walk_to(Vector2i(0, 0)), "walls are not walkable")

func test_walking_in_real_time() -> void:
	await _open({"location_id": "fx_town"})
	loc.step_time = 0.01
	loc.walk_to(Vector2i(2, 1))
	for i in 60:
		if not loc.is_walking(): break
		await wait_frames(1)
	assert_false(loc.is_walking())
	assert_eq(Game.state.location_cell, Vector2i(2, 1))

func test_container_runs_once() -> void:
	await _open({"location_id": "fx_town"})
	loc.walk_to(Vector2i(5, 1))
	loc.finish_walk()
	assert_eq(Game.state.inventory.get(&"fx_bread", 0), 1)
	assert_has(Game.state.pages, &"fx_page_1")
	assert_true(Game.state.flags.get("opened_fx_town_fx_chest", false))
	loc.open_container("fx_chest")
	assert_eq(Game.state.inventory.get(&"fx_bread", 0), 1, "second search gives nothing")

func test_trigger_requests_combat_with_return_args() -> void:
	await _open({"location_id": "fxl_trig"})
	loc.walk_to(Vector2i(3, 1))
	loc.finish_walk()
	assert_eq(Router.current, &"combat")
	assert_eq(Router.args.get("encounter_id"), &"fx_wolves")
	assert_eq(Router.args.get("return_mode"), &"location")
	assert_eq(Router.args.return_args.location_id, &"fxl_trig")
	assert_eq(Router.args.return_args.cell, Vector2i(3, 2))
	assert_eq(loc.leader_cell(), Vector2i(3, 2), "the walk stops on the trigger")
	assert_true(Game.state.flags.get("triggered_fxl_trig_fxl_ambush", false))
	assert_eq(saves, [], "no autosave into combat")

func test_once_trigger_does_not_fire_again() -> void:
	Game.state.flags["triggered_fxl_trig_fxl_ambush"] = true
	await _open({"location_id": "fxl_trig"})
	loc.walk_to(Vector2i(3, 1))
	loc.finish_walk()
	assert_eq(Router.current, &"location")
	assert_eq(loc.leader_cell(), Vector2i(3, 1))

func test_exit_goes_to_world_map() -> void:
	await _open({"location_id": "fx_town"})
	loc.walk_to(Vector2i(3, 4))
	loc.finish_walk()
	assert_eq(Router.current, &"worldmap")
	assert_eq(saves, [0])

func test_talking_opens_the_box_and_choices_apply() -> void:
	await _open({"location_id": "fx_town"})
	loc.walk_to(Vector2i(1, 1))
	loc.finish_walk()
	assert_not_null(loc.dialogue, "walking up to the priest talks to him")
	assert_true(Game.state.flags.get("fx_met", false), "the start node's effects ran")
	var box: DialogueBox = loc.dialogue
	assert_eq(box.speaker_label.text, tr("fx_npc_priest"))
	assert_eq(box.shown.size(), 3)
	box.reveal_all()
	box.choose_number(3)   # join
	assert_true(Rules.check([["in_party", "fx_priest"]], Game.state, Content.defs))
	assert_true(box.is_closed())
	await wait_frames(1)
	assert_null(loc.dialogue)
	assert_false(loc.is_busy())

func test_e_talks_to_an_adjacent_npc() -> void:
	await _open({"location_id": "fx_town", "cell": [2, 1]})
	assert_true(loc.interact_adjacent())
	assert_not_null(loc.dialogue)

func test_battle_from_dialogue_waits_for_close() -> void:
	var dlg: Dictionary = {"id": "fxl_duel", "start": "a", "nodes": {"a": {"speaker": "fx_npc_priest",
		"text_key": "fx_dlg_hello", "choices": [{"text_key": "fx_dlg_bye", "if": [],
		"do": [["battle", "fx_wolves"]], "goto": "end"}]}}}
	Content.defs.add(&"dialogue", dlg)
	var town: Dictionary = Content.get_def(&"map", &"fx_town").duplicate(true)
	town["id"] = "fxl_duel_town"
	town["entities"][0]["dialogue"] = "fxl_duel"
	Content.defs.add(&"map", town)
	await _open({"location_id": "fxl_duel_town", "cell": [2, 1]})
	loc.talk("fx_priest")
	loc.dialogue.choose_number(1)
	loc.dialogue.reveal_all()
	loc.dialogue.choose_number(1)
	assert_eq(Router.current, &"combat")
	assert_eq(Router.args.return_args.cell, Vector2i(2, 1))
