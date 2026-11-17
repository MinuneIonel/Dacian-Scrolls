## Router: autosaves to slot 0 except into menu and combat, and only with a party.
extends TestCase

var saves: Array[int] = []
var _old_state: GameState
var _old_save_fn: Callable

func before_each() -> void:
	saves.clear()
	_old_state = Game.state
	_old_save_fn = Router.save_fn
	Game.state = GameState.new()
	Router.switch_scenes = false
	Router.save_fn = func(slot: int) -> Error:
		saves.append(slot)
		return OK

func after_each() -> void:
	Game.state = _old_state
	Router.save_fn = _old_save_fn
	Router.switch_scenes = true
	Router.args = {}
	Router.current = &""

func _with_party() -> void:
	var c := Character.new()
	c.id = &"hero"
	Game.state.party.append(c)

func test_worldmap_autosaves_to_slot_0_with_a_party() -> void:
	_with_party()
	Router.go(&"worldmap")
	assert_eq(saves, [0])
	assert_eq(Router.current, &"worldmap")
	assert_eq(Game.state.mode, &"worldmap")

func test_combat_does_not_save() -> void:
	_with_party()
	Game.state.mode = &"location"
	Router.go(&"combat", {"encounter_id": &"x", "return_mode": &"location", "return_args": {}})
	assert_eq(saves.size(), 0)
	assert_eq(Game.state.mode, &"location", "combat is never the resume mode")
	assert_eq(Router.args.encounter_id, &"x")

func test_menu_does_not_save() -> void:
	_with_party()
	Router.go(&"menu")
	assert_eq(saves.size(), 0)

func test_no_party_no_autosave() -> void:
	Router.go(&"worldmap")
	Router.go(&"location", {"location_id": &"sarmizegetusa"})
	assert_eq(saves.size(), 0)

func test_autosave_can_be_disabled() -> void:
	_with_party()
	Router.autosave_enabled = false
	Router.go(&"scroll")
	Router.autosave_enabled = true
	assert_eq(saves.size(), 0)

func test_unknown_mode_is_an_error_and_changes_nothing() -> void:
	expect_errors(1)
	Router.go(&"disco")
	assert_eq(Router.current, &"")

func test_mode_changed_signal_fires() -> void:
	var got: Array[StringName] = []
	var cb := func(m: StringName) -> void: got.append(m)
	Router.mode_changed.connect(cb)
	Router.go(&"scroll")
	Router.mode_changed.disconnect(cb)
	assert_eq(got, [&"scroll"])

func test_resume_args_for_location() -> void:
	Game.state.mode = &"location"
	Game.state.location_id = &"sarmizegetusa"
	Game.state.location_cell = Vector2i(3, 4)
	assert_eq(Router.resume_args(), {"location_id": &"sarmizegetusa", "cell": Vector2i(3, 4)})
	Game.state.mode = &"worldmap"
	assert_eq(Router.resume_args(), {})

func test_default_save_goes_through_game_save() -> void:
	# Game.save is a stub until WP-10; whatever it does, the default hook must reach it.
	assert_true(_old_save_fn.is_valid())
	assert_eq(_old_save_fn.get_method(), &"_default_save")
