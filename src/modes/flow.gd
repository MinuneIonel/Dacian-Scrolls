## Glue between the modes (WP-30): the new game séance, the abduction (beam, saucer battle,
## crash or wake-up) and the wake-up at the temple after a lost battle. Never a game over.
##
## The state-changing part is pure (`begin_abduction`, `after_battle`: state, rng and defs in,
## events out) so tests can drive it without scenes. The rest starts overlays that live under
## the Hud autoload, above whatever mode the Router swaps in underneath:
##   Flow.start_new_game(seed, class)        menu Begin: new game, location, séance
##   Flow.play_abduction(ufo, enc, screen)   world map: beam, white-out, saucer battle
##   Flow.show_wake(after)                   combat end: wake-up card, then Fanfi's line
class_name Flow
extends RefCounted

const SeanceOverlay := preload("res://src/modes/flow/seance.gd")
const BeamOverlay := preload("res://src/modes/flow/beam.gd")
const WakeOverlay := preload("res://src/modes/flow/wake.gd")

## Where a lost regular battle wakes the party: the temple floor of Sarmizegetusa.
const TEMPLE_LOCATION: StringName = &"sarmizegetusa"
const TEMPLE_CELL := Vector2i(8, 8)
## Where a downed saucer comes down (a world.json location id).
const CRASH_LOCATION: StringName = &"crash_site"
const DEFEAT_LINES: Array[String] = ["flow_defeat_1", "flow_defeat_2", "flow_defeat_3"]
const FOREST_LINES: Array[String] = ["flow_wake_forest_1", "flow_wake_forest_2"]
const CRASH_LINES: Array[String] = ["flow_saucer_down_1"]
## Neighbours tried, in order, for the landing cell next to the crash site.
const AROUND: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(1, -1)]

## Tests turn the overlays off (or make them instant).
static var overlays_enabled: bool = true
static var instant: bool = false

# ---------------------------------------------------------------- pure part

## True when `encounter_id` is a UFO's encounter in world.json (the saucer battles).
static func is_abduction(encounter_id: StringName, defs: Defs) -> bool:
	var w: Variant = defs.json("world")
	if not (w is Dictionary): return false
	for u in w.get("ufos", []):
		if u is Dictionary and str(u.get("encounter", "")) == str(encounter_id): return true
	return false

## Bookkeeping when the beam takes the party: flags.times_abducted += 1 (read by the ending
## card). Nothing is saved: combat never autosaves, so a reload goes back to before the beam.
static func begin_abduction(state: GameState, rng: Rng, defs: Defs) -> Array[Dictionary]:
	var n: int = int(state.flags.get("times_abducted", 0)) + 1
	return Rules.run([["set_flag", "times_abducted", n]], state, rng, defs)

## What happens after Encounters.apply_battle_result. Returns
## {events, wake_events, mode, args, wake}: `events` are already applied (broadcast them now),
## `wake_events` are Fanfi's lines for the wake-up card, `mode`/`args` replace the battle's
## return target when mode is not &"", `wake` is "", "crash", "forest" or "temple".
## - UFO battle won: pages carried in the loot are read on the spot, the party lands next to
##   the crash site, which is discovered. (The UFO itself is already gone.)
## - UFO battle lost or timed out: everyone wakes with 1 HP in a random revealed forest cell,
##   minus half the food. (The UFO is already back on patrol, with a grace period.)
## - Any other battle lost: defeat{}, wake at Sarmizegetusa's temple, a third of the gold gone.
static func after_battle(encounter_id: StringName, result: Dictionary, state: GameState, rng: Rng, defs: Defs) -> Dictionary:
	var out: Dictionary = {"events": [] as Array[Dictionary], "wake_events": [] as Array[Dictionary],
		"mode": &"", "args": {}, "wake": ""}
	var outcome: String = str(result.get("outcome", ""))
	if is_abduction(encounter_id, defs):
		if outcome == "win": _saucer_down(result, state, rng, defs, out)
		else: _saucer_dump(state, rng, defs, out)
	elif outcome == "lose":
		_temple(state, rng, defs, out)
	return out

