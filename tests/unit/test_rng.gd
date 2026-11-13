extends TestCase

func test_same_seed_same_sequence() -> void:
	var a := Rng.new(42); var b := Rng.new(42)
	for i in 100:
		assert_eq(a.randi_range(0, 1000000), b.randi_range(0, 1000000))

func test_state_resumes_sequence() -> void:
	var a := Rng.new(7)
	for i in 5: a.randf()
	var s: int = a.get_state()
	var first: Array = []
	for i in 10: first.append(a.randi_range(0, 999))
	a.set_state(s)
	var second: Array = []
	for i in 10: second.append(a.randi_range(0, 999))
	assert_eq(second, first)

func test_degenerate_range() -> void:
	assert_eq(Rng.new(1).randi_range(3, 3), 3)

func test_roll_bounds() -> void:
	var r := Rng.new(3)
	for i in 500:
		assert_between(r.roll(20), 1, 20)

func test_pick_and_weighted() -> void:
	var r := Rng.new(9)
	assert_null(r.pick([]))
	assert_eq(r.pick_weighted([]), {})
	var counts: Dictionary = {"a": 0, "b": 0}
	for i in 1000:
		counts[r.pick_weighted([{"id": "a", "weight": 9}, {"id": "b", "weight": 1}]).id] += 1
	assert_between(counts.a, 850, 950)
