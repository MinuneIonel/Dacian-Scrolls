## WP-13: Ufo.tick patrol, chase, back to patrol, abduction, decoy_charm, gone.
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
	s.hour = 12
	s.ufos.append({"id": &"fx_ufo", "pos": Vector2i(3, 6), "state": "patrol", "route_i": 0})
	rng = Rng.new(1)

func _tick() -> Array[Dictionary]:
	return Ufo.tick(s, rng, defs)

func _u() -> Dictionary:
	return s.ufos[0]

func test_patrol_follows_route_one_cell_per_step_and_loops() -> void:
	s.world_pos = Vector2i(0, 0)
	s.hour = 22   # night: party at (0,0) stays out of radius 2 of the route
	var seen: Array[Vector2i] = []
	for i in 15:
		_tick()
		seen.append(_u().pos)
		assert_eq(_u().state, "patrol")
	assert_eq(seen[4], Vector2i(8, 6))
	assert_eq(seen[6], Vector2i(8, 4))
	assert_eq(seen[11], Vector2i(3, 4))
	assert_eq(seen[13], Vector2i(3, 6), "looped back to the start")
	assert_eq(seen[14], Vector2i(4, 6))

func test_patrol_emits_ufo_moved() -> void:
	s.world_pos = Vector2i(0, 0)
	s.hour = 22
	var ev: Array[Dictionary] = _tick()
	var e: Dictionary = find_event(ev, "ufo_moved")
	assert_eq(e.id, &"fx_ufo")
	assert_eq(e.pos, Vector2i(4, 6))
	assert_eq(e.state, "patrol")

func test_chase_when_within_five_by_day() -> void:
	s.world_pos = Vector2i(3, 1)   # road, 5 cells north
	var ev: Array[Dictionary] = _tick()
	assert_eq(_u().state, "chase")
	assert_eq(_u().pos, Vector2i(3, 4), "2 cells toward the party")
	assert_eq(find_event(ev, "ufo_moved").state, "chase")

func test_no_chase_beyond_five() -> void:
	s.world_pos = Vector2i(3, 0)   # plains, 6 cells
	_tick()
	assert_eq(_u().state, "patrol")

func test_night_radius_is_two() -> void:
	s.hour = 22
	s.world_pos = Vector2i(3, 1)
	_tick()
	assert_eq(_u().state, "patrol", "5 cells at night: not seen")
	s.ufos[0] = {"id": &"fx_ufo", "pos": Vector2i(3, 6), "state": "patrol", "route_i": 0}
	s.world_pos = Vector2i(3, 4)
	_tick()
	assert_eq(_u().state, "chase", "2 cells at night: seen")

func test_forest_hides_party() -> void:
	s.ufos[0].pos = Vector2i(4, 5)
	s.world_pos = Vector2i(4, 4)   # forest, 1 cell away
	_tick()
	assert_eq(_u().state, "patrol")

func test_chase_moves_two_cells_per_step() -> void:
	s.ufos[0] = {"id": &"fx_ufo", "pos": Vector2i(3, 7), "state": "chase", "route_i": 0}
	s.world_pos = Vector2i(3, 1)   # 6 away: beyond detection but under 8, keeps chasing
	_tick()
	assert_eq(_u().pos, Vector2i(3, 5))
	_tick()
	assert_eq(_u().pos, Vector2i(3, 3))
	assert_eq(_u().state, "chase")

func test_back_to_patrol_when_party_enters_forest() -> void:
	s.ufos[0] = {"id": &"fx_ufo", "pos": Vector2i(3, 6), "state": "chase", "route_i": 1}
	s.world_pos = Vector2i(4, 4)
	var ev: Array[Dictionary] = _tick()
	assert_eq(_u().state, "patrol")
	assert_eq(_u().pos, Vector2i(4, 6), "resumes the route")
	assert_eq(find_event(ev, "ufo_moved").state, "patrol")

func test_back_to_patrol_at_eight_cells() -> void:
	s.ufos[0] = {"id": &"fx_ufo", "pos": Vector2i(0, 7), "state": "chase", "route_i": 0}
	s.world_pos = Vector2i(8, 0)
	_tick()
	assert_eq(_u().state, "patrol")

func test_abducted_on_party_cell() -> void:
	s.world_pos = Vector2i(3, 5)
	var ev: Array[Dictionary] = _tick()
	var a: Dictionary = find_event(ev, "abducted")
	assert_eq(a.ufo, &"fx_ufo")
	assert_eq(a.encounter, &"fx_saucer")
	assert_eq(_u().pos, Vector2i(3, 5))

func test_decoy_charm_ignores_party_once_and_clears() -> void:
	s.flags["decoy_charm"] = true
	s.world_pos = Vector2i(3, 4)
	var ev: Array[Dictionary] = _tick()
	assert_eq(_u().state, "patrol")
	assert_eq(s.flags["decoy_charm"], false)
	var f: Dictionary = find_event(ev, "flag_set")
	assert_eq(f.flag, "decoy_charm")
	assert_eq(f.value, false)
	_tick()
	assert_eq(_u().state, "chase", "the charm worked once")

func test_gone_ufo_never_acts() -> void:
	s.ufos[0].state = "gone"
	s.world_pos = Vector2i(3, 5)
	for i in 5: assert_eq(_tick(), [] as Array[Dictionary])
	assert_eq(_u().pos, Vector2i(3, 6))

func test_two_ufos_abduct_once() -> void:
	s.ufos.append({"id": &"fx_ufo", "pos": Vector2i(4, 5), "state": "chase", "route_i": 0})
	s.world_pos = Vector2i(3, 5)
	assert_eq(count_events(_tick(), "abducted"), 1)
