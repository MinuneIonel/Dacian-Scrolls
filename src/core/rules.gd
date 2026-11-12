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

## Reveals every cell within Chebyshev `radius` of `center` that lies inside world.size.
## Returns only the newly revealed cells. Used by ["discover"] and Game.new_game.
static func reveal_around(state: GameState, center: Vector2i, radius: int, defs: Defs) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var world: Variant = defs.json("world")
	var size := Vector2i(1 << 20, 1 << 20)
	if world is Dictionary and world.get("size") is Array and world.size.size() == 2:
		size = Vector2i(int(world.size[0]), int(world.size[1]))
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or y < 0 or x >= size.x or y >= size.y: continue
			var k: String = GameState.cell_key(Vector2i(x, y))
			if state.revealed.has(k): continue
			state.revealed[k] = true
			out.append(Vector2i(x, y))
	return out

## The world.json location with that id, or {}.
static func location(id: StringName, defs: Defs) -> Dictionary:
	var world: Variant = defs.json("world")
	if not (world is Dictionary): return {}
	for l in world.get("locations", []):
		if l is Dictionary and StringName(str(l.get("id", ""))) == id: return l
	return {}

## [x, y] to a cell; anything else is (0, 0).
static func to_cell(v: Variant) -> Vector2i:
	if v is Vector2i: return v
	if v is Array and v.size() == 2: return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO
