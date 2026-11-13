## World map view: builds headless, travels on a second click, stops on encounters, routes
## abductions and arrivals, and draws terrain only on revealed cells. Uses the real world.json
## (the view is about that map) with Router scene switching and autosave off.
extends TestCase

const TOWN := Vector2i(24, 16)
const SOUTH := Vector2i(24, 19)        # three road cells south of the town, far from the UFO

## An Rng whose chance() always succeeds: every eligible step rolls an encounter.
class AlwaysRng extends Rng:
	func chance(_p: float) -> bool:
		return true

var view: Control
var emitted: Array[Dictionary] = []
var _saved_rng: Rng

func before_each() -> void:
	Router.switch_scenes = false
	Router.autosave_enabled = false
	Router.args = {}
	Router.current = &""
	Game.new_game(1, &"knight")
	Game.state.mode = &"worldmap"
	_saved_rng = Game.rng
	emitted = []
	Bus.events_emitted.connect(_on_events)

func after_each() -> void:
	if Bus.events_emitted.is_connected(_on_events): Bus.events_emitted.disconnect(_on_events)
	if view != null and is_instance_valid(view): view.free()
	view = null
	Router.switch_scenes = true
	Router.autosave_enabled = true
	Router.args = {}
	Router.current = &""
	Game.state = GameState.new()
	Game.rng = Rng.new(0)

func _on_events(events: Array[Dictionary]) -> void:
	emitted.append_array(events)

func _open(args: Dictionary = {}) -> void:
	Router.args = args
	view = load("res://src/modes/worldmap/worldmap.tscn").instantiate()
	add_child(view)
	view.step_time = 0.0
	await wait_frames(2)

func _wait_travel(max_frames: int = 120) -> void:
	var n: int = 0
	while view.traveling and n < max_frames:
		await wait_frames(1)
		n += 1

func test_builds_headless_with_hud() -> void:
	await _open()
	assert_not_null(view.map_view)
	assert_eq(view.hud_clock.text, tr("wm_clock") % [1, 8])
	assert_eq(view.hud_food.text, tr("wm_food") % 12)
	assert_eq(view.hud_pages.text, tr("wm_pages") % [0, 12])
	assert_false(view.night_tint.visible, "08:00 is day")
	assert_eq(view.ufo_nodes.size(), Game.state.ufos.size())

func test_click_reachable_cell_previews_then_travels() -> void:
	Game.state.flags["enc_cooldown"] = 999
	await _open()
	view.click_cell(SOUTH)
	assert_eq(view.pending_path.size(), 3)
	assert_true(view.tooltip.visible, "the cost tooltip shows")
	assert_eq(Game.state.world_pos, TOWN, "first click only previews")
	assert_eq(Game.state.hour, 8)
	view.click_cell(SOUTH)
	assert_true(view.traveling)
	await _wait_travel()
	assert_false(view.traveling)
	assert_eq(Game.state.world_pos, SOUTH)
	assert_eq(Game.state.hour, 11, "three road cells, one hour each")
	assert_eq(count_events(emitted, "stepped"), 3, "every step goes to Bus.emit_events")
	assert_eq(view.hud_clock.text, tr("wm_clock") % [1, 11])

func test_mouse_clicks_travel_too() -> void:
	Game.state.flags["enc_cooldown"] = 999
	await _open()
	for i in 2:
		for pressed in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = pressed
			e.position = view.screen_of(Vector2i(24, 17))
			view._on_map_input(e)
	await _wait_travel()
	assert_eq(Game.state.world_pos, Vector2i(24, 17))

func test_unreachable_click_does_nothing() -> void:
	await _open()
	for c in [Vector2i(29, 5), Vector2i(-3, -3), Vector2i(99, 4)]:
		view.click_cell(c)
		view.click_cell(c)
		assert_false(view.traveling)
		assert_true(view.pending_path.is_empty())
	await wait_frames(3)
	assert_eq(Game.state.world_pos, TOWN)
	assert_eq(Game.state.hour, 8)
	assert_eq(Game.state.day, 1)
	assert_eq(emitted.size(), 0)

func test_route_cost_counts_food_per_midnight() -> void:
	await _open()
	Game.state.hour = 22
	var p: Array[Vector2i] = [Vector2i(24, 17), Vector2i(24, 18), Vector2i(24, 19)]
	assert_eq(view.route_cost(p), Vector2i(3, 1))
	Game.state.hour = 8
	assert_eq(view.route_cost(p), Vector2i(3, 0))

