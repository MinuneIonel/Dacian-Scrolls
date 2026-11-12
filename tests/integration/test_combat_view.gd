## Combat view: it only plays back events (stub battle) and drives a real battle to the end
## (fixtures, deterministic fallback chooser on both sides) without engine errors.
extends TestCase

const SCENE: String = "res://src/modes/combat/combat.tscn"

## A Battle look-alike: fixed units, fixed events, records what the view sent.
class StubBattle extends RefCounted:
	var encounter_id: StringName = &"fx_wolves"
	var rules: Dictionary = {"magic_disabled": false, "gravity": "normal", "turn_limit": 0}
	var round: int = 1
	var grid: Grid = Grid.new(Vector2i(8, 7))
	var inventory: Dictionary = {}
	var applied: Array[Dictionary] = []
	var reply: Array[Dictionary] = []
	var legal: Array[Dictionary] = []
	var over_after_apply: bool = false
	var fixed_result: Dictionary = {}
	var _units: Array[Dictionary] = [
		{"uid": 1, "side": "party", "def_id": &"fx_knight", "char_id": &"hero", "cell": Vector2i(1, 2), "size": 1,
			"hp": 30, "max_hp": 30, "ap": 8, "mana": 4, "max_mana": 4, "charge": 4, "max_charge": 4,
			"abilities": [&"fx_strike", &"fx_ward", &"fx_zap"], "statuses": {}, "summoned": false, "downed": false},
		{"uid": 2, "side": "enemy", "def_id": &"fx_wolf", "char_id": &"", "cell": Vector2i(6, 2), "size": 1,
			"hp": 10, "max_hp": 10, "ap": 0, "abilities": [&"fx_strike"], "statuses": {}, "summoned": false},
		{"uid": 3, "side": "enemy", "def_id": &"fx_wolf", "char_id": &"", "cell": Vector2i(6, 4), "size": 1,
			"hp": 10, "max_hp": 10, "ap": 0, "abilities": [&"fx_strike"], "statuses": {}, "summoned": false},
		{"uid": 4, "side": "enemy", "def_id": &"fx_giant", "char_id": &"", "cell": Vector2i(3, 4), "size": 2,
			"hp": 40, "max_hp": 40, "ap": 0, "abilities": [&"fx_strike"], "statuses": {}, "summoned": false}]
	var _over: bool = false

	func units() -> Array[Dictionary]: return _units.duplicate(true)
	func unit(uid: int) -> Dictionary:
		for u in _units:
			if u.uid == uid: return u.duplicate(true)
		return {}
	func start() -> Array[Dictionary]:
		return [{"type": "battle_started", "round": 1}, {"type": "turn_started", "uid": 1, "ap": 8}]
	func current_unit() -> int: return -1 if _over else 1
	func is_ai(_uid: int) -> bool: return false
	func is_over() -> bool: return _over
	func legal_actions(_uid: int) -> Array[Dictionary]: return legal
	func apply(action: Dictionary) -> Array[Dictionary]:
		applied.append(action)
		if over_after_apply: _over = true
		return reply
	func result() -> Dictionary: return fixed_result
	func hazards() -> Array[Dictionary]: return []
	func corpses() -> Array[Dictionary]: return []
	func turn_order() -> Array[int]: return [1, 2, 3, 4]
	func hit_chance(_a: int, _t: int, _ab: StringName) -> int: return 75
	func are_allies(a: int, b: int) -> bool: return (a == 1) == (b == 1)
	func unit_at(c: Vector2i) -> int:
		for u in _units:
			var s: int = u.size
			if c.x >= u.cell.x and c.y >= u.cell.y and c.x < u.cell.x + s and c.y < u.cell.y + s: return u.uid
		return -1

var view: Node2D
var bus_events: Array[Dictionary] = []
var _old_state: GameState
var _old_rng: Rng
var _old_save_fn: Callable

func before_all() -> void:
	Content.reload("res://tests/fixtures/data")

func after_all() -> void:
	Content.reload("res://data")
	Audio.stop_music(0.0)
	await get_tree().create_timer(0.3).timeout

func before_each() -> void:
	_old_state = Game.state
	_old_rng = Game.rng
	_old_save_fn = Router.save_fn
	Router.switch_scenes = false
	Router.save_fn = func(_slot: int) -> Error: return OK
	Router.current = &""
	Router.args = {}
	Game.new_game(7, &"fx_knight")
	bus_events.clear()
	Bus.events_emitted.connect(_on_bus)

func after_each() -> void:
	Bus.events_emitted.disconnect(_on_bus)
	if view != null and is_instance_valid(view): view.free()
	view = null
	Game.state = _old_state
	Game.rng = _old_rng
	Router.save_fn = _old_save_fn
	Router.switch_scenes = true
	Router.args = {}
	Router.current = &""

func _on_bus(events: Array[Dictionary]) -> void:
	bus_events.append_array(events)

