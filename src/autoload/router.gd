## Switches between the five modes. Each mode is res://src/modes/<mode>/<mode>.tscn and reads
## Router.args in _ready(). Autosaves to slot 0 on every switch except to menu and combat.
extends Node

const MODES: Array[StringName] = [&"menu", &"worldmap", &"location", &"combat", &"scroll"]
const NO_AUTOSAVE: Array[StringName] = [&"menu", &"combat"]

signal mode_changed(mode: StringName)

var current: StringName = &""
var args: Dictionary = {}
var autosave_enabled: bool = true

func go(mode: StringName, mode_args: Dictionary = {}) -> void:
	if not MODES.has(mode):
		push_error("Router: unknown mode " + mode)
		return
	args = mode_args
	current = mode
	if mode != &"menu" and mode != &"combat":
		Game.state.mode = mode
		if autosave_enabled and not Game.state.party.is_empty():
			Game.save(0)
	var path: String = "res://src/modes/%s/%s.tscn" % [mode, mode]
	if is_inside_tree() and get_tree().current_scene != null:
		get_tree().call_deferred("change_scene_to_file", path)
	mode_changed.emit(mode)
