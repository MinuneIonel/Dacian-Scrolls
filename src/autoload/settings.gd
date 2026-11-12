## Player settings, stored apart from saves in user://settings.json.
extends Node

const PATH: String = "user://settings.json"
enum Gore { OFF = 0, NORMAL = 1, BLOODY_MESS = 2 }

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
	f.store_string(JSON.stringify({"gore": gore, "music_volume": music_volume,
		"sfx_volume": sfx_volume, "fullscreen": fullscreen}))
	changed.emit()

## Missing or corrupt files fall back to defaults silently.
func load_settings() -> void:
	reset_defaults()
	if not FileAccess.file_exists(path): return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary): return
	gore = clampi(int(d.get("gore", gore)), 0, 2)
	music_volume = clampf(float(d.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(d.get("fullscreen", fullscreen))
	changed.emit()

func reset_defaults() -> void:
	gore = Gore.NORMAL; music_volume = 0.8; sfx_volume = 0.8; fullscreen = false
