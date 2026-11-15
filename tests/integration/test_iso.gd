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

## A prop that sticks up (barrel) gets its upper part y-sorted; flat and walkable tiles do not.
func test_prop_top_is_sorted_above_the_centre_line() -> void:
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(Image.create(64, 58, false, Image.FORMAT_RGBA8))
	s.offset = Vector2(-32, -42)
	var top: Sprite2D = MapBuilder._prop_top(s, {"walkable": false})
	assert_not_null(top)
	assert_eq(top.region_rect, Rect2(0, 0, 64, 42))
	assert_eq(top.offset, s.offset)
	assert_null(MapBuilder._prop_top(s, {"walkable": true}))
	var flat := Sprite2D.new()
	flat.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	assert_null(MapBuilder._prop_top(flat, {"walkable": false}))
	top.free(); s.free(); flat.free()
