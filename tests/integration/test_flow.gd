## WP-30 glue on the real data: new game séance, abduction (beam, win, lose, timeout), the
## temple wake-up, Review Focus 5 (quit mid-abduction, reload slot 0), Continue after every
## mode transition, Hud narrator Rng, and won_<encounter> gating in content.
extends TestCase

const SAVE_DIR: String = "user://test_flow_saves"

var _old_state: GameState
var _old_rng: Rng
var _old_save_fn: Callable
var bus_events: Array[Dictionary] = []

func before_each() -> void:
	_old_state = Game.state
	_old_rng = Game.rng
	_old_save_fn = Router.save_fn
	Router.switch_scenes = false
	Router.current = &""
	Router.args = {}
	Game.save_dir_override = SAVE_DIR
	_clear_saves()
	Flow.overlays_enabled = true
	Flow.instant = false
	bus_events.clear()
	Bus.events_emitted.connect(_on_bus)

func after_each() -> void:
	Bus.events_emitted.disconnect(_on_bus)
	for n in Hud.get_children():
		if n.name in ["Seance", "Beam", "Wake"]: n.free()
	_clear_saves()
	Game.save_dir_override = ""
	Game.state = _old_state
	Game.rng = _old_rng
	Router.save_fn = _old_save_fn
	Router.switch_scenes = true
	Router.args = {}
	Router.current = &""
	Flow.overlays_enabled = true
	Flow.instant = false
	Hud.caption.clear()

func after_all() -> void:
	Audio.stop_music(0.0)
	await get_tree().create_timer(0.3).timeout

func _on_bus(events: Array[Dictionary]) -> void:
	bus_events.append_array(events)

func _clear_saves() -> void:
	for i in Game.SLOTS:
		var p: String = SAVE_DIR.path_join("save_%d.json" % i)
		if FileAccess.file_exists(p): DirAccess.remove_absolute(p)

func _defs() -> Defs:
	return Content.defs

func _slot0() -> GameState:
	var r: Dictionary = SaveCodec.decode(FileAccess.get_file_as_string(Game.save_path(0)))
	assert_true(r.ok, "slot 0 decodes")
	return r.state if r.ok else GameState.new()

func _new(seed_value: int = 5) -> void:
	Game.new_game(seed_value, &"knight")
	Rules.run([["recruit", "vezina"]], Game.state, Game.rng, _defs())

func _ufo() -> Dictionary:
	return Game.state.ufos[0]

func _result(outcome: String, reason: String = "") -> Dictionary:
	var hp: Dictionary = {}
	for m in Game.state.party: hp[m.id] = 0 if outcome != "win" else 5
	return {"outcome": outcome, "reason": reason, "loot": {}, "downed": [], "party_hp": hp,
		"party_mana": {}, "party_charge": {}, "items_used": {}}

# ---------------------------------------------------------------- new game

func test_new_game_goes_to_town_with_the_seance_on_top() -> void:
	var s: Node = Flow.start_new_game(11, &"knight")
	assert_eq(Game.state.mode, &"location")
	assert_eq(Router.current, &"location")
	assert_eq(Router.args.location_id, &"sarmizegetusa")
	assert_true(Game.has_save(0), "autosaved")
	assert_eq(_slot0().mode, &"location", "Continue resumes in the town")
	assert_eq(_slot0().location_id, &"sarmizegetusa")
	assert_not_null(s)
	assert_eq(s.lines.slice(0, 2), ["flow_seance_place", "flow_seance_medium"])
	assert_eq(s.lines.slice(2, 5), ["fanfi_new_game_1", "fanfi_new_game_2", "fanfi_new_game_3"], "Fanfi in order")
	assert_eq(s.lines[-1], "flow_seance_wake")
	assert_eq(s.current(), "flow_seance_place")
	s.advance()   # reveal the typed line
	assert_true(s.line_complete())
	s.advance()
	assert_eq(s.current(), "flow_seance_medium")
	assert_eq(count_events(bus_events, "new_game"), 0, "not before the séance ends")
	s.skip_all()
	assert_eq(count_events(bus_events, "new_game"), 1)
	assert_false(Hud.caption.is_showing(), "the caption does not repeat what the séance said")

