extends TestCase

func test_ground_tiles_are_diamonds() -> void:
	for id in ["tile_grass", "tile_road", "tile_forest_floor", "tile_stone"]:
		assert_true(Assets.has_tex(StringName(id)), id)
		assert_eq(Assets.tex(StringName(id)).get_size(), Vector2(64, 32), id)

func test_wall_is_tall() -> void:
	var t: Texture2D = Assets.tex(&"tile_wall")
	assert_eq(t.get_width(), 64)
	assert_true(t.get_height() > 32)

func test_sprites_have_every_anim_in_both_facings() -> void:
	for id in ["knight", "grazi_thrall", "giant_legs"]:
		var sf: SpriteFrames = Assets.frames(StringName(id))
		for a in ["idle", "walk", "attack", "hit", "death"]:
			assert_true(sf.has_animation(a), "%s %s" % [id, a])
			assert_true(sf.has_animation(a + "_ne"), "%s %s_ne" % [id, a])
		assert_eq(sf.get_frame_count(&"walk"), 4, id)

func test_frame_sizes() -> void:
	assert_eq(Assets.frames(&"knight").get_frame_texture(&"idle", 0).get_size(), Vector2(32, 48))
	assert_eq(Assets.frames(&"giant_legs").get_frame_texture(&"idle", 0).get_size(), Vector2(128, 192))
