## Every combat and progression number lives here. Values are pinned in docs/CONTRACTS.md.
class_name Formulas
extends RefCounted

const MIN_HIT: int = 5
const MAX_HIT: int = 95
const FLANK_BONUS: int = 15
const XP_PER_LEVEL: int = 120

## AP per turn: 6 + agility / 2 (integer division).
static func ap_for(agility: int) -> int:
	push_error("not implemented: Formulas.ap_for")  # WP-12
	return 0

## Hit chance in percent, clamped to [MIN_HIT, MAX_HIT].
static func hit_chance(att_agility: int, tgt_agility: int, cover: int, flanked: bool) -> int:
	push_error("not implemented: Formulas.hit_chance")  # WP-12
	return 0

## max(1, base + stat * scale - armor), rounded down.
static func damage(base: int, stat: int, scale: float, armor: int) -> int:
	push_error("not implemented: Formulas.damage")  # WP-12
	return 0

## XP needed to go from `level` to level + 1: XP_PER_LEVEL * level.
static func xp_to_next(level: int) -> int:
	push_error("not implemented: Formulas.xp_to_next")  # WP-12
	return 0

## Initiative: agility + d6.
static func initiative(agility: int, rng: Rng) -> int:
	push_error("not implemented: Formulas.initiative")  # WP-12
	return 0
