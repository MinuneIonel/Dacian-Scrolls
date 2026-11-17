## Loaded game data. Content.defs is what you pass into core code.
extends Node

const DATA_ROOT: String = "res://data"

var defs: Defs

func _ready() -> void:
	reload(DATA_ROOT)

var _translations: Array[Translation] = []

## Replaces all content, e.g. with tests/fixtures/data. Also loads every <root>/strings/*.csv
## (each file has a "keys,en" header; files are split by owner to avoid merge conflicts).
func reload(root: String) -> void:
	defs = ContentLoader.load_root(root)
	for t in _translations: TranslationServer.remove_translation(t)
	_translations.clear()
	var dir: String = root.path_join("strings")
	var da := DirAccess.open(dir)
	if da == null: return
	var files: PackedStringArray = da.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".csv"): continue
		var t: Translation = ContentLoader.load_strings(dir.path_join(f))
		if t != null:
			TranslationServer.add_translation(t)
			_translations.append(t)
			TranslationServer.set_locale(t.locale)

func get_def(kind: StringName, id: StringName) -> Dictionary:
	return defs.get_def(kind, id)

func all(kind: StringName) -> Array[Dictionary]:
	return defs.all(kind)

func has(kind: StringName, id: StringName) -> bool:
	return defs.has(kind, id)
