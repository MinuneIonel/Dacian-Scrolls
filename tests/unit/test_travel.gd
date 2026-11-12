## WP-13: Travel.path / step / terrain_at, time, food, discovery, encounter rolls, fuzz.
extends TestCase

const FIXTURES: String = "res://tests/fixtures/data"

var defs: Defs
var s: GameState
var rng: Rng

func before_all() -> void:
	defs = ContentLoader.load_root(FIXTURES)

func before_each() -> void:
	s = _state(1)
	rng = Rng.new(1)

func _state(members: int) -> GameState:
	var st := GameState.new()
	var classes: Array[StringName] = [&"fx_knight", &"fx_necro", &"fx_necro", &"fx_knight"]
	for i in members:
		var id: StringName = &"hero" if i == 0 else StringName("fx_m%d" % i)
		st.party.append(Character.create(id, defs.get_def(&"class", classes[i]), "hero_name"))
	st.food = 12
	st.gold = 24
	st.day = 1
	st.hour = 8
	return st

## A Defs on the fixtures whose world has every encounter chance set to `chance`.
func _defs_with_chance(chance: float) -> Defs:
	var d: Defs = ContentLoader.load_root(FIXTURES)
	var w: Dictionary = d.json("world").duplicate(true)
	for t in w.terrain_rules:
		if w.terrain_rules[t].passable: w.terrain_rules[t].encounter_chance = chance
	w.ufos = []
	d.set_json("world", w)
	return d

func _walk(p: Array[Vector2i], d: Defs = defs) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in p: out.append_array(Travel.step(s, c, rng, d))
	return out

# ---- terrain ----------------------------------------------------------------

func test_terrain_at() -> void:
	assert_eq(Travel.terrain_at(Vector2i(0, 0), defs), "plains")
	assert_eq(Travel.terrain_at(Vector2i(2, 1), defs), "road")
	assert_eq(Travel.terrain_at(Vector2i(2, 0), defs), "forest")
	assert_eq(Travel.terrain_at(Vector2i(8, 5), defs), "mountain")
	assert_eq(Travel.terrain_at(Vector2i(6, 0), defs), "river")
	assert_eq(Travel.terrain_at(Vector2i(-1, 0), defs), "")
	assert_eq(Travel.terrain_at(Vector2i(12, 0), defs), "")
	assert_eq(Travel.terrain_at(Vector2i(0, 8), defs), "")

func test_three_road_cells_from_hour_8_end_at_hour_11() -> void:
	s.world_pos = Vector2i(1, 1)
	var p: Array[Vector2i] = Travel.path(s, Vector2i(4, 1), defs)
	assert_eq(p, [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)] as Array[Vector2i])
	var ev: Array[Dictionary] = _walk(p)
	assert_eq(s.hour, 11)
	assert_eq(s.day, 1)
	assert_eq(s.world_pos, Vector2i(4, 1))
	assert_eq(count_events(ev, "stepped"), 3)
	assert_eq(find_event(ev, "stepped").hours, 1)
	var tc: Dictionary = {}
	for e in ev:
		if e.type == "time_changed": tc = e
	assert_eq(tc.hour, 11)
	assert_eq(tc.day, 1)

func test_forest_costs_four_hours() -> void:
	s.world_pos = Vector2i(3, 2)
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(4, 2), rng, defs)
	assert_eq(find_event(ev, "stepped").hours, 4)
	assert_eq(s.hour, 12)

func test_mountain_and_plains_hours() -> void:
	s.world_pos = Vector2i(7, 5)
	assert_eq(find_event(Travel.step(s, Vector2i(8, 5), rng, defs), "stepped").hours, 6)
	assert_eq(find_event(Travel.step(s, Vector2i(8, 4), rng, defs), "stepped").hours, 2)
	assert_eq(s.hour, 16)

func test_path_prefers_fewer_hours() -> void:
	s.world_pos = Vector2i(1, 1)
	var p: Array[Vector2i] = Travel.path(s, Vector2i(1, 5), defs)
	assert_eq(p, [Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(1, 5)] as Array[Vector2i])
	# Around the forest on road (5 h) beats straight through it (6 h).
	s.world_pos = Vector2i(3, 2)
	var q: Array[Vector2i] = Travel.path(s, Vector2i(5, 2), defs)
	assert_eq(q, [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(5, 2)] as Array[Vector2i])