func _open(stub: Object, instant: bool = true) -> void:
	view = load(SCENE).instantiate()
	if stub != null: view.battle = stub
	view.ai_chooser = fallback_choose
	view.audio = false
	add_child(view)
	view.set_instant(instant)

## Waits until a party turn waits for input, or the view returned, or `frames` pass.
func _settle(frames: int = 600) -> void:
	for i in frames:
		if (view.awaiting_input and not view.player.playing) or view.returned: return
		await wait_frames(1)

## Deterministic chooser for tests: first legal ability on a hostile, else the move that gets
## closest to the nearest hostile (only if it gets closer), else end_turn.
static func fallback_choose(b: Object, uid: int, _rng: Rng) -> Dictionary:
	var legal: Array = b.legal_actions(uid)
	for a in legal:
		if a.type == "ability":
			var t: int = b.unit_at(a.cell)
			if t >= 0 and not b.are_allies(uid, t): return a
	var me: Dictionary = b.unit(uid)
	var foes: Array[Vector2i] = []
	for u in b.units():
		if not b.are_allies(uid, u.uid) and not u.get("downed", false): foes.append(u.cell)
	var best: Dictionary = {"type": "end_turn"}
	var best_d: int = _nearest(me.cell, foes)
	for a in legal:
		if a.type != "move": continue
		var d: int = _nearest(a.path[-1], foes)
		if d < best_d:
			best_d = d
			best = a
	return best

static func _nearest(c: Vector2i, foes: Array[Vector2i]) -> int:
	var best: int = 1 << 20
	for f in foes: best = mini(best, absi(f.x - c.x) + absi(f.y - c.y))
	return best

func _fixed_events() -> Array[Dictionary]:
	var path: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]
	var push: Array[Vector2i] = [Vector2i(7, 2)]
	return [
		{"type": "moved", "uid": 1, "path": path},
		{"type": "ability_used", "uid": 1, "ability": &"fx_strike", "cell": Vector2i(6, 2)},
		{"type": "damaged", "target": 2, "amount": 4, "crit": false, "shield_absorbed": 0},
		{"type": "missed", "uid": 1, "target": 4},
		{"type": "damaged", "target": 3, "amount": 10, "crit": true, "shield_absorbed": 0},
		{"type": "died", "target": 3, "gib": false, "corpse": true},
		{"type": "pushed", "target": 2, "path": push},
		{"type": "status", "target": 2, "status": "slowed", "turns": 2},
		{"type": "damaged", "target": 1, "amount": 7, "crit": false, "shield_absorbed": 2},
		{"type": "healed", "target": 1, "amount": 3},
		{"type": "hazard", "cell": Vector2i(4, 1), "hazard": "acid", "turns": 2},
		{"type": "turn_started", "uid": 1, "ap": 8}]

func _check_end_positions() -> void:
	var hero: Node2D = view.unit_view(1)
	assert_eq(hero.cell, Vector2i(5, 2), "hero walked the path")
	assert_eq(hero.position, Iso.footprint_center(Vector2i(5, 2), 1))
	assert_eq(hero.hp, 26, "30 - 7 + 3")
	var wolf: Node2D = view.unit_view(2)
	assert_eq(wolf.cell, Vector2i(7, 2), "pushed")
	assert_eq(wolf.hp, 6)
	assert_almost_eq(wolf.hp_ratio(), 0.6)
	assert_has(wolf.statuses, "slowed")
	var dead: Node2D = view.unit_view(3)
	assert_not_null(dead, "a corpse stays on the map")
	assert_true(dead.is_corpse)
	assert_eq(dead.hp, 0)
	assert_eq(view.unit_view(4).hp, 40, "the miss did nothing")
	assert_eq(view.unit_view(4).size, 2)
	assert_true(view.overlay.has_hazard(Vector2i(4, 1), "acid"))

func test_plays_stub_events_in_order_instant() -> void:
	var stub := StubBattle.new()
	stub.legal = [{"type": "end_turn"}]
	stub.reply = _fixed_events()
	await _open(stub)
	await _settle()
	assert_true(view.awaiting_input, "party turn waits for input")
	view.submit({"type": "end_turn"})
	await wait_frames(2)
	await _settle()
	assert_eq(stub.applied.size(), 1)
	_check_end_positions()
	assert_has(bus_events.map(func(e: Dictionary) -> String: return e.type), "moved", "events reach Bus")

func test_plays_stub_events_animated_at_4x() -> void:
	var stub := StubBattle.new()
	stub.legal = [{"type": "end_turn"}]
	stub.reply = _fixed_events()
	await _open(stub, false)
	view.set_fast(true)
	assert_eq(view.player.speed, 4.0)
	await _settle(900)
	view.submit({"type": "end_turn"})
	await wait_frames(2)
	await _settle(900)
	assert_false(view.player.playing)
	_check_end_positions()

