## src/core must stay pure: no scene tree, no autoloads, no global randomness, no clock, no files.
extends TestCase

const AUTOLOADS: Array[String] = ["Game", "Bus", "Content", "Assets", "Audio", "Router", "Settings", "Hud"]

func _core_files(dir: String, out: Array[String]) -> void:
	var da := DirAccess.open(dir)
	for sub in da.get_directories(): _core_files(dir + "/" + sub, out)
	for f in da.get_files():
		if f.ends_with(".gd"): out.append(dir + "/" + f)

func test_core_is_pure() -> void:
	var rx := RegEx.new()
	var autoload_alt: String = "|".join(AUTOLOADS)
	rx.compile("(?<![\\w.])(randi|randf|randi_range|randf_range|randomize|randfn)\\s*\\(|get_tree\\s*\\(|\\bTime\\.|\\bOS\\.|FileAccess|DirAccess|ResourceLoader|\\bload\\s*\\(|\\bpreload\\s*\\(|(?<![\\w.])(" + autoload_alt + ")\\.|extends\\s+Node")
	var files: Array[String] = []
	_core_files("res://src/core", files)
	assert_true(files.size() > 10, "found core files")
	for path in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line: String = lines[i].strip_edges()
			if line.begins_with("#") or line.begins_with("func ") or line.begins_with("static func "): continue
			var m := rx.search(line)
			if m != null:
				fail("%s:%d uses forbidden '%s'" % [path, i + 1, m.get_string()])
