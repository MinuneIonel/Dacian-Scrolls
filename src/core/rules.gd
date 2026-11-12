## The rules mini-language shared by dialogue, quests, encounters and map triggers.
## Conditions are arrays like ["flag", "met_priest", "==", true]; effects like ["gold", 12].
## See docs/CONTRACTS.md section "Rules" for every form.
class_name Rules
extends RefCounted

## Condition name -> number of arguments after the name.
const CONDITIONS: Dictionary = {
	"flag": 3, "quest": 3, "has_item": 2, "gold": 2, "class": 1, "in_party": 1,
	"has_page": 1, "stat": 3, "night": 0, "not": 1, "any": 1,
}
## Effect name -> number of arguments after the name.
const EFFECTS: Dictionary = {
	"set_flag": 2, "give_item": 2, "take_item": 2, "gold": 1, "food": 1, "quest": 2,
	"page": 1, "xp": 1, "recruit": 1, "heal_party": 0, "battle": 1, "shop": 1,
	"discover": 1, "teleport": 1, "narrate": 1, "roll": 4,
}
const OPS: Array[String] = ["==", "!=", ">=", "<=", ">", "<"]

## True when every condition holds. An empty list is true.
static func check(conds: Array, state: GameState, defs: Defs) -> bool:
	push_error("not implemented: Rules.check")  # WP-11
	return false

## Applies effects in order, returns the events they caused.
static func run(effects: Array, state: GameState, rng: Rng, defs: Defs) -> Array[Dictionary]:
	push_error("not implemented: Rules.run")  # WP-11
	return []
