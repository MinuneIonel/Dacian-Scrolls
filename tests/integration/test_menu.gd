## The title screen builds headless without engine errors and behaves with keyboard input.
## Never presses Begin or Continue: Game.new_game/load_slot belong to WP-10.
extends TestCase

const SAVE_DIR: String = "user://test_menu_saves"
const SETTINGS_PATH: String = "user://test_menu_settings.json"
var menu: Control
var _saved_settings: Dictionary

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_clear_dir()
	Game.save_dir_override = SAVE_DIR
	_saved_settings = Settings.to_dict()
	Settings.path = SETTINGS_PATH
	Router.args = {}

func after_each() -> void:
	if menu != null and is_instance_valid(menu): menu.free()
	menu = null
	_clear_dir()
	Game.save_dir_override = ""
	if FileAccess.file_exists(SETTINGS_PATH): DirAccess.remove_absolute(SETTINGS_PATH)
	Settings.path = Settings.PATH
	Settings.gore = _saved_settings.gore; Settings.music_volume = _saved_settings.music_volume
	Settings.sfx_volume = _saved_settings.sfx_volume; Settings.fullscreen = _saved_settings.fullscreen
	Router.args = {}

func _clear_dir() -> void:
	for f in DirAccess.get_files_at(SAVE_DIR): DirAccess.remove_absolute(SAVE_DIR.path_join(f))

func _open(args: Dictionary = {}) -> void:
	Router.args = args
	menu = load("res://src/modes/menu/menu.tscn").instantiate()
	add_child(menu)
	await wait_frames(2)

func _press(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)

func test_builds_with_continue_disabled_without_a_save() -> void:
	await _open()
	assert_eq(menu.screen, &"main")
	assert_true(menu.btn_continue.disabled)
	assert_false(menu.btn_new.disabled)
	assert_eq(menu.btn_new.text, tr("menu_new_game"))
	assert_true(menu.btn_new.has_focus(), "keyboard focus starts on New Game")

func test_continue_enabled_and_focused_with_a_save() -> void:
	var f := FileAccess.open(Game.save_path(0), FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	await _open()
	assert_false(menu.btn_continue.disabled)
	assert_true(menu.btn_continue.has_focus())

func test_new_game_screen_picks_a_class() -> void:
	await _open()
	menu.btn_new.pressed.emit()
	await wait_frames(1)
	assert_eq(menu.screen, &"new")
	assert_eq(menu.hero_class, &"knight")
	menu.class_buttons[1].pressed.emit()
	assert_eq(menu.hero_class, &"necromancer")
	assert_true(menu.class_buttons[1].button_pressed)
	assert_false(menu.class_buttons[0].button_pressed)

func test_seed_parsing() -> void:
	await _open()
	assert_eq(menu.parse_seed(" 1234 "), 1234)
	assert_eq(menu.parse_seed("lobizi"), hash("lobizi"))
	assert_eq(menu.parse_seed("lobizi"), menu.parse_seed("lobizi"))

func test_settings_change_and_save_on_back() -> void:
	await _open({"screen": "settings"})
	assert_eq(menu.screen, &"settings")
	Settings.gore = 1
	menu._sync_settings()
	menu.gore_button.pressed.emit()
	assert_eq(Settings.gore, 2)
	assert_has(menu.gore_button.text, tr("settings_gore_bloody"))
	menu.music_slider.value = 0.3
	assert_almost_eq(Settings.music_volume, 0.3)
	menu.fullscreen_box.button_pressed = true
	assert_true(Settings.fullscreen)
	menu.fullscreen_box.button_pressed = false
	menu._back()
	assert_eq(menu.screen, &"main")
	Settings.reset_defaults()
	Settings.load_settings()
	assert_eq(Settings.gore, 2, "saved on leaving settings")
	assert_almost_eq(Settings.music_volume, 0.3)

func test_escape_returns_to_main() -> void:
	await _open({"screen": "new"})
	_press(&"ui_cancel")
	await wait_frames(2)
	assert_eq(menu.screen, &"main")

func test_keyboard_moves_focus_down_the_main_menu() -> void:
	await _open()
	_press(&"ui_down")
	await wait_frames(2)
	assert_true(menu.btn_settings.has_focus(), "disabled Continue is skipped")
	_press(&"ui_up")
	await wait_frames(2)
	assert_true(menu.btn_new.has_focus())
	_press(&"ui_up")
	await wait_frames(2)
	assert_true(menu.btn_quit.has_focus(), "wraps around")
