## Global signals. Nothing but signals lives here.
extends Node

## Core events just applied to Game.state, for narrator, toasts, sounds, HUDs.
signal events_emitted(events: Array[Dictionary])
signal mode_change_requested(mode: StringName, args: Dictionary)
## A short message key from the string table.
signal toast(text_key: String)

func emit_events(events: Array[Dictionary]) -> void:
	if not events.is_empty(): events_emitted.emit(events)
