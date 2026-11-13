extends TestCase

var defs: Defs

func before_all() -> void:
	defs = ContentLoader.load_root("res://tests/fixtures/data")

func _grid(rows: Array) -> Grid:
	return Grid.from_map({"legend": {".": "grass", "#": "wall", "c": "crate"}, "ground": rows}, defs.json("tiles"))

func test_from_map_reads_tiles() -> void:
	var g := Grid.from_map(defs.get_def(&"map", &"fx_arena"), defs.json("tiles"))
	assert_eq(g.size, Vector2i(8, 7))
	assert_false(g.is_walkable(Vector2i(0, 0)))
	assert_true(g.is_walkable(Vector2i(1, 1)))
	assert_false(g.is_walkable(Vector2i(3, 2)), "crate")
	assert_eq(g.cover_at(Vector2i(3, 2)), 20)
	assert_eq(g.cover_at(Vector2i(0, 0)), 40)
	assert_false(g.is_walkable(Vector2i(4, 4)), "water")

func test_fits_size_two() -> void:
	var g := _grid(["....", "..#.", "...."])
	assert_true(g.fits(Vector2i(0, 0), 2))
	assert_false(g.fits(Vector2i(1, 0), 2), "wall in footprint")
	assert_false(g.fits(Vector2i(3, 0), 2), "out of bounds")
	assert_false(g.fits(Vector2i(0, 0), 2, {Vector2i(1, 1): true}), "occupied")
	assert_true(g.fits(Vector2i(0, 0), 1, {Vector2i(1, 1): true}))

func test_reachable_costs_and_no_diagonals() -> void:
	var g := _grid(["....", "....", "...."])
	var r: Dictionary = g.reachable(Vector2i(0, 0), 2, 1)
	assert_eq(r[Vector2i(0, 0)], 0)
	assert_eq(r[Vector2i(1, 1)], 2, "diagonal costs two steps")
	assert_eq(r[Vector2i(2, 0)], 2)
	assert_not_has(r, Vector2i(2, 1))
	assert_eq(r.size(), 6)

func test_reachable_cost_per_cell() -> void:
	var g := _grid(["....", "....", "...."])
	var r: Dictionary = g.reachable(Vector2i(0, 0), 6, 1, {}, 2)
	assert_eq(r[Vector2i(3, 0)], 6)
	assert_not_has(r, Vector2i(3, 1))

func test_occupied_blocks() -> void:
	var g := _grid(["...", "...", "..."])
	var occ: Dictionary = {Vector2i(1, 0): true, Vector2i(1, 1): true}
	var r: Dictionary = g.reachable(Vector2i(0, 0), 3, 1, occ)
	assert_not_has(r, Vector2i(1, 0))
	assert_not_has(r, Vector2i(2, 0))
	assert_has(r, Vector2i(1, 2))

func test_walled_in_reaches_only_itself() -> void:
	var g := _grid(["###", "#.#", "###"])
	var r: Dictionary = g.reachable(Vector2i(1, 1), 8, 1)
	assert_eq(r, {Vector2i(1, 1): 0})