func test_seance_runs_to_the_end_by_clicking() -> void:
	var s: Node = Flow.start_new_game(12, &"necromancer")
	var n: int = s.lines.size()
	for i in n * 2: s.advance()
	assert_true(s.done)
	await get_tree().create_timer(1.2).timeout
	assert_eq(count_events(bus_events, "new_game"), 1, "after the fade")
	assert_false(is_instance_valid(s), "freed")

# ---------------------------------------------------------------- abduction

func test_saucer_encounter_has_the_saucer_rules() -> void:
	var enc: Dictionary = _defs().get_def(&"encounter", &"saucer_surgeon")
	assert_eq(enc.map, "arena_saucer")
	assert_eq(enc.rules, {"magic_disabled": true, "gravity": "floaty", "turn_limit": 12})
	assert_true(Flow.is_abduction(&"saucer_surgeon", _defs()))
	assert_false(Flow.is_abduction(&"wolves", _defs()))

func test_play_abduction_counts_and_goes_to_combat_without_saving() -> void:
	_new()
	Router.go(&"worldmap")
	var before: String = FileAccess.get_file_as_string(Game.save_path(0))
	Flow.instant = true
	Flow.play_abduction(&"ufo_sarmizegetusa", &"saucer_surgeon", Vector2(100, 100))
	assert_eq(Router.current, &"combat")
	assert_eq(Router.args.encounter_id, &"saucer_surgeon")
	assert_eq(Router.args.return_mode, &"worldmap")
	assert_eq(Game.state.flags.get("times_abducted"), 1)
	assert_eq(find_event(bus_events, "flag_set").flag, "times_abducted")
	assert_eq(FileAccess.get_file_as_string(Game.save_path(0)), before, "no save on the way in")
	Flow.play_abduction(&"ufo_sarmizegetusa", &"saucer_surgeon", Vector2(100, 100))
	assert_eq(Game.state.flags.get("times_abducted"), 2)

func test_beam_whites_out_then_starts_the_battle() -> void:
	_new()
	Router.go(&"worldmap")
	var b: Node = Flow.play_abduction(&"ufo_sarmizegetusa", &"saucer_surgeon", Vector2(320, 200))
	assert_not_null(b)
	assert_ne(Router.current, &"combat", "the beam plays first")
	await get_tree().create_timer(1.9).timeout
	assert_eq(Router.current, &"combat", "battle starts at full white")
	assert_eq(Audio.current_track, &"saucer")
	await get_tree().create_timer(1.2).timeout
	assert_false(is_instance_valid(b), "white fades and the overlay goes")

## Party on the UFO's cell after the abduction step, the UFO chasing there.
func _abducted() -> void:
	_new()
	Game.state.world_pos = Vector2i(33, 16)
	_ufo()["pos"] = Vector2i(33, 16)
	_ufo()["state"] = "chase"
	Game.state.food = 9
	Game.state.gold = 30

func test_saucer_win_crash_site_pages_and_ufo_gone() -> void:
	_abducted()
	var res: Dictionary = _result("win", "enemies_defeated")
	res.loot = {"surgeon_logbook": 1, "oglinda_shard": 1, "lobizi_scalpel": 1}
	var ev: Array[Dictionary] = Encounters.apply_battle_result(&"saucer_surgeon", res, Game.state, Game.rng, _defs())
	var after: Dictionary = Flow.after_battle(&"saucer_surgeon", res, Game.state, Game.rng, _defs())
	ev.append_array(after.events)
	assert_eq(_ufo().state, "gone")
	assert_eq(count_events(ev, "page_found"), 2, "two pages")
	assert_has(Game.state.pages, &"page_surgeon_log")
	assert_has(Game.state.pages, &"page_oglinda")
	assert_eq(int(Game.state.inventory.get(&"lobizi_scalpel", 0)), 1, "salvage")
	var crash: Vector2i = Rules.to_cell(Rules.location(&"crash_site", _defs()).cell)
	var d: Vector2i = Game.state.world_pos - crash
	assert_true(maxi(absi(d.x), absi(d.y)) == 1, "lands next to the crash site")
	assert_true(Travel.passable(Game.state.world_pos, _defs()))
	assert_has(Game.state.discovered, &"crash_site")
	assert_eq(after.mode, &"worldmap")
	assert_eq(after.wake, "crash")
	assert_eq(after.wake_events[0].line_key, "flow_saucer_down_1")

