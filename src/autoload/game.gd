## Owns the live GameState and the game's Rng. Saves and loads.
extends Node

const SAVE_PATTERN: String = "user://save_%d.json"
const SLOTS: int = 4   # 0 is the autosave, 1..3 manual

var state: GameState = GameState.new()
var rng: Rng = Rng.new(0)
var save_dir_override: String = ""   # tests point saves elsewhere

## Fresh game: hero of the given class, starting food/gold, UFOs seeded, at Sarmizegetusa.
func new_game(seed_value: int, hero_class: StringName) -> void:
	push_error("not implemented: Game.new_game")  # WP-10

func save(slot: int) -> Error:
	push_error("not implemented: Game.save")  # WP-10
	return ERR_UNAVAILABLE

## On failure returns an error and leaves `state` untouched; the reason key goes to Bus.toast.
func load_slot(slot: int) -> Error:
	push_error("not implemented: Game.load_slot")  # WP-10
	return ERR_UNAVAILABLE

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(save_path(slot))

func save_path(slot: int) -> String:
	if save_dir_override != "": return save_dir_override.path_join("save_%d.json" % slot)
	return SAVE_PATTERN % slot

## Applies events' side effects that live outside core (narrator, toasts) by broadcasting them.
func broadcast(events: Array[Dictionary]) -> void:
	Bus.emit_events(events)
