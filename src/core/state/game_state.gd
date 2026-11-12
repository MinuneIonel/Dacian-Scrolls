## Everything that is saved. Every mode reads and writes this one object.
class_name GameState
extends RefCounted

const VERSION: int = 1

var version: int = VERSION
var seed: int = 0
var rng_state: int = 0
var day: int = 1
var hour: int = 8                      # 0..23; night is hour >= 20 or hour <= 5
var food: int = 0
var gold: int = 0
var party: Array[Character] = []       # index 0 is the hero, max 4
var inventory: Dictionary = {}         # StringName item_id -> int count
var flags: Dictionary = {}             # String -> Variant
var quests: Dictionary = {}            # StringName quest_id -> int stage (0 none, 100 done)
var pages: Array[StringName] = []      # scroll pages in the order found
var world_pos: Vector2i = Vector2i.ZERO
var revealed: Dictionary = {}          # "x,y" -> true
var discovered: Array[StringName] = [] # location ids
var ufos: Array[Dictionary] = []       # {id: StringName, pos: Vector2i, state: "patrol"|"chase"|"gone", route_i: int}
var mode: StringName = &"worldmap"     # the mode to resume in
var location_id: StringName = &""
var location_cell: Vector2i = Vector2i.ZERO

func is_night() -> bool:
	return hour >= 20 or hour <= 5

static func cell_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]

func to_dict() -> Dictionary:
	push_error("not implemented: GameState.to_dict")  # WP-10
	return {}

static func from_dict(d: Dictionary) -> GameState:
	push_error("not implemented: GameState.from_dict")  # WP-10
	return GameState.new()