func _check_dumped(after: Dictionary, food_before: int) -> void:
	assert_eq(_ufo().state, "patrol", "UFO resumes patrol")
	for m in Game.state.party: assert_eq(m.hp, 1, "wakes with 1 HP")
	assert_eq(Game.state.food, food_before - food_before / 2, "half the food gone")
	var c: Vector2i = Game.state.world_pos
	assert_true(Fog.is_revealed(Game.state, c), "a revealed cell")
	assert_true(Travel.hides(c, _defs()), "in the forest")
	assert_eq(after.mode, &"worldmap")
	assert_eq(after.wake, "forest")
	assert_eq(count_events(after.events, "defeat"), 0, "not a defeat, and never a game over")
	assert_true(int(Game.state.flags.get(Ufo.GRACE_FLAG, 0)) > 0, "grace period")

func test_saucer_lose_wakes_in_a_revealed_forest() -> void:
	_abducted()
	Fog.reveal(Game.state, Vector2i(24, 16), 8, Travel.world_size(_defs()))
	var res: Dictionary = _result("lose", "party_down")
	Encounters.apply_battle_result(&"saucer_surgeon", res, Game.state, Game.rng, _defs())
	_check_dumped(Flow.after_battle(&"saucer_surgeon", res, Game.state, Game.rng, _defs()), 9)

func test_saucer_timeout_is_the_same_wake_up() -> void:
	_abducted()
	Fog.reveal(Game.state, Vector2i(33, 16), 6, Travel.world_size(_defs()))
	var res: Dictionary = _result("lose", "timeout")
	Encounters.apply_battle_result(&"saucer_surgeon", res, Game.state, Game.rng, _defs())
	_check_dumped(Flow.after_battle(&"saucer_surgeon", res, Game.state, Game.rng, _defs()), 9)

func test_forest_cell_is_reproducible_and_falls_back_to_the_start() -> void:
	_abducted()
	Fog.reveal(Game.state, Vector2i(24, 16), 10, Travel.world_size(_defs()))
	var a: Vector2i = Flow.forest_cell(Game.state, Rng.new(3), _defs())
	assert_eq(Flow.forest_cell(Game.state, Rng.new(3), _defs()), a)
	Game.state.revealed = {"24,16": true}
	assert_eq(Flow.forest_cell(Game.state, Rng.new(3), _defs()), Vector2i(24, 16), "no forest seen: town")

func test_combat_view_abduction_loss_returns_to_the_world_map() -> void:
	_abducted()
	Router.save_fn = func(_slot: int) -> Error: return OK
	Router.args = {"encounter_id": "saucer_surgeon", "return_mode": "worldmap", "return_args": {}}
	var view: Node2D = load("res://src/modes/combat/combat.tscn").instantiate()
	view.audio = false
	var lose := func(b: Object, _uid: int, _r: Rng) -> Dictionary: return {"type": "end_turn"}
	view.ai_chooser = lose
	view.party_chooser = lose
	add_child(view)
	view.set_instant(true)
	for i in 3000:
		if view.returned: break
		await wait_frames(1)
	assert_true(view.returned)
	assert_eq(view.result.outcome, "lose")
	assert_eq(view.result.reason, "timeout", "the self-destruct timer")
	assert_eq(Router.current, &"worldmap")
	assert_eq(Game.state.mode, &"worldmap")
	assert_true(Travel.hides(Game.state.world_pos, _defs()))
	assert_not_null(Hud.get_node_or_null("Wake"), "wake-up card")
	view.free()

# ---------------------------------------------------------------- regular defeat

