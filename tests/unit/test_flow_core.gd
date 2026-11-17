## WP-30: core fixes from the wave-3 notes. items_used applied by Encounters.apply_battle_result,
## and the UFO grace period after a lost or fled UFO battle.
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
	rng = Rng.new(1)

func _result(outcome: String) -> Dictionary:
	return {"outcome": outcome, "reason": "", "loot": {}, "downed": [],
		"party_hp": {}, "party_mana": {}, "party_charge": {}}

func test_items_used_are_taken_from_the_inventory() -> void:
	s.inventory = {&"fx_bread": 3, &"fx_cell": 1}
	var res: Dictionary = _result("win")
	res["items_used"] = {&"fx_bread": 2, "fx_cell": 1}
	var ev: Array[Dictionary] = Encounters.apply_battle_result(&"fxw_bandits", res, s, rng, defs)
	assert_eq(s.inventory.get(&"fx_bread", 0), 1)
	assert_false(s.inventory.has(&"fx_cell"), "removed at 0")
	assert_eq(count_events(ev, "item_changed"), 2)
	assert_eq(ev[0].type, "item_changed", "items first")

func test_items_used_are_taken_on_a_loss_too() -> void:
	s.inventory = {&"fx_bread": 1}
	var res: Dictionary = _result("lose")
	res["items_used"] = {&"fx_bread": 1}
	Encounters.apply_battle_result(&"fxw_bandits", res, s, rng, defs)
	assert_false(s.inventory.has(&"fx_bread"))

func test_items_used_never_go_below_zero_and_missing_key_is_fine() -> void:
	s.inventory = {&"fx_bread": 1}
	var res: Dictionary = _result("fled")
	res["items_used"] = {&"fx_bread": 5}
	Encounters.apply_battle_result(&"fxw_bandits", res, s, rng, defs)
	assert_false(s.inventory.has(&"fx_bread"))
	s.inventory = {&"fx_bread": 1}
	Encounters.apply_battle_result(&"fxw_bandits", _result("win"), s, rng, defs)
	assert_eq(s.inventory[&"fx_bread"], 1)

func _ufo_battle(outcome: String) -> Array[Dictionary]:
	s.world_pos = Vector2i(3, 5)
	s.ufos.append({"id": &"fx_ufo", "pos": Vector2i(3, 5), "state": "chase", "route_i": 1})
	return Encounters.apply_battle_result(&"fx_saucer", _result(outcome), s, rng, defs)

func test_lost_ufo_battle_starts_a_grace_period() -> void:
	var ev: Array[Dictionary] = _ufo_battle("lose")
	assert_eq(s.ufos[0].state, "patrol")
	assert_eq(int(s.flags.get(Ufo.GRACE_FLAG, 0)), Ufo.GRACE_STEPS)
	assert_eq(find_event(ev, "flag_set").flag, Ufo.GRACE_FLAG)

func test_won_ufo_battle_has_no_grace() -> void:
	_ufo_battle("win")
	assert_false(s.flags.has(Ufo.GRACE_FLAG))

func test_no_respot_during_grace_then_spotted_again() -> void:
	_ufo_battle("fled")
	# Party stays on open plains right under the UFO: within the detect radius every tick.
	for i in Ufo.GRACE_STEPS:
		var ev: Array[Dictionary] = Ufo.tick(s, rng, defs)
		assert_eq(s.ufos[0].state, "patrol", "grace step %d" % i)
		assert_eq(count_events(ev, "abducted"), 0)
		s.world_pos = s.ufos[0].pos   # worst case: standing on the UFO
	assert_false(s.flags.has(Ufo.GRACE_FLAG), "grace used up and cleared")
	Ufo.tick(s, rng, defs)
	assert_eq(s.ufos[0].state, "chase", "visible again after the grace period")

func test_grace_survives_a_save_round_trip() -> void:
	_ufo_battle("lose")
	var back: Dictionary = SaveCodec.decode(SaveCodec.encode(s))
	assert_true(back.ok)
	var s2: GameState = back.state
	Ufo.tick(s2, rng, defs)
	assert_eq(int(s2.flags.get(Ufo.GRACE_FLAG, 0)), Ufo.GRACE_STEPS - 1)
