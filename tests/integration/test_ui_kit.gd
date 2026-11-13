## UiKit builders return the right nodes, translate keys, and wire their signals.
extends TestCase

func test_theme_has_the_pixel_font() -> void:
	var t: Theme = UiKit.theme()
	assert_not_null(t.default_font)
	assert_true(t.default_font is FontFile, "bitmap font, not the fallback")
	assert_eq(t.default_font_size, UiKit.FONT_SIZE)
	assert_true(UiKit.font().has_char("ș".unicode_at(0)), "Romanian diacritics")
	assert_true(UiKit.font().has_char("…".unicode_at(0)))
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		assert_true(t.has_stylebox(s, "Button"), "Button " + s)

func test_builders_return_the_right_types() -> void:
	var nodes: Array[Node] = [UiKit.panel(), UiKit.button("menu_quit"), UiKit.label("title"),
		UiKit.bar(Color.RED), UiKit.choice_list(["opt_fight", "opt_flee"]), UiKit.toast_layer()]
	assert_true(nodes[0] is PanelContainer)
	assert_true(nodes[1] is Button)
	assert_true(nodes[2] is Label)
	assert_true(nodes[3] is ProgressBar)
	assert_true(nodes[4] is VBoxContainer)
	assert_true(nodes[5] is CanvasLayer)
	for n in nodes: n.free()

func test_button_and_label_translate_their_keys() -> void:
	var b: Button = UiKit.button("menu_quit")
	var l: Label = UiKit.label("title")
	assert_eq(b.text, tr("menu_quit"))
	assert_ne(b.text, "menu_quit")
	assert_eq(b.get_meta(&"text_key"), "menu_quit")
	assert_eq(l.text, "Dacian Scrolls")
	b.free(); l.free()

func test_choice_list_emits_chosen() -> void:
	var c: VBoxContainer = UiKit.choice_list(["opt_fight", "opt_flee", "opt_talk"])
	add_child(c)
	var got: Array[int] = []
	c.chosen.connect(func(i: int) -> void: got.append(i))
	assert_eq(c.get_child_count(), 3)
	(c.get_child(2) as Button).pressed.emit()
	(c.get_child(0) as Button).pressed.emit()
	assert_eq(got, [2, 0])
	assert_eq((c.get_child(1) as Button).text, tr("opt_flee"))
	c.free()

func test_toast_layer_shows_and_expires() -> void:
	var layer: CanvasLayer = UiKit.toast_layer()
	add_child(layer)
	Bus.toast.emit("party_full")
	Bus.emit_events([{"type": "toast", "text_key": "save_corrupt"}])
	assert_eq(layer.count(), 2, "stacked")
	var first: Label = layer.stack.get_child(0).get_child(0)
	assert_eq(first.text, tr("party_full"))
	for i in 6: Bus.toast.emit("party_full")
	await wait_frames(2)
	assert_between(layer.count(), 1, ToastLayer.MAX_SHOWN)
	layer.free()
