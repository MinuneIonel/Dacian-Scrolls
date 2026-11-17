## Captures engine errors (script errors, push_error) so the runner can fail tests on them.
extends Logger

var errors: Array[String] = []
var _mutex := Mutex.new()

func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING: return
	var text: String = rationale if rationale != "" else code
	_mutex.lock()
	errors.append("%s (%s:%d in %s)" % [text, file.get_file(), line, function])
	_mutex.unlock()

func _log_message(_message: String, _error: bool) -> void:
	pass

func take() -> Array[String]:
	_mutex.lock()
	var out: Array[String] = errors.duplicate()
	errors.clear()
	_mutex.unlock()
	return out