func test_river_never_in_a_path() -> void:
	var size: Vector2i = Travel.world_size(defs)
	var paths: int = 0
	for y in size.y:
		for x in size.x:
			s.world_pos = Vector2i(0, 7)
			var p: Array[Vector2i] = Travel.path(s, Vector2i(x, y), defs)
			if not p.is_empty(): paths += 1
			for i in p.size():
				assert_true(Travel.terrain_at(p[i], defs) != "river", "river at %s" % p[i])
				var from: Vector2i = s.world_pos if i == 0 else p[i - 1]
				assert_eq(absi(p[i].x - from.x) + absi(p[i].y - from.y), 1, "4-way")
	assert_true(paths > 50)

func test_path_to_river_enclosed_cell_is_empty_and_no_time_passes() -> void:
	s.world_pos = Vector2i(5, 1)
	assert_eq(Travel.path(s, Vector2i(8, 1), defs), [] as Array[Vector2i])
	assert_eq(Travel.path(s, Vector2i(6, 1), defs), [] as Array[Vector2i], "river itself")
	assert_eq(Travel.path(s, Vector2i(30, 1), defs), [] as Array[Vector2i], "outside")
	assert_eq(Travel.path(s, Vector2i(5, 1), defs), [] as Array[Vector2i], "already there")
	assert_eq(s.hour, 8)
	assert_eq(s.day, 1)
	assert_eq(s.world_pos, Vector2i(5, 1))

func test_step_into_river_or_not_adjacent_does_nothing() -> void:
	s.world_pos = Vector2i(5, 1)
	assert_eq(Travel.step(s, Vector2i(6, 1), rng, defs), [] as Array[Dictionary])
	assert_eq(Travel.step(s, Vector2i(5, 3), rng, defs), [] as Array[Dictionary])
	assert_eq(Travel.step(s, Vector2i(4, 2), rng, defs), [] as Array[Dictionary], "diagonal")
	assert_eq(s.world_pos, Vector2i(5, 1))
	assert_eq(s.hour, 8)
	assert_true(s.revealed.is_empty())

# ---- fog --------------------------------------------------------------------

func test_fog_exactly_radius_two_after_one_step() -> void:
	s.world_pos = Vector2i(3, 4)
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(3, 5), rng, defs)
	assert_eq(s.revealed.size(), 25)
	for y in range(0, 8):
		for x in range(0, 12):
			var inside: bool = absi(x - 3) <= 2 and absi(y - 5) <= 2
			assert_eq(Fog.is_revealed(s, Vector2i(x, y)), inside, "cell %d,%d" % [x, y])
	assert_eq(find_event(ev, "revealed").cells.size(), 25)

func test_fog_clipped_at_edge_and_only_new_cells() -> void:
	var size := Vector2i(12, 8)
	assert_eq(Fog.reveal(s, Vector2i(0, 0), 2, size).size(), 9)
	var again: Array[Vector2i] = Fog.reveal(s, Vector2i(1, 0), 2, size)
	assert_eq(again, [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)] as Array[Vector2i])
	assert_eq(Fog.reveal(s, Vector2i(1, 0), 2, size).size(), 0)

func test_no_revealed_event_when_nothing_new() -> void:
	Fog.reveal(s, Vector2i(3, 4), 4, Vector2i(12, 8))
	s.world_pos = Vector2i(3, 4)
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(3, 5), rng, defs)
	assert_eq(count_events(ev, "revealed"), 0)

# ---- time and food ----------------------------------------------------------

func test_crossing_midnight_with_party_of_three_eats_three_food() -> void:
	s = _state(3)
	s.hour = 23
	s.food = 10
	s.world_pos = Vector2i(2, 1)
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(3, 1), rng, defs)
	assert_eq(s.food, 7)
	assert_eq(s.day, 2)
	assert_eq(s.hour, 0)
	var f: Dictionary = find_event(ev, "food_changed")
	assert_eq(f.food, 7)
	assert_eq(f.delta, -3)
	assert_eq(count_events(ev, "starved"), 0)
	var t: Dictionary = find_event(ev, "time_changed")
	assert_eq(t.day, 2)
	assert_eq(t.hour, 0)