static func _saucer_down(result: Dictionary, state: GameState, rng: Rng, defs: Defs, out: Dictionary) -> void:
	var ev: Array[Dictionary] = out.events
	var loot: Variant = result.get("loot", {})
	if loot is Dictionary:
		var ids: Array = (loot as Dictionary).keys()
		ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for item in ids:
			if not defs.has(&"item", StringName(str(item))): continue
			for fx in defs.get_def(&"item", StringName(str(item))).get("use_effects", []):
				if fx is Array and fx.size() == 2 and str(fx[0]) == "page":
					ev.append_array(Rules.run([["page", str(fx[1])]], state, rng, defs))
	var crash: Dictionary = Rules.location(CRASH_LOCATION, defs)
	if not crash.is_empty():
		var c: Vector2i = Rules.to_cell(crash.get("cell", []))
		var land: Vector2i = c
		for d in AROUND:
			if Travel.passable(c + d, defs):
				land = c + d
				break
		state.world_pos = land
		ev.append_array(Rules.run([["discover", str(CRASH_LOCATION)]], state, rng, defs))
		var cells: Array[Vector2i] = Rules.reveal_around(state, land, 2, defs)
		if not cells.is_empty(): ev.append({"type": "revealed", "cells": cells})
	out.mode = &"worldmap"
	out.wake = "crash"
	out.wake_events = _line(CRASH_LINES, 0)

static func _saucer_dump(state: GameState, rng: Rng, defs: Defs, out: Dictionary) -> void:
	var ev: Array[Dictionary] = out.events
	for m in state.party: m.hp = 1
	ev.append_array(Rules.run([["food", -(state.food / 2)]], state, rng, defs))
	state.world_pos = forest_cell(state, rng, defs)
	out.mode = &"worldmap"
	out.wake = "forest"
	out.wake_events = _line(FOREST_LINES, int(state.flags.get("times_abducted", 1)) - 1)

static func _temple(state: GameState, rng: Rng, defs: Defs, out: Dictionary) -> void:
	var ev: Array[Dictionary] = out.events
	ev.append({"type": "defeat"})
	for m in state.party: m.hp = maxi(m.hp, 1)
	ev.append_array(Rules.run([["gold", -(state.gold / 3)]], state, rng, defs))
	var n: int = int(state.flags.get("times_defeated", 0))
	ev.append_array(Rules.run([["set_flag", "times_defeated", n + 1]], state, rng, defs))
	var loc_id: StringName = TEMPLE_LOCATION
	var cell: Variant = TEMPLE_CELL
	var loc: Dictionary = Rules.location(loc_id, defs)
	if loc.is_empty():
		# Content without Sarmizegetusa (test fixtures): the world's start location.
		var w: Variant = defs.json("world")
		loc_id = StringName(str(w.get("start", ""))) if w is Dictionary else &""
		loc = Rules.location(loc_id, defs)
		cell = Rules.to_cell(loc.entry_cell) if loc.has("entry_cell") else null
	if not loc.is_empty(): state.world_pos = Rules.to_cell(loc.get("cell", []))
	out.mode = &"location"
	out.args = {"location_id": loc_id}
	if cell != null: out.args["cell"] = cell
	out.wake = "temple"
	out.wake_events = _line(DEFEAT_LINES, n)

