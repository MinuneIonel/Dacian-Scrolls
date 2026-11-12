## Player settings, stored apart from saves in user://settings.json.
## apply() pushes them to the window and to the "Music" / "SFX" audio buses when those exist.
extends Node

const PATH: String = "user://settings.json"
enum Gore { OFF = 0, NORMAL = 1, BLOODY_MESS = 2 }
const GORE_KEYS: Array[String] = ["settings_gore_off", "settings_gore_normal", "settings_gore_bloody"]
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

signal changed

var gore: int = Gore.NORMAL
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var fullscreen: bool = false
var path: String = PATH   # tests point this elsewhere

func _ready() -> void:
	load_settings()

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	apply()
	changed.emit()

func to_dict() -> Dictionary:
	return {"gore": gore, "music_volume": music_volume, "sfx_volume": sfx_volume, "fullscreen": fullscreen}

## Missing or corrupt files fall back to defaults silently.
func load_settings() -> void:
	reset_defaults()
	if FileAccess.file_exists(path):
		var json := JSON.new()   # an instance parses without logging errors
		var d: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
		if d is Dictionary:
			gore = clampi(int(_num(d.get("gore"), gore)), 0, 2)
			music_volume = clampf(_num(d.get("music_volume"), music_volume), 0.0, 1.0)
			sfx_volume = clampf(_num(d.get("sfx_volume"), sfx_volume), 0.0, 1.0)
			var fs: Variant = d.get("fullscreen")
			fullscreen = fs is bool and fs
	apply()
	changed.emit()

func reset_defaults() -> void:
	gore = Gore.NORMAL; music_volume = 0.8; sfx_volume = 0.8; fullscreen = false

## The string key naming the current gore level.
func gore_key() -> String:
	return GORE_KEYS[clampi(gore, 0, 2)]

## Window mode and bus volumes. Headless runs skip the window.
func apply() -> void:
	_set_bus(MUSIC_BUS, music_volume)
	_set_bus(SFX_BUS, sfx_volume)
	if DisplayServer.get_name() == "headless": return
	var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var now: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_full: bool = now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_full != fullscreen: DisplayServer.window_set_mode(want)

func _set_bus(bus: StringName, linear: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	if i < 0: return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.0)

static func _num(v: Variant, fallback: float) -> float:
	return float(v) if (v is float or v is int) else fallback