func test_no_food_eaten_without_midnight() -> void:
	s.hour = 20
	s.world_pos = Vector2i(3, 2)
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(4, 2), rng, defs)   # forest, 4 h -> 0:00
	assert_eq(s.hour, 0)
	assert_eq(s.food, 11)
	s.hour = 19
	ev = Travel.step(s, Vector2i(3, 2), rng, defs)   # plains, 2 h
	assert_eq(count_events(ev, "food_changed"), 0)
	assert_eq(s.food, 11)

func test_starvation_costs_two_hp_never_below_one() -> void:
	s = _state(3)
	s.food = 1
	s.hour = 23
	s.party[0].hp = 10
	s.party[1].hp = 2
	s.party[2].hp = 1
	s.world_pos = Vector2i(2, 1)
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(3, 1), rng, defs)
	assert_eq(s.food, 0)
	assert_eq(find_event(ev, "food_changed").delta, -1)
	assert_eq(find_event(ev, "starved").amount, 2)
	assert_eq(s.party[0].hp, 8)
	assert_eq(s.party[1].hp, 1)
	assert_eq(s.party[2].hp, 1)
	# Many more days of starving: nobody dies, one starved event per midnight.
	var starved: int = 0
	for i in 40:
		s.world_pos = Vector2i(3, 2)
		starved += count_events(Travel.step(s, Vector2i(4, 2), rng, defs), "starved")
		s.world_pos = Vector2i(4, 2)
		starved += count_events(Travel.step(s, Vector2i(3, 2), rng, defs), "starved")
	assert_eq(starved, s.day - 2)
	for m in s.party: assert_eq(m.hp, 1)
	assert_eq(s.food, 0)

func test_long_step_crosses_midnight_once() -> void:
	s.hour = 22
	s.world_pos = Vector2i(7, 5)
	Travel.step(s, Vector2i(8, 5), rng, defs)   # mountain 6 h
	assert_eq(s.day, 2)
	assert_eq(s.hour, 4)
	assert_eq(s.food, 11)

# ---- discovery --------------------------------------------------------------

func test_discovers_non_hidden_location_within_radius_one() -> void:
	s.world_pos = Vector2i(3, 2)
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(2, 2), rng, defs)
	assert_eq(find_event(ev, "discovered").location, &"fx_town")
	assert_has(s.discovered, &"fx_town")
	assert_eq(count_events(ev, "arrived"), 0)
	ev = Travel.step(s, Vector2i(2, 1), rng, defs)
	assert_eq(count_events(ev, "discovered"), 0, "only once")

func test_arrived_on_location_cell_and_no_encounter_roll() -> void:
	var d: Defs = _defs_with_chance(1.0)
	s.world_pos = Vector2i(2, 1)
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(1, 1), rng, d)
	assert_eq(find_event(ev, "discovered").location, &"fx_town")
	assert_eq(find_event(ev, "arrived").location, &"fx_town")
	assert_eq(count_events(ev, "encounter"), 0)

func test_hidden_location_not_discovered_by_walking() -> void:
	s.world_pos = Vector2i(10, 6)
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(9, 6), rng, defs)
	assert_eq(count_events(ev, "discovered"), 0)
	assert_eq(count_events(ev, "arrived"), 0)
	assert_not_has(s.discovered, &"fx_cave")
	s.discovered.append(&"fx_cave")
	s.world_pos = Vector2i(10, 6)
	ev = Travel.step(s, Vector2i(9, 6), rng, defs)
	assert_eq(find_event(ev, "arrived").location, &"fx_cave")

# ---- encounters -------------------------------------------------------------

func test_encounter_then_three_step_cooldown() -> void:
	var d: Defs = _defs_with_chance(1.0)
	s.world_pos = Vector2i(3, 3)
	var got: Array[int] = []
	for i in 9:
		var to := Vector2i(3, 4) if s.world_pos == Vector2i(3, 3) else Vector2i(3, 3)
		var ev: Array[Dictionary] = Travel.step(s, to, rng, d)
		got.append(count_events(ev, "encounter"))
		if got[-1] == 1: assert_eq(find_event(ev, "encounter").encounter, &"fx_wolves")
	assert_eq(got, [1, 0, 0, 0, 1, 0, 0, 0, 1] as Array[int])

