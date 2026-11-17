extends TestCase

func test_ap() -> void:
	assert_eq(Formulas.ap_for(4), 8)
	assert_eq(Formulas.ap_for(5), 8)
	assert_eq(Formulas.ap_for(0), 6)

func test_hit_chance_exact() -> void:
	assert_eq(Formulas.hit_chance(6, 4, 20, false), 65)
	assert_eq(Formulas.hit_chance(6, 4, 20, true), 80)

func test_hit_chance_clamps() -> void:
	assert_eq(Formulas.hit_chance(20, 0, 0, true), 95)
	assert_eq(Formulas.hit_chance(0, 20, 40, false), 5)

func test_damage_exact() -> void:
	assert_eq(Formulas.damage(6, 5, 1.0, 3), 8)
	assert_eq(Formulas.damage(1, 0, 1.0, 9), 1)
	assert_eq(Formulas.damage(6, 5, 0.5, 0), 8)  # floor(8.5)

func test_initiative_range() -> void:
	var r := Rng.new(5)
	for i in 100:
		assert_between(Formulas.initiative(3, r), 4, 9)

func test_roll_hits() -> void:
	assert_true(Formulas.roll_hits(2, 95))
	assert_false(Formulas.roll_hits(1, 95))
	assert_true(Formulas.roll_hits(20, 5))
	assert_false(Formulas.roll_hits(19, 5))
	assert_true(Formulas.roll_hits(8, 65))   # 8*5=40 > 35
	assert_false(Formulas.roll_hits(7, 65))

func test_gib() -> void:
	assert_true(Formulas.is_gib(true, 0, 10))
	assert_true(Formulas.is_gib(false, 5, 10))
	assert_false(Formulas.is_gib(false, 4, 10))

func test_xp_to_next_untouched() -> void:
	assert_eq(Formulas.xp_to_next(2), 240)
