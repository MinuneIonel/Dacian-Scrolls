## The only source of randomness in the game. Seeded, serialisable, deterministic.
## Core code receives an Rng; it never calls the global random functions.
class_name Rng
extends RefCounted

var _r := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_r.seed = seed_value

## Inclusive on both ends.
func randi_range(a: int, b: int) -> int:
	return _r.randi_range(a, b)

## In [0, 1).
func randf() -> float:
	return _r.randf()

## A die roll from 1 to sides, e.g. roll(20) for a d20.
func roll(sides: int) -> int:
	return _r.randi_range(1, maxi(1, sides))

## True with probability p (0..1).
func chance(p: float) -> bool:
	return _r.randf() < p

## A random element, or null for an empty array.
func pick(arr: Array) -> Variant:
	if arr.is_empty(): return null
	return arr[_r.randi_range(0, arr.size() - 1)]

## Picks from [{..., weight_key: int}], weighted. Returns {} for an empty list.
func pick_weighted(items: Array, weight_key: String = "weight") -> Dictionary:
	var total: int = 0
	for it in items: total += int(it.get(weight_key, 1))
	if total <= 0: return {}
	var r: int = _r.randi_range(1, total)
	for it in items:
		r -= int(it.get(weight_key, 1))
		if r <= 0: return it
	return items[-1]

func get_state() -> int:
	return _r.state

func set_state(s: int) -> void:
	_r.state = s
