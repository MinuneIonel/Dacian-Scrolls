class_name Encounters
extends RefCounted

## Options the player may pick now: [{id, label_key, chance: int (percent, 100 without a roll)}].
## Never fewer than 2: "fight" and "flee" are always kept.
static func options(encounter_id: StringName, state: GameState, defs: Defs) -> Array[Dictionary]:
	push_error("not implemented: Encounters.options")  # WP-13
	return []

static func choose(encounter_id: StringName, option_id: String, state: GameState, rng: Rng, defs: Defs) -> Array[Dictionary]:
	push_error("not implemented: Encounters.choose")  # WP-13
	return []

## Applies a finished Battle.result(): party HP/mana/charge, loot, and the encounter XP on a win.
static func apply_battle_result(encounter_id: StringName, result: Dictionary, state: GameState, rng: Rng, defs: Defs) -> Array[Dictionary]:
	push_error("not implemented: Encounters.apply_battle_result")  # WP-13
	return []
