extends TestCase

func test_projection_round_trip() -> void:
	for y in 20:
		for x in 20:
			var c := Vector2i(x, y)
			assert_eq(Iso.world_to_cell(Iso.cell_to_world(c)), c)

func test_known_points() -> void:
	assert_eq(Iso.cell_to_world(Vector2i(0, 0)), Vector2(0, 0))
	assert_eq(Iso.cell_to_world(Vector2i(1, 0)), Vector2(32, 16))
	assert_eq(Iso.cell_to_world(Vector2i(0, 1)), Vector2(-32, 16))
	assert_eq(Iso.facing(Vector2i(0, 0), Vector2i(1, 0)), "se")
	assert_eq(Iso.facing(Vector2i(0, 0), Vector2i(0, -1)), "ne")

func test_build_every_real_map() -> void:
	for m in Content.all(&"map"):
		var node: Node2D = MapBuilder.build(StringName(m.id), Content.defs)
		var size: Vector2i = node.get_meta("size")
		assert_eq(node.get_node("Ground").get_child_count() > 0, true, m.id)
		assert_true(node.get_meta("grid") is Grid, m.id)
		assert_true(size.x > 0 and size.y > 0, m.id)
		node.free()

func test_unit_sprite_flips_and_plays() -> void:
	var u := UnitSprite.new(&"knight", 1)
	add_child(u)
	u.face("sw")
	assert_true(u.animated_sprite().flip_h)
	u.face("ne")
	assert_false(u.animated_sprite().flip_h)
	assert_eq(String(u.current_animation()), "idle_ne")
	u.play(&"walk")
	assert_eq(String(u.current_animation()), "walk_ne")
	u.queue_free()
