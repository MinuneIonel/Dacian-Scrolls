class_name QuestLog
extends RefCounted

## Started quests: [{quest: StringName, stage: int, name_key: String, desc_key: String, done: bool}].
static func entries(state: GameState, defs: Defs) -> Array[Dictionary]:
	push_error("not implemented: QuestLog.entries")  # WP-11
	return []
