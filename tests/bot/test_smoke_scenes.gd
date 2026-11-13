## Every mode scene loads headless on the real data, runs 60 frames, and logs no engine error
## (the runner fails a test on any). Scene switching, autosave and Flow overlays are off; saves
## and settings go to a scratch folder so nothing of the player's is touched.
extends TestCase

const FRAMES: int = 60
const SAVE_DIR: String = "user://test_bot_smoke"
const SETTINGS_PATH: String = "user://test_bot_smoke_settings.json"

var view: Node
var _settings: Dictionary

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	Game.save_dir_override = SAVE_DIR
	_settings = Settings.to_dict()
	Settings.path = SETTINGS_PATH
	Router.switch_scenes = false
	Router.autosave_enabled = false
	Router.current = &""
	Flow.overlays_enabled = false
	Game.new_game(101, &"necromancer")
	Rules.run([["recruit", "vezina"]], Game.state, Game.rng, Content.defs)

func after_each() -> void:
	if view != null and is_instance_valid(view): view.free()
	view = null
	await wait_frames(2)
	for f in DirAccess.get_files_at(SAVE_DIR): DirAccess.remove_absolute(SAVE_DIR.path_join(f))
	Game.save_dir_override = ""
	if FileAccess.file_exists(SETTINGS_PATH): DirAccess.remove_absolute(SETTINGS_PATH)
	Settings.path = Settings.PATH
	Settings.gore = _settings.gore; Settings.music_volume = _settings.music_volume
	Settings.sfx_volume = _settings.sfx_volume; Settings.fullscreen = _settings.fullscreen
	Router.switch_scenes = true
	Router.autosave_enabled = true
	Router.args = {}
	Router.current = &""
	Flow.overlays_enabled = true
	Game.state = GameState.new()
	Game.rng = Rng.new(0)

func _smoke(mode: StringName, args: Dictionary) -> void:
	Router.args = args
	Router.current = mode
	var scene: PackedScene = load(Router.scene_path(mode))
	assert_not_null(scene, "no scene for %s" % mode)
	if scene == null: return
	view = scene.instantiate()
	add_child(view)
	await wait_frames(FRAMES)
	assert_true(is_instance_valid(view) and view.is_inside_tree(), "%s left the tree" % mode)

func test_menu() -> void:
	await _smoke(&"menu", {})

func test_menu_new_game_screen() -> void:
	await _smoke(&"menu", {"screen": "new"})

func test_location_sarmizegetusa() -> void:
	Game.state.mode = &"location"
	await _smoke(&"location", {"location_id": &"sarmizegetusa"})

func test_location_strigoi_cave() -> void:
	await _smoke(&"location", {"location_id": &"strigoi_cave"})

func test_location_crash_site() -> void:
	await _smoke(&"location", {"location_id": &"crash_site"})

func test_worldmap() -> void:
	Game.state.mode = &"worldmap"
	await _smoke(&"worldmap", {})

func test_combat_wolves() -> void:
	await _smoke(&"combat", {"encounter_id": &"wolves", "return_mode": &"worldmap", "return_args": {}})
	assert_true(int(view.battle.round) >= 1, "the battle started")

func test_combat_saucer() -> void:
	await _smoke(&"combat", {"encounter_id": &"saucer_surgeon", "return_mode": &"worldmap", "return_args": {},
		"ufo": &"ufo_sarmizegetusa"})
	assert_true(bool(view.battle.rules.magic_disabled), "the saucer's own rules apply")

func test_scroll() -> void:
	await _smoke(&"scroll", {"return_mode": &"worldmap", "return_args": {}})
