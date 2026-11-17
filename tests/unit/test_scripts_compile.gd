## Every script in the project parses. Catches typos in files no test touches yet.
extends TestCase

func _gd(dir: String, out: Array[String]) -> void:
	var da := DirAccess.open(dir)
	if da == null: return
	for sub in da.get_directories():
		if not sub.begins_with("."): _gd(dir + "/" + sub, out)
	for f in da.get_files():
		if f.ends_with(".gd"): out.append(dir + "/" + f)

func test_all_scripts_load() -> void:
	var files: Array[String] = []
	for d in ["res://src", "res://tools", "res://tests"]: _gd(d, files)
	for path in files:
		var s: Script = load(path)
		if s == null or not s.can_instantiate():
			fail("cannot load " + path)

func test_all_scenes_load() -> void:
	for m in ["menu", "worldmap", "location", "combat", "scroll"]:
		var p: String = "res://src/modes/%s/%s.tscn" % [m, m]
		assert_not_null(load(p), p)
