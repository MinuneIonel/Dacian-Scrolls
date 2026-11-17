## Base class for every test file. Name files test_*.gd and methods test_*.
## A test may await (frames, signals). Engine errors logged during a test fail it,
## unless the test announces them first with expect_errors(n).
class_name TestCase
extends Node

var _failures: Array[String] = []
var _expected_errors: int = 0
var _seen_errors: Array[String] = []

func before_all() -> void: pass
func after_all() -> void: pass
func before_each() -> void: pass
func after_each() -> void: pass

func fail(msg: String) -> void:
	_failures.append(msg)

func assert_true(v: bool, msg: String = "") -> void:
	if not v: fail("expected true. " + msg)

func assert_false(v: bool, msg: String = "") -> void:
	if v: fail("expected false. " + msg)

func assert_eq(got: Variant, want: Variant, msg: String = "") -> void:
	if not _same(got, want): fail("expected %s, got %s. %s" % [_s(want), _s(got), msg])

func assert_ne(got: Variant, not_want: Variant, msg: String = "") -> void:
	if _same(got, not_want): fail("expected anything but %s. %s" % [_s(not_want), msg])

func assert_almost_eq(got: float, want: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(got - want) > eps: fail("expected %s ± %s, got %s. %s" % [want, eps, got, msg])

func assert_between(got: float, lo: float, hi: float, msg: String = "") -> void:
	if got < lo or got > hi: fail("expected %s in [%s, %s]. %s" % [got, lo, hi, msg])

func assert_has(container: Variant, item: Variant, msg: String = "") -> void:
	var ok: bool = false
	if container is Dictionary: ok = (container as Dictionary).has(item)
	elif container is Array: ok = (container as Array).has(item)
	elif container is String: ok = (container as String).contains(str(item))
	if not ok: fail("expected %s to contain %s. %s" % [_s(container), _s(item), msg])

func assert_not_has(container: Variant, item: Variant, msg: String = "") -> void:
	var ok: bool = false
	if container is Dictionary: ok = (container as Dictionary).has(item)
	elif container is Array: ok = (container as Array).has(item)
	elif container is String: ok = (container as String).contains(str(item))
	if ok: fail("expected %s not to contain %s. %s" % [_s(container), _s(item), msg])

func assert_null(v: Variant, msg: String = "") -> void:
	if v != null: fail("expected null, got %s. %s" % [_s(v), msg])

func assert_not_null(v: Variant, msg: String = "") -> void:
	if v == null: fail("expected non-null. " + msg)

## Allow exactly n engine errors (push_error, script errors) in this test.
func expect_errors(n: int) -> void:
	_expected_errors += n

## Waits n rendered/processed frames.
func wait_frames(n: int = 1) -> void:
	for i in n:
		await get_tree().process_frame

## Events helper: the first event of a type, or {}.
func find_event(events: Array, type: String) -> Dictionary:
	for e in events:
		if e is Dictionary and e.get("type", "") == type: return e
	return {}

func count_events(events: Array, type: String) -> int:
	var n: int = 0
	for e in events:
		if e is Dictionary and e.get("type", "") == type: n += 1
	return n

func _same(a: Variant, b: Variant) -> bool:
	# StringName and String compare equal; ints and floats compare by value.
	if (a is String or a is StringName) and (b is String or b is StringName):
		return str(a) == str(b)
	if (a is int or a is float) and (b is int or b is float):
		return a == b
	if typeof(a) != typeof(b): return false
	if a is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _same(a[i], b[i]): return false
		return true
	if a is Dictionary:
		if a.size() != b.size(): return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]): return false
		return true
	return a == b

func _s(v: Variant) -> String:
	var t: String = var_to_str(v) if not (v is Object) else str(v)
	return t if t.length() < 300 else t.substr(0, 300) + "…"
