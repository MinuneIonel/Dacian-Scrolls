## Owns the live GameState and the game's Rng. Saves and loads.
extends Node

const SAVE_PATTERN: String = "user://save_%d.json"
const SLOTS: int = 4   # 0 is the autosave, 1..3 manual
const START_FOOD: int = 12
const START_GOLD: int = 24
const START_REVEAL: int = 2

var state: GameState = GameState.new()
var rng: Rng = Rng.new(0)
var save_dir_override: String = ""   # tests point saves elsewhere

## Fresh game: hero of the given class, starting food/gold, UFOs seeded, at Sarmizegetusa.
func new_game(seed_value: int, hero_class: StringName) -> void:
	var defs: Defs = Content.defs
	var s := GameState.new()
	s.seed = seed_value
	s.food = START_FOOD
	s.gold = START_GOLD
	s.day = 1
	s.hour = 8
	s.party.append(Character.create(&"hero", defs.get_def(&"class", hero_class), "hero_name"))
	var world: Variant = defs.json("world")
	if not (world is Dictionary): world = {}
	var start: StringName = StringName(str(world.get("start", "")))
	var loc: Dictionary = Rules.location(start, defs)
	if loc.is_empty(): push_error("Game.new_game: world.json has no start location '%s'" % start)
	s.world_pos = Rules.to_cell(loc.get("cell", []))
	Rules.reveal_around(s, s.world_pos, START_REVEAL, defs)
	if start != &"": s.discovered.append(start)
	for u in world.get("ufos", []):
		var route: Array = u.get("route", [])
		s.ufos.append({"id": StringName(str(u.get("id", ""))),
			"pos": Rules.to_cell(route[0] if not route.is_empty() else []),
			"state": "patrol", "route_i": 0})
	s.mode = &"location"
	s.location_id = start
	s.location_cell = Rules.to_cell(loc.get("entry_cell", []))
	state = s
	rng = Rng.new(seed_value)

## Writes to a temp file then renames it over the slot, so a crash cannot destroy a save.
func save(slot: int) -> Error:
	if slot < 0 or slot >= SLOTS:
		push_error("Game.save: bad slot %d" % slot)
		return ERR_INVALID_PARAMETER
	state.rng_state = rng.get_state()
	var path: String = save_path(slot)
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var mk: Error = DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK: return mk
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(SaveCodec.encode(state))
	f.flush()
	var werr: Error = f.get_error()
	f.close()
	if werr != OK:
		DirAccess.remove_absolute(tmp)
		return werr
	return DirAccess.rename_absolute(tmp, path)

## On failure returns an error and leaves `state` untouched; the reason key goes to Bus.toast.
func load_slot(slot: int) -> Error:
	if slot < 0 or slot >= SLOTS or not has_save(slot):
		Bus.toast.emit(SaveCodec.CORRUPT)
		return ERR_FILE_NOT_FOUND
	var text: String = FileAccess.get_file_as_string(save_path(slot))
	var r: Dictionary = SaveCodec.decode(text)
	if not r.ok:
		Bus.toast.emit(str(r.error_key))
		return ERR_FILE_CORRUPT
	state = r.state
	rng.set_state(state.rng_state)
	return OK

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(save_path(slot))

func save_path(slot: int) -> String:
	if save_dir_override != "": return save_dir_override.path_join("save_%d.json" % slot)
	return SAVE_PATTERN % slot

## Applies events' side effects that live outside core (narrator, toasts) by broadcasting them.
func broadcast(events: Array[Dictionary]) -> void:
	Bus.emit_events(events)