func test_encounter_stops_travel_and_shows_options() -> void:
	Game.rng = AlwaysRng.new(3)
	await _open()
	view.click_cell(SOUTH)
	view.click_cell(SOUTH)
	await _wait_travel()
	assert_false(view.traveling)
	assert_eq(Game.state.world_pos, Vector2i(24, 17), "stopped after the first step")
	assert_not_null(view.modal)
	assert_ne(view.encounter_id, &"")
	assert_has(view.option_ids, "fight")
	assert_has(view.option_ids, "flee")
	assert_eq(view.option_buttons.size(), view.option_ids.size())
	var flee: Button = view.option_buttons[view.option_ids.find("flee")]
	assert_true(flee.text.ends_with("%)"), "roll options show their chance: " + flee.text)
	# Fighting goes to combat and back to the world map.
	view.choose_option("fight")
	assert_eq(Router.current, &"combat")
	assert_eq(Router.args.get("return_mode"), &"worldmap")
	assert_eq(Router.args.get("return_args"), {})
	assert_ne(str(Router.args.get("encounter_id", "")), "")

func test_peaceful_option_shows_outcome_then_continues() -> void:
	await _open()
	Game.state.inventory[&"bread"] = 2
	view.open_encounter(&"wolves")
	assert_has(view.option_ids, "bribe")
	view.choose_option("bribe")
	assert_eq(Router.current, &"", "no battle")
	assert_eq(Game.state.inventory.get(&"bread", 0), 1)
	assert_not_null(find_event(emitted, "narrator").get("line_key"))
	await wait_frames(1)
	assert_not_null(view.modal, "outcome panel")
	assert_eq(view.encounter_id, &"")

func test_abducted_routes_to_combat() -> void:
	Flow.instant = true   # WP-30: skip the beam animation
	Game.state.flags["enc_cooldown"] = 999
	Game.state.ufos[0]["pos"] = Vector2i(27, 16)
	Game.state.ufos[0]["state"] = "chase"
	await _open()
	view.click_cell(Vector2i(25, 16))
	view.click_cell(Vector2i(25, 16))
	await _wait_travel()
	Flow.instant = false
	assert_eq(find_event(emitted, "abducted").get("encounter"), &"saucer_surgeon")
	assert_eq(Router.current, &"combat")
	assert_eq(Router.args.get("encounter_id"), &"saucer_surgeon")
	assert_eq(Router.args.get("return_mode"), &"worldmap")

func test_arrival_prompts_to_enter() -> void:
	Game.state.flags["enc_cooldown"] = 999
	Game.state.world_pos = SOUTH
	await _open()
	view.click_cell(TOWN)
	view.click_cell(TOWN)
	await _wait_travel()
	assert_eq(Game.state.world_pos, TOWN)
	assert_eq(view.enter_location, &"sarmizegetusa")
	view.enter(&"sarmizegetusa")
	assert_eq(Router.current, &"location")
	assert_eq(Router.args.get("location_id"), &"sarmizegetusa")

func test_fog_draws_only_revealed_cells() -> void:
	await _open()
	await wait_frames(1)
	assert_eq(view.canvas.drawn_cells, Game.state.revealed.size())
	assert_eq(Game.state.revealed.size(), 25, "radius 2 around the start")
	assert_eq(view.fog.alpha_at(TOWN), 0.0, "the party's cell is clear")
	assert_eq(view.fog.alpha_at(Vector2i(0, 0)), 1.0, "unrevealed is fully dark")
	assert_eq(view.fog.alpha_at(TOWN + Vector2i(3, 0)), 1.0)
	var ids: Array = view.overlay.visible_locations().map(func(l: Dictionary) -> String: return str(l.id))
	assert_eq(ids, ["sarmizegetusa"], "hidden locations stay invisible")

func test_reveal_all_and_night_tint() -> void:
	Game.state.hour = 22
	await _open({"debug_reveal_all": true})
	await wait_frames(1)
	assert_eq(view.canvas.drawn_cells, 48 * 32)
	assert_eq(view.fog.alpha_at(Vector2i(0, 0)), 0.0)
	assert_true(view.night_tint.visible)
