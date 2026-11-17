extends TestCase

const FIXTURES: String = "res://tests/fixtures/data"

func test_unknown_def_is_empty_not_a_crash() -> void:
	expect_errors(1)
	assert_eq(Content.get_def(&"ability", &"nope_does_not_exist"), {})

func test_unknown_texture_is_placeholder() -> void:
	var t: Texture2D = Assets.tex(&"nope_does_not_exist")
	assert_not_null(t)
	assert_eq(t.get_size(), Vector2(32, 32))

func test_unknown_frames_have_standard_anims() -> void:
	var sf: SpriteFrames = Assets.frames(&"nope_does_not_exist")
	for a in ["idle", "walk", "attack", "hit", "death"]:
		assert_true(sf.has_animation(a), a)

func test_fixture_root_loads_every_kind() -> void:
	var defs: Defs = ContentLoader.load_root(FIXTURES)
	for kind in Defs.KINDS:
		assert_true(defs.all(kind).size() > 0, "fixtures have a %s" % kind)
	assert_true(defs.json("world") is Dictionary and not defs.json("world").is_empty())
	assert_true(defs.json("tiles") is Dictionary and not defs.json("tiles").is_empty())
	assert_true(defs.json("fanfi") is Dictionary)

func test_defs_all_sorted_by_id() -> void:
	var d := Defs.new()
	d.add(&"item", {"id": "zz"}); d.add(&"item", {"id": "aa"})
	assert_eq(d.all(&"item").map(func(x): return x.id), ["aa", "zz"])

func test_strings_load() -> void:
	assert_eq(tr("title"), "Dacian Scrolls")
