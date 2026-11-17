## WP-13: Fog.reveal / is_revealed.
extends TestCase

const SIZE := Vector2i(12, 8)

var s: GameState

func before_each() -> void:
	s = GameState.new()

func test_reveal_square_of_radius_two() -> void:
	var got: Array[Vector2i] = Fog.reveal(s, Vector2i(5, 4), 2, SIZE)
	assert_eq(got.size(), 25)
	assert_eq(s.revealed.size(), 25)
	assert_true(Fog.is_revealed(s, Vector2i(3, 2)))
	assert_true(Fog.is_revealed(s, Vector2i(7, 6)))
	assert_false(Fog.is_revealed(s, Vector2i(8, 4)))
	assert_false(Fog.is_revealed(s, Vector2i(5, 7)))

func test_clipped_at_edge_and_only_new_cells() -> void:
	assert_eq(Fog.reveal(s, Vector2i(0, 0), 2, SIZE).size(), 9)
	var again: Array[Vector2i] = Fog.reveal(s, Vector2i(1, 0), 2, SIZE)
	assert_eq(again, [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)] as Array[Vector2i])
	assert_eq(Fog.reveal(s, Vector2i(1, 0), 2, SIZE).size(), 0)
	assert_eq(Fog.reveal(s, Vector2i(11, 7), 1, SIZE).size(), 4)

func test_radius_zero_and_outside() -> void:
	assert_eq(Fog.reveal(s, Vector2i(4, 4), 0, SIZE), [Vector2i(4, 4)] as Array[Vector2i])
	assert_eq(Fog.reveal(s, Vector2i(40, 40), 2, SIZE).size(), 0)
	assert_true(s.revealed.has("4,4"))
