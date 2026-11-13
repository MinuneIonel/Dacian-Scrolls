## Walks one dialogue tree. Choices are filtered by their "if" conditions.
class_name DialogueRunner
extends RefCounted

const END: String = "end"

var _def: Dictionary = {}
var _node_id: String = ""
var _started: bool = false
var _state: GameState
var _rng: Rng
var _defs: Defs

func _init(dialogue_id: StringName, state: GameState, rng: Rng, defs: Defs) -> void:
	_state = state
	_rng = rng
	_defs = defs
	_def = defs.get_def(&"dialogue", dialogue_id)   # logs one error when unknown
	if _def.is_empty(): return
	var start_id: String = str(_def.get("start", ""))
	if not _nodes().has(start_id):
		push_error("DialogueRunner: '%s' has no start node '%s'" % [dialogue_id, start_id])
		return
	_node_id = start_id

## {speaker: String, text_key: String, choices: [{index: int, text_key: String}]}, {} when done.
## A choice's index is its position in the node's full choice list; pass it to choose().
func current() -> Dictionary:
	if is_done(): return {}
	var node: Dictionary = _node()
	var choices: Array[Dictionary] = []
	var all: Array = node.get("choices", [])
	for i in all.size():
		if _visible(all[i]):
			choices.append({"index": i, "text_key": str(all[i].get("text_key", ""))})
	return {"speaker": str(node.get("speaker", "")), "text_key": str(node.get("text_key", "")),
		"choices": choices}

## Events from entering the first node (its "do" effects). Call once after construction.
func start() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _started or is_done(): return out
	_started = true
	return Rules.run(_node().get("do", []), _state, _rng, _defs)

## Runs a visible choice's "do", then moves to its goto node and runs that node's "do".
## A hidden or unknown index changes nothing and returns [].
func choose(index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if is_done(): return out
	var all: Array = _node().get("choices", [])
	if index < 0 or index >= all.size() or not _visible(all[index]): return out
	_started = true
	var choice: Dictionary = all[index]
	out.append_array(Rules.run(choice.get("do", []), _state, _rng, _defs))
	var goto: String = str(choice.get("goto", END))
	if goto == END:
		_node_id = ""
	elif not _nodes().has(goto):
		push_error("DialogueRunner: '%s' goto unknown node '%s'" % [_def.get("id", ""), goto])
		_node_id = ""
	else:
		_node_id = goto
		out.append_array(Rules.run(_node().get("do", []), _state, _rng, _defs))
	return out

func is_done() -> bool:
	return _node_id == ""

func _nodes() -> Dictionary:
	var n: Variant = _def.get("nodes", {})
	return n if n is Dictionary else {}

func _node() -> Dictionary:
	var n: Variant = _nodes().get(_node_id, {})
	return n if n is Dictionary else {}

func _visible(choice: Variant) -> bool:
	return choice is Dictionary and Rules.check(choice.get("if", []), _state, _defs)
