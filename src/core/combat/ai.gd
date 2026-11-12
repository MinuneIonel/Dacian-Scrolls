## Picks actions for units. Every function returns one member of battle.legal_actions(uid).
class_name Ai
extends RefCounted

## Enemy brain, by the enemy's "ai" field.
static func choose(battle: Battle, uid: int, rng: Rng) -> Dictionary:
	push_error("not implemented: Ai.choose")  # WP-20
	return {"type": "end_turn"}

## A competent player: focuses fire, uses combos, heals when needed. For balance sims and the bot.
static func policy_good(battle: Battle, uid: int, rng: Rng) -> Dictionary:
	push_error("not implemented: Ai.policy_good")  # WP-20
	return {"type": "end_turn"}

## A button-masher: a uniformly random legal action, but never end_turn while other actions exist.
static func policy_random(battle: Battle, uid: int, rng: Rng) -> Dictionary:
	push_error("not implemented: Ai.policy_random")  # WP-20
	return {"type": "end_turn"}
