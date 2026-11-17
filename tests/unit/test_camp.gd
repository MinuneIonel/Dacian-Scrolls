## Healing outside battle: the "heal" effect (herbs on the map) and Travel.camp.
extends TestCase

var defs: Defs

func before_all() -> void:
	defs = ContentLoader.load_root("res://tests/fixtures/data")

func _state(members: int) -> GameState:
	var st := GameState.new()
	for i in members:
		var id: StringName = &"hero" if i == 0 else StringName("fx_m%d" % i)
		st.party.append(Character.create(id, defs.get_def(&"class", &"fx_knight"), "hero_name"))
	st.food = 12
	st.day = 1
	st.hour = 8
	return st

func test_heal_effect_caps_at_max() -> void:
	var s := _state(2)
	s.party[0].hp = 3
	s.party[1].hp = s.party[1].max_hp - 1
	var ev := Rules.run([["heal", 10]], s, Rng.new(1), defs)
	assert_eq(s.party[0].hp, 13)
	assert_eq(s.party[1].hp, s.party[1].max_hp)
	assert_eq(find_event(ev, "party_healed").get("total"), 11)

func test_camp_heals_half_restores_mana_costs_food_and_time() -> void:
	var s := _state(2)
	var m: Character = s.party[0]
	m.hp = 2
	m.mana = 0
	var ev := Travel.camp(s)
	assert_eq(m.hp, mini(m.max_hp, 2 + m.max_hp * Travel.CAMP_HEAL_PCT / 100))
	assert_eq(m.mana, m.max_mana)
	assert_eq(s.food, 10)
	assert_eq(s.hour, 8 + Travel.CAMP_HOURS)
	assert_not_null(find_event(ev, "camped").get("hours"))

func test_camp_overnight_also_eats_the_midnight_meal() -> void:
	var s := _state(1)
	s.hour = 20
	Travel.camp(s)
	assert_eq(s.day, 2)
	assert_eq(s.hour, 4)
	assert_eq(s.food, 10, "1 for camp, 1 at midnight")

func test_camp_blocked_without_food() -> void:
	var s := _state(3)
	s.food = 2
	s.party[0].hp = 1
	assert_eq(Travel.camp_blocker(s), "camp_no_food")
	assert_eq(Travel.camp(s).size(), 0)
	assert_eq(s.party[0].hp, 1)
	assert_eq(s.hour, 8)

func test_camp_blocked_while_a_ufo_chases() -> void:
	var s := _state(1)
	s.ufos = [{"id": &"u1", "def": &"x", "pos": Vector2i(1, 1), "state": "chase"}]
	assert_eq(Travel.camp_blocker(s), "camp_ufo_near")
	s.ufos[0].state = "patrol"
	assert_eq(Travel.camp_blocker(s), "")
