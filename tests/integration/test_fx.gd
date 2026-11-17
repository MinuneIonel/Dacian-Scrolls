## Gore and juice (WP-32): gore never changes the battle, and each gore level draws what it should.
extends TestCase

const SCENE: String = "res://src/modes/combat/combat.tscn"
const ViewTest := preload("res://tests/integration/test_combat_view.gd")

var view: Node2D
var bus_events: Array[Dictionary] = []
var _old_state: GameState
var _old_rng: Rng
var _old_save_fn: Callable
var _old_gore: int
var _last_counts: Dictionary = {}

func before_all() -> void:
	Content.reload("res://tests/fixtures/data")

func after_all() -> void:
	Content.reload("res://data")
	await get_tree().create_timer(0.2).timeout

func before_each() -> void:
	_old_state = Game.state
	_old_rng = Game.rng
	_old_save_fn = Router.save_fn
	_old_gore = Settings.gore
	Router.switch_scenes = false
	Router.save_fn = func(_slot: int) -> Error: return OK
	Router.current = &""
	Router.args = {}
	bus_events.clear()
	Bus.events_emitted.connect(_on_bus)

func after_each() -> void:
	Bus.events_emitted.disconnect(_on_bus)
	if view != null and is_instance_valid(view): view.free()
	view = null
	Engine.time_scale = 1.0
	Settings.gore = _old_gore
	Game.state = _old_state
	Game.rng = _old_rng
	Router.save_fn = _old_save_fn
	Router.switch_scenes = true
	Router.args = {}
	Router.current = &""

func _on_bus(events: Array[Dictionary]) -> void:
	bus_events.append_array(events)

## A real seeded battle, both sides on the deterministic fallback chooser; returns its events.
func _real_battle(enc: String, gore: int) -> Array[Dictionary]:
	Settings.gore = gore
	Game.new_game(11, &"fx_knight")
	bus_events.clear()
	Router.args = {"encounter_id": enc}
	view = load(SCENE).instantiate()
	view.ai_chooser = ViewTest.fallback_choose
	view.party_chooser = ViewTest.fallback_choose
	view.audio = false
	add_child(view)
	view.set_instant(true)
	for i in 3000:
		if view.returned: break
		await wait_frames(1)
	assert_true(view.returned, "%s finished at gore %d" % [enc, gore])
	var out: Array[Dictionary] = bus_events.duplicate(true)
	_last_counts = (view.fx.counts as Dictionary).duplicate()
	view.free()
	view = null
	return out

func _same_battle_at_gore_0_and_2(enc: String) -> Array:
	var a: Array[Dictionary] = await _real_battle(enc, 0)
	var at_0: Dictionary = _last_counts
	var b: Array[Dictionary] = await _real_battle(enc, 2)
	if count_events(a, "died") > 0:
		assert_eq(int(at_0.get("gib", 0)), 0, "no chunks at gore 0")
		assert_true(int(_last_counts.get("gib", 0)) > 0, "chunks flew at gore 2: %s" % _last_counts)
	assert_true(a.size() > 5, "the battle produced events")
	assert_eq(a.size(), b.size(), "same number of events")
	assert_eq(a, b, "identical event lists at gore 0 and gore 2")
	return [a, b]

func test_seeded_wolves_battle_identical_at_gore_0_and_2() -> void:
	var r: Array = await _same_battle_at_gore_0_and_2("fx_wolves")
	assert_true(count_events(r[0], "died") > 0, "someone died, so the gore paths ran")

func test_seeded_giant_battle_identical_at_gore_0_and_2() -> void:
	await _same_battle_at_gore_0_and_2("fx_saucer")

# ---- per-level nodes (stub battle, animated at 4x) ----------------------------------

func _death_events(gib: bool) -> Array[Dictionary]:
	var push: Array[Vector2i] = [Vector2i(5, 3)]
	return [
		{"type": "ability_used", "uid": 1, "ability": &"fx_zap", "cell": Vector2i(6, 2)},
		{"type": "damaged", "target": 2, "amount": 10, "crit": true, "shield_absorbed": 0},
		{"type": "died", "target": 2, "gib": gib, "corpse": false},
		{"type": "pushed", "target": 3, "path": push},
		{"type": "ability_used", "uid": 1, "ability": &"fx_heal", "cell": Vector2i(1, 2)},
		{"type": "healed", "target": 1, "amount": 2},
		{"type": "damaged", "target": 4, "amount": 40, "crit": false, "shield_absorbed": 0},
		{"type": "died", "target": 4, "gib": gib, "corpse": false},
		{"type": "damaged", "target": 1, "amount": 30, "crit": false, "shield_absorbed": 0},
		{"type": "died", "target": 1, "gib": false, "corpse": false},
		{"type": "turn_started", "uid": 1, "ap": 8}]

