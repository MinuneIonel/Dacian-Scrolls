## Switches between the five modes. Each mode is res://src/modes/<mode>/<mode>.tscn and reads
## Router.args in _ready(). Autosaves to slot 0 on every switch except to menu and combat,
## and only once there is a party (nothing to save on the title screen).
extends Node

const MODES: Array[StringName] = [&"menu", &"worldmap", &"location", &"combat", &"scroll"]
const NO_AUTOSAVE: Array[StringName] = [&"menu", &"combat"]
const AUTOSAVE_SLOT: int = 0
## location_cell when the location's own spawn should be used.
const NO_CELL := Vector2i(-1, -1)

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
		record(mode, mode_args)
		if autosave_enabled and not Game.state.party.is_empty():
			save_fn.call(AUTOSAVE_SLOT)
	if switch_scenes and is_inside_tree() and get_tree().current_scene != null:
		get_tree().call_deferred(&"change_scene_to_file", scene_path(mode))
	mode_changed.emit(mode)

static func scene_path(mode: StringName) -> String:
	return "res://src/modes/%s/%s.tscn" % [mode, mode]

## Writes where the game is into Game.state before the autosave, so Continue resumes there.
## location: mode plus location_id and location_cell (args cell, else the location's
## entry_cell, else NO_CELL: the location view picks its spawn). scroll is an overlay mode:
## the resume mode stays the one underneath (its return_mode when given).
func record(mode: StringName, mode_args: Dictionary) -> void:
	var st: GameState = Game.state
	match mode:
		&"location":
			st.mode = mode
			if mode_args.has("location_id"):
				st.location_id = StringName(str(mode_args.location_id))
			var cell: Variant = mode_args.get("cell")
			if cell != null and (cell is Vector2i or cell is Array):
				st.location_cell = Rules.to_cell(cell)
			else:
				var loc: Dictionary = Rules.location(st.location_id, Content.defs) if Content.defs != null else {}
				st.location_cell = Rules.to_cell(loc.entry_cell) if loc.has("entry_cell") else NO_CELL
		&"scroll":
			var rm := StringName(str(mode_args.get("return_mode", "")))
			if rm == &"location" or rm == &"worldmap":
				var ra: Variant = mode_args.get("return_args", {})
				record(rm, ra if ra is Dictionary else {})
			elif st.mode == &"scroll" or st.mode == &"":
				st.mode = &"worldmap"
		_:
			st.mode = mode

## The args a saved game resumes with, for Router.go(Game.state.mode, resume_args()).
func resume_args() -> Dictionary:
	if Game.state.mode == &"location":
		var out: Dictionary = {"location_id": Game.state.location_id}
		if Game.state.location_cell != NO_CELL: out["cell"] = Game.state.location_cell
		return out
	return {}

func _default_save(slot: int) -> Error:
	return Game.save(slot)
