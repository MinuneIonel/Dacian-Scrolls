## Reads a data root (res://data or a test fixture root) into a Defs, and the string table
## into a Translation. Not part of core: it touches the file system.
class_name ContentLoader
extends RefCounted

const DIRS: Dictionary = {
	&"class": "classes", &"ability": "abilities", &"item": "items", &"enemy": "enemies",
	&"encounter": "encounters", &"map": "maps", &"dialogue": "dialogue", &"quest": "quests",
	&"page": "pages", &"npc": "npcs", &"shop": "shops",
}
const SINGLETONS: Array[String] = ["world", "fanfi", "tiles"]

static func load_root(root: String) -> Defs:
	var defs := Defs.new()
	for kind in DIRS:
		var dir: String = root.path_join(DIRS[kind])
		var da := DirAccess.open(dir)
		if da == null: continue
		var files: PackedStringArray = da.get_files()
		files.sort()
		for f in files:
			if not f.ends_with(".json"): continue
			var v: Variant = read_json(dir.path_join(f))
			if v is Dictionary: defs.add(kind, v)
			elif v is Array:
				for d in v:
					if d is Dictionary: defs.add(kind, d)
	for s in SINGLETONS:
		var p: String = root.path_join(s + ".json")
		if FileAccess.file_exists(p): defs.set_json(s, read_json(p))
	return defs

static func read_json(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		push_error("ContentLoader: cannot read " + path)
		return null
	var j := JSON.new()
	if j.parse(text) != OK:
		push_error("ContentLoader: %s line %d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data

## Loads a "keys,<locale>" CSV into a Translation for that locale.
static func load_strings(csv_path: String) -> Translation:
	var f := FileAccess.open(csv_path, FileAccess.READ)
	if f == null: return null
	var header: PackedStringArray = f.get_csv_line()
	var t := Translation.new()
	t.locale = header[1] if header.size() > 1 else "en"
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			t.add_message(row[0], row[1].c_unescape())
	return t