func test_no_encounter_with_zero_chance() -> void:
	var d: Defs = _defs_with_chance(0.0)
	s.world_pos = Vector2i(3, 3)
	for i in 50:
		var to := Vector2i(3, 4) if s.world_pos == Vector2i(3, 3) else Vector2i(3, 3)
		assert_eq(count_events(Travel.step(s, to, rng, d), "encounter"), 0)

func test_encounter_rate_roughly_matches_terrain_chance() -> void:
	# Plains 10%; with the 3-step cooldown the expected share of steps is 0.1 / 1.3.
	var hits: int = 0
	var steps: int = 4000
	s.world_pos = Vector2i(3, 3)
	var d: Defs = ContentLoader.load_root(FIXTURES)
	var w: Dictionary = d.json("world").duplicate(true)
	w.ufos = []
	d.set_json("world", w)
	for i in steps:
		var to := Vector2i(3, 4) if s.world_pos == Vector2i(3, 3) else Vector2i(3, 3)
		hits += count_events(Travel.step(s, to, rng, d), "encounter")
	assert_between(float(hits) / steps, 0.06, 0.095)

func test_step_ticks_ufos_and_abduction_sets_cooldown() -> void:
	s.world_pos = Vector2i(3, 4)
	s.ufos = [{"id": &"fx_ufo", "pos": Vector2i(3, 6), "state": "patrol", "route_i": 0}]
	var ev: Array[Dictionary] = Travel.step(s, Vector2i(3, 5), rng, defs)
	assert_eq(find_event(ev, "abducted").ufo, &"fx_ufo")
	assert_eq(int(s.flags["enc_cooldown"]), 3)

func test_same_seed_same_events() -> void:
	var a: GameState = _state(2)
	var b: GameState = _state(2)
	for st: GameState in [a, b]:
		st.world_pos = Vector2i(0, 7)
		st.ufos.append({"id": &"fx_ufo", "pos": Vector2i(3, 6), "state": "patrol", "route_i": 0})
	var p: Array[Vector2i] = Travel.path(a, Vector2i(11, 7), defs)
	var ra := Rng.new(5)
	var rb := Rng.new(5)
	var ea: Array = []
	var eb: Array = []
	for c in p:
		ea.append_array(Travel.step(a, c, ra, defs))
		eb.append_array(Travel.step(b, c, rb, defs))
	assert_eq(var_to_str(ea), var_to_str(eb))
	assert_eq(var_to_str(a.to_dict()), var_to_str(b.to_dict()))

# ---- fuzz -------------------------------------------------------------------

func test_fuzz_random_journeys() -> void:
	var size: Vector2i = Travel.world_size(defs)
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if Travel.passable(Vector2i(x, y), defs): cells.append(Vector2i(x, y))
	for seed_i in 300:
		var r := Rng.new(1000 + seed_i)
		var st: GameState = _state(r.randi_range(1, 4))
		st.food = r.randi_range(0, 6)
		st.hour = r.randi_range(0, 23)
		for m in st.party: m.hp = r.randi_range(1, m.max_hp)
		st.world_pos = r.pick(cells)
		st.ufos = [{"id": &"fx_ufo", "pos": Vector2i(3, 6), "state": "patrol", "route_i": 0}]
		if r.chance(0.3): st.flags["decoy_charm"] = true
		for leg in 3:
			var p: Array[Vector2i] = Travel.path(st, r.pick(cells), defs)
			for c in p:
				var hour_before: int = st.day * 24 + st.hour
				var ev: Array[Dictionary] = Travel.step(st, c, r, defs)
				assert_eq(st.world_pos, c)
				assert_true(Travel.passable(st.world_pos, defs))
				assert_true(st.day * 24 + st.hour > hour_before, "time moves")
				assert_true(st.food >= 0)
				for m in st.party: assert_true(m.hp >= 1, "hp %d" % m.hp)
				if count_events(ev, "encounter") > 0 or count_events(ev, "abducted") > 0: break