func test_regular_defeat_wakes_at_the_temple() -> void:
	_new()
	Game.state.gold = 31
	Game.state.world_pos = Vector2i(20, 20)
	var res: Dictionary = _result("lose", "party_down")
	Encounters.apply_battle_result(&"wolves", res, Game.state, Game.rng, _defs())
	var after: Dictionary = Flow.after_battle(&"wolves", res, Game.state, Game.rng, _defs())
	assert_eq(find_event(after.events, "defeat").type, "defeat")
	assert_eq(Game.state.gold, 31 - 10, "a third of the gold")
	for m in Game.state.party: assert_true(m.hp >= 1)
	assert_eq(after.mode, &"location")
	assert_eq(after.args, {"location_id": &"sarmizegetusa", "cell": Flow.TEMPLE_CELL})
	assert_eq(Game.state.world_pos, Rules.to_cell(Rules.location(&"sarmizegetusa", _defs()).cell))
	assert_eq(after.wake, "temple")
	assert_eq(after.wake_events[0].type, "narrator")
	var second: Dictionary = Flow.after_battle(&"wolves", res, Game.state, Game.rng, _defs())
	assert_ne(second.wake_events[0].line_key, after.wake_events[0].line_key, "Fanfi varies the line")
	# The temple floor is walkable in the town map.
	var grid: Grid = Grid.from_map(_defs().get_def(&"map", &"sarmizegetusa"), _defs().json("tiles"))
	assert_true(grid.is_walkable(Flow.TEMPLE_CELL), "temple floor")

func test_win_and_flee_change_nothing() -> void:
	_new()
	for o in ["win", "fled"]:
		var after: Dictionary = Flow.after_battle(&"wolves", _result(o), Game.state, Game.rng, _defs())
		assert_eq(after.mode, &"")
		assert_eq(after.events.size(), 0)
		assert_eq(after.wake, "")

func test_temple_wake_up_broadcasts_fanfi_after_the_card() -> void:
	var after: Dictionary = {"wake": "temple", "wake_events": [{"type": "narrator", "line_key": "flow_defeat_1"}]}
	var w: Node = Flow.show_wake(after)
	assert_eq(w.title_key(), "flow_wake_temple_title")
	assert_eq(count_events(bus_events, "narrator"), 0)
	await get_tree().create_timer(3.0).timeout
	assert_eq(count_events(bus_events, "narrator"), 1)
	assert_false(is_instance_valid(w))

# ---------------------------------------------------------------- Review Focus 5

func test_quit_mid_abduction_reload_gives_the_last_autosave() -> void:
	_new(21)
	Router.save_fn = _old_save_fn   # the real Game.save
	Game.state.world_pos = Vector2i(28, 16)   # on the road west of the UFO's loop, by day
	Game.state.hour = 10
	Game.state.flags["enc_cooldown"] = 999
	_ufo()["pos"] = Vector2i(31, 16)
	_ufo()["route_i"] = 18
	Router.go(&"worldmap")   # the last mode change: autosave
	var saved: Dictionary = Game.state.to_dict()
	# Walk east into the UFO until it beams the party up.
	var abd: Dictionary = {}
	for i in 12:
		var ev: Array[Dictionary] = Travel.step(Game.state, Game.state.world_pos + Vector2i(1, 0), Game.rng, _defs())
		abd = find_event(ev, "abducted")
		if not abd.is_empty(): break
	assert_false(abd.is_empty(), "abducted")
	Flow.instant = true
	Flow.play_abduction(StringName(str(abd.ufo)), StringName(str(abd.encounter)), Vector2.ZERO)
	assert_eq(Router.current, &"combat")
	# Force-quit here: nothing after the battle runs. Then Continue.
	Game.state = GameState.new()
	assert_eq(Game.load_slot(0), OK)
	assert_eq(Game.state.to_dict(), saved, "state equals the autosave from the last mode change")
	assert_eq(Game.state.mode, &"worldmap", "still on the world map")
	assert_ne(Rules.to_cell(_ufo().pos), Game.state.world_pos, "the UFO is not yet on its cell")
	assert_eq(_ufo().state, "patrol")
	assert_false(Game.state.flags.has("times_abducted"))
	assert_eq(Router.resume_args(), {})

