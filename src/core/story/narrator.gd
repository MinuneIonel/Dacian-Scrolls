## Fanfi. Picks narrator lines for a batch of events from Defs.json("fanfi").
class_name Narrator
extends RefCounted

## String-table keys to show, in order. "once" lines are remembered in state.flags.
static func lines_for(events: Array[Dictionary], state: GameState, rng: Rng, defs: Defs) -> Array[String]:
	push_error("not implemented: Narrator.lines_for")  # WP-11
	return []
