## Walks one dialogue tree. Choices are filtered by their "if" conditions.
class_name DialogueRunner
extends RefCounted

func _init(dialogue_id: StringName, state: GameState, rng: Rng, defs: Defs) -> void:
	push_error("not implemented: DialogueRunner")  # WP-11

## {speaker: String, text_key: String, choices: [{index: int, text_key: String}]}, {} when done.
func current() -> Dictionary:
	return {}

## Events from entering the first node (its "do" effects). Call once after construction.
func start() -> Array[Dictionary]:
	return []

func choose(index: int) -> Array[Dictionary]:
	return []

func is_done() -> bool:
	return true