# ---------------------------------------------------------------- Continue after transitions

func _continue_target() -> Array:
	var st: GameState = _slot0()
	var old: GameState = Game.state
	Game.state = st
	var args: Dictionary = Router.resume_args()
	Game.state = old
	return [st.mode, args]

func test_every_transition_resumes_in_the_right_place() -> void:
	_new()
	Router.save_fn = _old_save_fn
	Router.go(&"location", {"location_id": &"sarmizegetusa"})
	assert_eq(_continue_target(), [&"location", {"location_id": &"sarmizegetusa", "cell": Vector2i(19, 36)}],
		"entry cell recorded before the autosave")
	Router.go(&"scroll", {"return_mode": &"location",
		"return_args": {"location_id": &"sarmizegetusa", "cell": Vector2i(10, 12)}})
	assert_eq(_continue_target(), [&"location", {"location_id": &"sarmizegetusa", "cell": Vector2i(10, 12)}],
		"the scroll resumes where it was opened")
	Router.go(&"worldmap")
	assert_eq(_continue_target(), [&"worldmap", {}])
	Router.go(&"scroll", {"return_mode": &"worldmap", "return_args": {}})
	assert_eq(_continue_target(), [&"worldmap", {}], "not into the town of a stale location_id")
	Router.go(&"scroll")
	assert_eq(Game.state.mode, &"worldmap", "scroll without args keeps the mode underneath")
	Router.go(&"location", {"location_id": &"strigoi_cave", "cell": [7, 8]})
	Router.go(&"combat", {"encounter_id": &"cave_wolves", "return_mode": &"location", "return_args": {}})
	assert_eq(_continue_target(), [&"location", {"location_id": &"strigoi_cave", "cell": Vector2i(7, 8)}],
		"combat keeps the last save")
	Router.go(&"menu")
	assert_eq(_continue_target()[0], &"location")

func test_old_save_in_scroll_mode_resumes_on_the_world_map() -> void:
	_new()
	Game.state.mode = &"scroll"
	Router.go(&"scroll")
	assert_eq(Game.state.mode, &"worldmap")

# ---------------------------------------------------------------- Hud and content

func test_hud_narrator_does_not_touch_game_rng() -> void:
	_new()
	var before: int = Game.rng.get_state()
	var ev: Array[Dictionary] = [{"type": "page_found", "page": &"page_tavern"}, {"type": "level_up", "unit": &"hero", "level": 2}]
	for i in 5: Bus.emit_events(ev)
	assert_eq(Game.rng.get_state(), before)
	assert_true(Hud.caption.is_showing(), "Fanfi still speaks")

func _visible(map_id: StringName, entity: String) -> bool:
	for e in _defs().get_def(&"map", map_id).get("entities", []):
		if str(e.get("id", "")) == entity: return Rules.check(e.get("if", []), Game.state, _defs())
	fail("no entity " + entity)
	return false

func test_duras_coffin_needs_a_won_fight() -> void:
	_new()
	Game.state.flags["duras_fought"] = true   # chose to fight, then lost
	assert_false(_visible(&"strigoi_cave", "duras_coffin"), "no reward for losing")
	assert_true(_visible(&"strigoi_cave", "duras"), "Duras is still there to try again")
	Game.state.flags["won_cave_strigoi"] = true
	assert_true(_visible(&"strigoi_cave", "duras_coffin"))
	assert_false(_visible(&"strigoi_cave", "duras"))

func test_ozo_parcel_needs_a_won_fight_or_a_deal() -> void:
	_new()
	Game.state.flags["ozo_fought"] = true
	assert_false(_visible(&"crash_site", "parcel"))
	assert_true(_visible(&"crash_site", "ozo"))
	Game.state.flags["won_crash_thrall"] = true
	assert_true(_visible(&"crash_site", "parcel"))
	assert_false(_visible(&"crash_site", "ozo"))
	_new()
	Game.state.flags["ozo_gone"] = true   # bribed or freed
	assert_true(_visible(&"crash_site", "parcel"))
	assert_false(_visible(&"crash_site", "ozo"))
