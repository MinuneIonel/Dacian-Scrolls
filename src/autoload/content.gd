## Loaded game data. Content.defs is what you pass into core code.
extends Node

const DATA_ROOT: String = "res://data"

var defs: Defs

func _ready() -> void:
	reload(DATA_ROOT)

## Replaces all content, e.g. with tests/fixtures/data. Also loads <root>/strings/en.csv.
func reload(root: String) -> void:
	defs = ContentLoader.load_root(root)
	var csv: String = root.path_join("strings/en.csv")
	if FileAccess.file_exists(csv):
		var t: Translation = ContentLoader.load_strings(csv)
		if t != null:
			TranslationServer.add_translation(t)
			TranslationServer.set_locale(t.locale)

func get_def(kind: StringName, id: StringName) -> Dictionary:
	return defs.get_def(kind, id)

func all(kind: StringName) -> Array[Dictionary]:
	return defs.all(kind)

func has(kind: StringName, id: StringName) -> bool:
	return defs.has(kind, id)
