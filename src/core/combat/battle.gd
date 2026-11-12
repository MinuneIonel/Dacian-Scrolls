## One tactical battle. Drive it with apply(action); read back events. No scene tree.
## Unit dictionaries: {uid: int, side: "party"|"enemy", def_id: StringName, char_id: StringName,
##   cell: Vector2i, size: int, hp: int, max_hp: int, ap: int, mana: int, charge: int,
##   armor: int, stats: Dictionary, abilities: Array[StringName], statuses: Dictionary, summoned: bool}
class_name Battle
extends RefCounted

var encounter_id: StringName
var round: int = 0
var rules: Dictionary = {"magic_disabled": false, "gravity": "normal", "turn_limit": 0}
var grid: Grid

func _init(enc_id: StringName, party: Array[Character], rng: Rng, defs: Defs) -> void:
	encounter_id = enc_id
	push_error("not implemented: Battle._init")  # WP-12

func units() -> Array[Dictionary]:
	return []

func unit(uid: int) -> Dictionary:
	return {}

## uid of the unit whose turn it is.
func current_unit() -> int:
	return -1

## True for units the AI drives: every enemy, and summoned party units.
func is_ai(uid: int) -> bool:
	return false

## Every legal action for that unit. Always contains {type: "end_turn"} while the battle runs.
func legal_actions(uid: int) -> Array[Dictionary]:
	return []

## Applies an action for the current unit. Illegal actions change nothing and return
## [{type: "illegal", reason: String}].
func apply(action: Dictionary) -> Array[Dictionary]:
	return []

## Events produced by starting the battle (initiative, first turn_started).
func start() -> Array[Dictionary]:
	return []

func is_over() -> bool:
	return true

## {outcome: "win"|"lose"|"fled", reason: String, loot: {item_id: n}, downed: [char_id],
##  party_hp: {char_id: hp}, party_mana: {char_id: n}, party_charge: {char_id: n}}. See CONTRACTS section 8.
func result() -> Dictionary:
	return {}

## [{cell: Vector2i, def_id: StringName, raiseable: bool}]
func corpses() -> Array[Dictionary]:
	return []
