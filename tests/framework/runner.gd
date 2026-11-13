## Headless test runner. Started by tools/test.sh. Exit code 0 means everything passed.
extends Node

const CatcherScript := preload("res://tests/framework/error_catcher.gd")

var _catcher: Logger
var _passed: int = 0
var _failed: Array[String] = []

func _ready() -> void:
	_catcher = CatcherScript.new()
	OS.add_logger(_catcher)
	var dirs: PackedStringArray = PackedStringArray(["tests/unit", "tests/integration"])
	var filter: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dirs="): dirs = a.trim_prefix("--dirs=").split(",", false)
		elif a.begins_with("--filter="): filter = a.trim_prefix("--filter=")
	var files: Array[String] = []
	for d in dirs:
		_collect("res://" + d.trim_prefix("res://").trim_suffix("/"), files)
	files.sort()
	_catcher.take()  # discard startup noise from autoloads
	var t0: int = Time.get_ticks_msec()
	for f in files:
		await _run_file(f, filter)
	var dt: float = (Time.get_ticks_msec() - t0) / 1000.0
	print("")
	for line in _failed: print("FAIL ", line)
	print("%d passed, %d failed in %.1fs" % [_passed, _failed.size(), dt])
	get_tree().quit(0 if _failed.is_empty() and _passed > 0 else 1)

func _collect(dir: String, out: Array[String]) -> void:
	var da := DirAccess.open(dir)
	if da == null: return
	for sub in da.get_directories():
		_collect(dir + "/" + sub, out)
	for f in da.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"): out.append(dir + "/" + f)

func _run_file(path: String, filter: String) -> void:
	var script: Script = load(path)
	var load_errors: Array[String] = _catcher.take()
	if script == null or not script.can_instantiate():
		_failed.append("%s: could not load. %s" % [path, "; ".join(load_errors)])
		return
	var tc: Node = script.new()
	if not (tc is TestCase):
		_failed.append("%s: does not extend TestCase" % path)
		tc.free()
		return
	var names: Array[String] = []
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not names.has(n): names.append(n)
	var file_match: bool = filter == "" or path.get_file().contains(filter)
	if not file_match:
		names = names.filter(func(n: String) -> bool: return n.contains(filter))
	if names.is_empty():
		tc.free()
		return
	tc.name = path.get_file().get_basename()
	add_child(tc)
	await tc.before_all()
	for n in names:
		tc._failures.clear(); tc._expected_errors = 0
		_catcher.take()
		await tc.before_each()
		await tc.call(n)
		await tc.after_each()
		var errs: Array[String] = _catcher.take()
		var label: String = "%s::%s" % [path.trim_prefix("res://"), n]
		if errs.size() != tc._expected_errors:
			tc._failures.append("expected %d engine errors, got %d: %s" % [tc._expected_errors, errs.size(), "; ".join(errs)])
		if tc._failures.is_empty():
			_passed += 1
			print("  ok   ", label)
		else:
			_failed.append(label + "\n       " + "\n       ".join(tc._failures))
			print("  FAIL ", label)
	await tc.after_all()
	tc.queue_free()
	await get_tree().process_frame
