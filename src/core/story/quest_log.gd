class_name QuestLog
extends RefCounted

const DONE_STAGE: int = 100

## Started quests: [{quest: StringName, stage: int, name_key: String, desc_key: String, done: bool}].
## Active quests first, then done ones, each sorted by id. desc_key is the text of the highest
## defined stage reached. Quests without a def are skipped.
static func entries(state: GameState, defs: Defs) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	var done: Array[Dictionary] = []
	var ids: Array = state.quests.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for id in ids:
		var q := StringName(str(id))
		var stage: int = int(state.quests[id])
		if stage <= 0 or not defs.has(&"quest", q): continue
		var def: Dictionary = defs.get_def(&"quest", q)
		var e: Dictionary = {"quest": q, "stage": stage, "name_key": str(def.get("name_key", "")),
			"desc_key": _desc_for(def, stage), "done": stage >= DONE_STAGE}
		if e.done: done.append(e)
		else: active.append(e)
	active.append_array(done)
	return active

static func _desc_for(def: Dictionary, stage: int) -> String:
	var stages: Variant = def.get("stages", {})
	if not (stages is Dictionary): return ""
	var best: int = -1
	var key: String = ""
	for k in stages:
		var n: int = str(k).to_int()
		if n <= stage and n > best:
			best = n
			key = str(stages[k])
	return key
