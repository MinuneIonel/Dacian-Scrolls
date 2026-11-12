## Switches between the five modes. Each mode is res://src/modes/<mode>/<mode>.tscn and reads
## Router.args in _ready(). Autosaves to slot 0 on every switch except to menu and combat,
## and only once there is a party (nothing to save on the title screen).
extends Node

const MODES: Array[StringName] = [&"menu", &"worldmap", &"location", &"combat", &"scroll"]
const NO_AUTOSAVE: Array[StringName] = [&"menu", &"combat"]
const AUTOSAVE_SLOT: int = 0

signal mode_changed(mode: StringName)

var current: StringName = &""
var args: Dictionary = {}
var autosave_enabled: bool = true
## Tests set this false so go() records the mode without replacing the running scene.
var switch_scenes: bool = true
## How the autosave is written: func(slot: int) -> Error. Defaults to Game.save; tests swap it.
var save_fn: Callable = _default_save

func go(mode: StringName, mode_args: Dictionary = {}) -> void:
	if not MODES.has(mode):
		push_error("Router: unknown mode " + mode)
		return
	args = mode_args
	current = mode
	if not NO_AUTOSAVE.has(mode):
		Game.state.mode = mode
		if autosave_enabled and not Game.state.party.is_empty():
			save_fn.call(AUTOSAVE_SLOT)
	if switch_scenes and is_inside_tree() and get_tree().current_scene != null:
		get_tree().call_deferred(&"change_scene_to_file", scene_path(mode))
	mode_changed.emit(mode)

static func scene_path(mode: StringName) -> String:
	return "res://src/modes/%s/%s.tscn" % [mode, mode]

## The args a saved game resumes with, for Router.go(Game.state.mode, resume_args()).
func resume_args() -> Dictionary:
	if Game.state.mode == &"location":
		return {"location_id": Game.state.location_id, "cell": Game.state.location_cell}
	return {}

func _default_save(slot: int) -> Error:
	return Game.save(slot)