func _play_stub(gore: int, gib: bool, gravity: String = "normal") -> Node:
	Settings.gore = gore
	Game.new_game(7, &"fx_knight")
	var stub: ViewTest.StubBattle = ViewTest.StubBattle.new()
	stub.rules.gravity = gravity
	stub.legal = [{"type": "end_turn"}]
	stub.reply = _death_events(gib)
	view = load(SCENE).instantiate()
	view.battle = stub
	view.ai_chooser = ViewTest.fallback_choose
	view.audio = false
	add_child(view)
	view.set_fast(true)
	await _settle()
	view.submit({"type": "end_turn"})
	await wait_frames(2)
	await _settle()
	await wait_frames(30)   # flying chunks land
	return view.fx

func _settle(frames: int = 900) -> void:
	for i in frames:
		if (view.awaiting_input and not view.player.playing) or view.returned: return
		await wait_frames(1)

func _n(fx: Node, kind: String) -> int:
	return int(fx.counts.get(kind, 0))

func _decals(fx: Node) -> int:
	return (fx.decals as Node2D).get_child_count()

func test_gore_0_fades_with_dust_and_leaves_no_decals() -> void:
	var fx: Node = await _play_stub(0, true)
	assert_eq(fx.gore, 0)
	assert_eq(_n(fx, "dust"), 3, "wolf, giant and the downed hero puff dust")
	assert_eq(_n(fx, "splat"), 0)
	assert_eq(_n(fx, "gib"), 0, "gib flag ignored at gore 0")
	assert_eq(_decals(fx), 0)
	assert_eq(fx.shakes, 1, "only the crit shakes")
	assert_eq(fx.pauses, 1, "hit pause on the crit")
	assert_eq(fx.nudges, 1, "camera nudge on the push")
	assert_eq(Engine.time_scale, 1.0, "hit pause restored time")
	assert_eq(_n(fx, "zap"), 1, "tech ability zap")
	assert_eq(_n(fx, "glyph"), 1, "magic heal glyph")
	assert_eq(_n(fx, "heal"), 1, "heal sparkle")
	assert_null(view.unit_view(2), "wolf faded away")

func test_gore_1_splats_and_falls() -> void:
	var fx: Node = await _play_stub(1, false)
	assert_eq(_n(fx, "dust"), 0)
	assert_eq(_n(fx, "splat"), 4, "wolf 1, giant 2, downed hero 1")
	assert_eq(_n(fx, "gib"), 0)
	assert_eq(_n(fx, "balloon"), 0)
	assert_eq(_decals(fx), 4, "splats stay on the map")
	assert_true(view.unit_view(1).sprite.visible, "downed hero is still there")

func test_gore_1_with_gib_flag_makes_chunks() -> void:
	var fx: Node = await _play_stub(1, true)
	assert_eq(_n(fx, "gib"), 12, "6 chunks each for the wolf and the giant")
	assert_eq(_n(fx, "balloon"), 0, "giants only pop at gore 2")
	assert_eq(get_tree().get_nodes_in_group(&"fx_gib_flying").size(), 0, "every chunk landed")
	assert_eq(_decals(fx), _n(fx, "splat") + _n(fx, "gib"), "chunks and splats stay as decals")
	assert_true(fx.shakes >= 3, "crit + two bursts shake")

func test_gore_2_bursts_and_giant_pops_like_a_water_balloon() -> void:
	var fx: Node = await _play_stub(2, false)
	assert_eq(_n(fx, "balloon"), 1, "the 2x2 giant pops")
	assert_eq(_n(fx, "gib"), 6 + 8, "wolf chunks + giant chunks")
	assert_true(_n(fx, "splat") >= 10, "the giant coats the cells around it (%d)" % _n(fx, "splat"))
	assert_eq(_decals(fx), _n(fx, "splat") + _n(fx, "gib"))
	assert_true(fx.shakes >= 3)
	assert_eq(Engine.time_scale, 1.0)

func test_floaty_gravity_bobs_units() -> void:
	await _play_stub(0, false, "floaty")
	var wolf: Node2D = view.unit_view(3)
	var ys: Array[float] = []
	for i in 10:
		ys.append(wolf.sprite.position.y)
		await wait_frames(3)
	assert_true(ys.min() < -0.5, "lifted off the ground")
	assert_true(ys.max() - ys.min() > 0.3, "and bobbing")
	assert_eq(view.unit_view(1).sprite.position.y, 0.0, "downed units do not float")

func test_normal_gravity_does_not_bob() -> void:
	await _play_stub(0, false)
	await wait_frames(10)
	assert_eq(view.unit_view(3).sprite.position.y, 0.0)
