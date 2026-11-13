## One party member. Plain data plus serialisation.
class_name Character
extends RefCounted

const STAT_KEYS: Array[String] = ["might", "agility", "wits", "spirit"]
const MAX_EQUIPPED: int = 4
const GEAR_SLOTS: Array[String] = ["weapon", "armor", "trinket"]

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
	var c := Character.new()
	c.id = char_id
	c.name_key = char_name_key
	c.class_id = StringName(str(class_def.get("id", "")))
	c.level = 1
	c.xp = 0
	c.max_hp = int(class_def.get("base_hp", 1))
	c.hp = c.max_hp
	c.max_mana = int(class_def.get("base_mana", 0))
	c.mana = c.max_mana
	c.max_charge = int(class_def.get("base_charge", 0))
	c.charge = c.max_charge
	var base: Dictionary = class_def.get("base_stats", {})
	c.stats = {}
	for k in STAT_KEYS: c.stats[k] = int(base.get(k, 1))
	for a in class_def.get("abilities", []): c.known.append(StringName(str(a)))
	for i in mini(MAX_EQUIPPED, c.known.size()): c.equipped.append(c.known[i])
	return c

func to_dict() -> Dictionary:
	var g: Dictionary = {}
	for k in GEAR_SLOTS: g[k] = str(gear.get(k, ""))
	return {
		"id": str(id), "name_key": name_key, "class_id": str(class_id),
		"level": level, "xp": xp, "hp": hp, "max_hp": max_hp, "mana": mana,
		"max_mana": max_mana, "charge": charge, "max_charge": max_charge,
		"stats": stats.duplicate(),
		"known": known.map(func(a: StringName) -> String: return str(a)),
		"equipped": equipped.map(func(a: StringName) -> String: return str(a)),
		"gear": g,
	}

## Lenient: missing fields get defaults. SaveCodec validates untrusted input first.
static func from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	c.id = StringName(str(d.get("id", "")))
	c.name_key = str(d.get("name_key", ""))
	c.class_id = StringName(str(d.get("class_id", "")))
	c.level = maxi(1, int(d.get("level", 1)))
	c.xp = int(d.get("xp", 0))
	c.max_hp = int(d.get("max_hp", 1))
	c.hp = int(d.get("hp", c.max_hp))
	c.max_mana = int(d.get("max_mana", 0))
	c.mana = int(d.get("mana", c.max_mana))
	c.max_charge = int(d.get("max_charge", 0))
	c.charge = int(d.get("charge", c.max_charge))
	var st: Dictionary = d.get("stats", {})
	c.stats = {}
	for k in STAT_KEYS: c.stats[k] = int(st.get(k, 1))
	for a in d.get("known", []): c.known.append(StringName(str(a)))
	for a in d.get("equipped", []):
		if c.equipped.size() < MAX_EQUIPPED: c.equipped.append(StringName(str(a)))
	var g: Dictionary = d.get("gear", {})
	c.gear = {}
	for k in GEAR_SLOTS: c.gear[k] = StringName(str(g.get(k, "")))
	return c

## Adds XP and levels up as needed (see Formulas.xp_to_next). Returns events
## (xp_gained, level_up).
func gain_xp(amount: int, class_def: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if amount <= 0: return out
	xp += amount
	out.append({"type": "xp_gained", "unit": id, "amount": amount})
	while xp >= Formulas.xp_to_next(level):
		xp -= Formulas.xp_to_next(level)
		out.append(level_up(class_def))
	return out

## One level: more HP and +1 to the class's highest base stat. Returns the level_up event.
func level_up(class_def: Dictionary) -> Dictionary:
	level += 1
	var per: int = int(class_def.get("hp_per_level", 0))
	max_hp += per
	hp += per
	var top: String = top_stat(class_def)
	stats[top] = int(stats.get(top, 0)) + 1
	return {"type": "level_up", "unit": id, "level": level}

## The class's highest base stat; ties go to the first in STAT_KEYS order.
static func top_stat(class_def: Dictionary) -> String:
	var base: Dictionary = class_def.get("base_stats", {})
	var best: String = STAT_KEYS[0]
	for k in STAT_KEYS:
		if int(base.get(k, 0)) > int(base.get(best, 0)): best = k
	return best
