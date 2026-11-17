extends TestCase

var defs: Defs

func before_all() -> void:
	defs = ContentLoader.load_root("res://tests/fixtures/data")

func _grid(rows: Array) -> Grid:
	return Grid.from_map({"legend": {".": "grass", "#": "wall"}, "ground": rows}, defs.json("tiles"))

func test_straight_path() -> void:
	var g := _grid(["....", "....", "...."])
	var p: Array[Vector2i] = Pathfinder.path(g, Vector2i(0, 0), Vector2i(3, 0), 1)
	assert_eq(p, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])

func test_no_diagonal_steps() -> void:
	var g := _grid(["....", "....", "...."])
	var p: Array[Vector2i] = Pathfinder.path(g, Vector2i(0, 0), Vector2i(2, 2), 1)
	assert_eq(p.size(), 4)
	var prev := Vector2i(0, 0)
	for c in p:
		assert_eq(absi(c.x - prev.x) + absi(c.y - prev.y), 1)
		prev = c

func test_empty_when_same_or_unreachable() -> void:
	var g := _grid(["..#..", "..#..", "..#.."])
	assert_eq(Pathfinder.path(g, Vector2i(0, 0), Vector2i(0, 0), 1), [])
	assert_eq(Pathfinder.path(g, Vector2i(0, 0), Vector2i(4, 0), 1), [])
	assert_eq(Pathfinder.path(g, Vector2i(0, 0), Vector2i(2, 0), 1), [], "target is a wall")

func test_size_two_cannot_pass_one_cell_gap() -> void:
	var g := _grid([".....", ".....", "##.##", ".....", "....."])
	assert_eq(Pathfinder.path(g, Vector2i(0, 0), Vector2i(0, 3), 2), [])
	assert_eq(Pathfinder.path(g, Vector2i(0, 0), Vector2i(0, 3), 1).size(), 7)

func test_size_two_passes_two_cell_gap() -> void:
	var g := _grid([".....", ".....", "#..##", ".....", "....."])
	assert_ne(Pathfinder.path(g, Vector2i(0, 0), Vector2i(0, 3), 2), [])

func test_occupied_cells_block() -> void:
	var g := _grid(["...", "...", "..."])
	var occ: Dictionary = {Vector2i(1, 0): true, Vector2i(1, 1): true, Vector2i(1, 2): true}
	assert_eq(Pathfinder.path(g, Vector2i(0, 0), Vector2i(2, 0), 1, occ), [])
