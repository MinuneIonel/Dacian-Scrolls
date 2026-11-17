## Every combat and progression number lives here. Values are pinned in docs/CONTRACTS.md.
class_name Formulas
extends RefCounted

const MIN_HIT: int = 5
const MAX_HIT: int = 95
const FLANK_BONUS: int = 15
const XP_PER_LEVEL: int = 120

## AP per turn: 6 + agility / 2 (integer division).
static func ap_for(agility: int) -> int:
	return 6 + agility / 2

## Hit chance in percent, clamped to [MIN_HIT, MAX_HIT].
static func hit_chance(att_agility: int, tgt_agility: int, cover: int, flanked: bool) -> int:
	var c: int = 75 + 5 * (att_agility - tgt_agility) - cover + (FLANK_BONUS if flanked else 0)
	return clampi(c, MIN_HIT, MAX_HIT)

## max(1, base + stat * scale - armor), rounded down.
static func damage(base: int, stat: int, scale: float, armor: int) -> int:
	return maxi(1, floori(float(base) + float(stat) * scale) - armor)

## XP needed to go from `level` to level + 1: XP_PER_LEVEL * level.
static func xp_to_next(level: int) -> int:
	return XP_PER_LEVEL * maxi(1, level)

## Initiative: agility + d6.
static func initiative(agility: int, rng: Rng) -> int:
	return agility + rng.roll(6)

## Does a natural d20 `roll` hit at `chance` percent? Rolls high: hit when roll * 5 > 100 - chance,
## so 95% hits on 2+, 5% only on 20. A natural 20 always hits (and crits).
static func roll_hits(roll: int, chance: int) -> bool:
	return roll >= 20 or roll * 5 > 100 - chance

## Gib rule: crit kill, or overkill (damage past the remaining HP) of at least half max HP.
static func is_gib(crit: bool, overkill: int, max_hp: int) -> bool:
	return crit or overkill * 2 >= max_hp