## A random revealed, passable forest cell (sorted first, so the pick is reproducible), else
## the start location's cell, else where the party is.
static func forest_cell(state: GameState, rng: Rng, defs: Defs) -> Vector2i:
	var cells: Array[Vector2i] = []
	for k in state.revealed:
		var parts: PackedStringArray = str(k).split(",")
		if parts.size() != 2: continue
		var c := Vector2i(int(parts[0]), int(parts[1]))
		if Travel.hides(c, defs) and Travel.passable(c, defs): cells.append(c)
	if cells.is_empty():
		var w: Variant = defs.json("world")
		var start: Dictionary = Rules.location(StringName(str(w.get("start", ""))), defs) if w is Dictionary else {}
		return Rules.to_cell(start.cell) if start.has("cell") else state.world_pos
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells[rng.randi_range(0, cells.size() - 1)]

static func _line(lines: Array[String], i: int) -> Array[Dictionary]:
	return [{"type": "narrator", "line_key": lines[posmod(i, lines.size())]}]

# ---------------------------------------------------------------- scenes

## Menu Begin: a fresh game, straight into Sarmizegetusa (autosaved as location), with Fanfi's
## séance on top. The séance reads Fanfi's new_game lines in order and marks them as said, so
## the new_game{} event it broadcasts at the end does not make the caption repeat them.
static func start_new_game(seed_value: int, hero_class: StringName) -> Node:
	Game.new_game(seed_value, hero_class)
	var lines: Array[String] = seance_lines(Content.defs)
	for k in lines:
		if k.begins_with("fanfi_"): Game.state.flags[Narrator.ONCE_PREFIX + k] = true
	Router.go(&"location", {"location_id": Game.state.location_id})
	var done := func() -> void: Bus.emit_events([{"type": "new_game"}])
	if not overlays_enabled:
		done.call()
		return null
	var s: Node = SeanceOverlay.new()
	s.lines = lines
	s.finished.connect(done)
	_root().add_child(s)
	return s

## The séance script: staging, Fanfi's new_game lines (fanfi.json, in order), the wake-up.
static func seance_lines(defs: Defs) -> Array[String]:
	var out: Array[String] = ["flow_seance_place", "flow_seance_medium"]
	var fanfi: Variant = defs.json("fanfi")
	if fanfi is Dictionary:
		for entry in fanfi.get("new_game", []):
			if entry is Dictionary:
				for k in entry.get("lines", []): out.append(str(k))
	out.append("flow_seance_wake")
	return out

## World map, on `abducted`: counts the abduction, plays the beam over `screen_pos` and the
## white-out, switches the music to the saucer and starts the UFO's battle (which brings its
## own rules: magic off, floaty gravity, the self-destruct turn limit). Returns the overlay.
static func play_abduction(ufo_id: StringName, encounter: StringName, screen_pos: Vector2) -> Node:
	Bus.emit_events(begin_abduction(Game.state, Game.rng, Content.defs))
	var go := func() -> void:
		Audio.play_music(&"saucer")
		Router.go(&"combat", {"encounter_id": encounter, "return_mode": &"worldmap", "return_args": {},
			"ufo": ufo_id})
	Audio.stinger(&"abduction")
	Audio.sfx(&"beam")
	if not overlays_enabled:
		go.call()
		return null
	var b: Node = BeamOverlay.new()
	b.screen_pos = screen_pos
	b.instant = instant
	b.whited_out.connect(go)
	_root().add_child(b)
	return b

## After the battle's Router.go: the wake-up card for after_battle()'s `wake`, which then
## broadcasts the `wake_events` (Fanfi's line). Without a wake, nothing happens.
static func show_wake(after: Dictionary) -> Node:
	var kind: String = str(after.get("wake", ""))
	if kind == "": return null
	var evs: Array[Dictionary] = []
	evs.assign(after.get("wake_events", []))
	if not overlays_enabled:
		Bus.emit_events(evs)
		return null
	var w: Node = WakeOverlay.new()
	w.kind = kind
	w.wake_events = evs
	w.instant = instant
	_root().add_child(w)
	return w

## Overlays live under the Hud autoload: it outlives every scene change, and unlike the tree
## root it is never busy setting up children.
static func _root() -> Node:
	return Hud
