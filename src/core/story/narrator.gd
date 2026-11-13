## Fanfi. Picks narrator lines for a batch of events from Defs.json("fanfi").
## fanfi.json: {event_type: [{if: [conds], lines: [keys], once: bool}]}.
class_name Narrator
extends RefCounted

const ONCE_PREFIX: String = "fanfi_once:"

## String-table keys to show, in order. "once" lines are remembered in state.flags.
## Returns at most one line: for the first event (in order) that has a usable entry, a random
## line of its first entry whose "if" holds and that still has a line left. A `narrator`
## event (from the ["narrate", key] effect) counts as matching and speaks its own line_key.
static func lines_for(events: Array[Dictionary], state: GameState, rng: Rng, defs: Defs) -> Array[String]:
	var out: Array[String] = []
	var fanfi: Variant = defs.json("fanfi")
	if not (fanfi is Dictionary): fanfi = {}
	for e in events:
		var type: String = str(e.get("type", ""))
		if type == "narrator" and str(e.get("line_key", "")) != "":
			out.append(str(e.line_key))
			return out
		var entries: Variant = fanfi.get(type, [])
		if not (entries is Array): continue
		for entry in entries:
			if not (entry is Dictionary): continue
			var conds: Variant = entry.get("if", [])
			if not (conds is Array) or not Rules.check(conds, state, defs): continue
			var once: bool = entry.get("once", false) == true
			var avail: Array = []
			for k in entry.get("lines", []):
				if not once or not state.flags.has(ONCE_PREFIX + str(k)): avail.append(str(k))
			if avail.is_empty(): continue
			var line: String = str(rng.pick(avail))
			if once: state.flags[ONCE_PREFIX + line] = true
			out.append(line)
			return out
	return out