func test_click_moves_and_attacks_through_legal_actions() -> void:
	var stub := StubBattle.new()
	var path: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2)]
	stub.legal = [{"type": "end_turn"}, {"type": "move", "path": path},
		{"type": "ability", "ability": &"fx_strike", "cell": Vector2i(4, 4)}]
	await _open(stub)
	await _settle()
	assert_true(view.overlay.move_cells.has(Vector2i(3, 2)), "reachable cell highlighted")
	view.click_cell(Vector2i(0, 0))
	assert_eq(stub.applied.size(), 0, "clicks outside legal cells do nothing")
	view.click_cell(Vector2i(3, 2))
	await wait_frames(2)
	assert_eq(stub.applied[0].type, "move")
	assert_eq(stub.applied[0].path, path)
	await _settle()
	# Select ability 1 (the basic attack) and click the 2x2 giant on its far cell.
	view.select_button(0)
	assert_true(view.overlay.target_cells.has(Vector2i(4, 4)))
	view.click_cell(Vector2i(3, 5))
	await wait_frames(2)
	assert_eq(stub.applied.size(), 2)
	assert_eq(stub.applied[1], {"type": "ability", "ability": &"fx_strike", "cell": Vector2i(4, 4)})

func test_magic_greyed_out_when_magic_disabled() -> void:
	var stub := StubBattle.new()
	stub.rules.magic_disabled = true
	stub.legal = [{"type": "end_turn"}, {"type": "ability", "ability": &"fx_strike", "cell": Vector2i(6, 2)}]
	await _open(stub)
	await _settle()
	var btns: Array = view.hud.ability_buttons
	assert_true(btns[0].visible and not btns[0].disabled, "steel basic attack usable")
	assert_true(btns[1].disabled, "fx_ward is magic")
	assert_eq(btns[1].tooltip_text, tr("zalmoxis_cant_hear_you"))
	assert_true(btns[2].disabled, "zap has no legal target")
	assert_ne(btns[2].tooltip_text, tr("zalmoxis_cant_hear_you"))
	assert_true(view.hud.flee_button.disabled, "flee not in legal actions")

func test_battle_end_applies_result_and_returns() -> void:
	var stub := StubBattle.new()
	stub.legal = [{"type": "end_turn"}]
	stub.over_after_apply = true
	stub.reply = [{"type": "died", "target": 2, "gib": true, "corpse": false},
		{"type": "battle_ended", "outcome": "win", "reason": "enemies_defeated"}]
	stub.fixed_result = {"outcome": "win", "reason": "enemies_defeated", "loot": {"fx_bread": 2}, "downed": [],
		"party_hp": {"hero": 12}, "party_mana": {"hero": 1}, "party_charge": {"hero": 0}, "items_used": {}}
	Router.args = {"encounter_id": "fx_wolves", "return_mode": "location", "return_args": {"location_id": "fx_town"}}
	await _open(stub)
	var died: Array = []
	view.player.unit_died.connect(func(uid: int, gib: bool, _c: bool, _v: Node2D) -> void: died.append([uid, gib]))
	await _settle()
	view.submit({"type": "end_turn"})
	await _settle()
	assert_true(view.returned)
	assert_eq(died, [[2, true]], "gore hook fired")
	assert_eq(Router.current, &"location")
	assert_eq(Router.args, {"location_id": "fx_town"})
	assert_eq(Game.state.party[0].hp, 12)
	assert_eq(int(Game.state.inventory.get(&"fx_bread", 0)), 2)
	assert_eq(Game.state.flags.get("won_fx_wolves"), true)
	assert_true(view.hud.result_panel.visible)
	assert_has(bus_events.map(func(e: Dictionary) -> String: return e.type), "xp_gained")

func _real_battle(enc: String) -> void:
	Router.args = {"encounter_id": enc}
	view = load(SCENE).instantiate()
	view.ai_chooser = fallback_choose
	view.audio = false
	view.party_chooser = fallback_choose
	add_child(view)
	view.set_instant(true)
	for i in 3000:
		if view.returned: break
		await wait_frames(1)

func test_smoke_real_battle_wolves_to_return() -> void:
	await _real_battle("fx_wolves")
	assert_true(view.returned, "battle finished and returned")
	assert_eq(Router.current, &"worldmap", "default return mode")
	assert_has(["win", "lose", "fled"], view.result.get("outcome", ""))
	assert_true(count_events(bus_events, "damaged") > 0, "units actually fought")
	assert_true(count_events(bus_events, "moved") > 0, "and walked")

func test_smoke_real_battle_saucer_giant() -> void:
	await _real_battle("fx_saucer")
	assert_true(view.returned)
	assert_eq(Router.current, &"worldmap")
	assert_has(["win", "lose"], view.result.get("outcome", ""))
	assert_true(count_events(bus_events, "timer") > 0, "turn limit counted down")
