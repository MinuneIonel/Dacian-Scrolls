## One party member. Plain data plus serialisation.
class_name Character
extends RefCounted

const STAT_KEYS: Array[String] = ["might", "agility", "wits", "spirit"]
const MAX_EQUIPPED: int = 4

var id: StringName
var name_key: String
var class_id: StringName
var level: int = 1
var xp: int = 0
var hp: int = 1
var max_hp: int = 1
var mana: int = 0
var max_mana: int = 0
var charge: int = 0
var max_charge: int = 0
var stats: Dictionary = {"might": 1, "agility": 1, "wits": 1, "spirit": 1}
var known: Array[StringName] = []      # abilities learned
var equipped: Array[StringName] = []   # at most MAX_EQUIPPED, subset of known
var gear: Dictionary = {"weapon": &"", "armor": &"", "trinket": &""}

## A new level-1 character from a class definition (see data/schemas/class.schema.json).
static func create(char_id: StringName, class_def: Dictionary, char_name_key: String) -> Character:
	push_error("not implemented: Character.create")  # WP-10
	return Character.new()

func to_dict() -> Dictionary:
	push_error("not implemented: Character.to_dict")  # WP-10
	return {}

static func from_dict(d: Dictionary) -> Character:
	push_error("not implemented: Character.from_dict")  # WP-10
	return Character.new()

## Adds XP and levels up as needed (see Formulas.xp_to_next). Returns events
## (xp_gained, level_up).
func gain_xp(amount: int, class_def: Dictionary) -> Array[Dictionary]:
	push_error("not implemented: Character.gain_xp")  # WP-10
	return []
