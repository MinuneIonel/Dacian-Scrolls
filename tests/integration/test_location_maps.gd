## Location mode on the real maps: every entity can be reached from the entry, and the scene
## builds for every world location without engine errors.
extends TestCase

const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var _old_state: GameState
var _old_save_fn: Callable

func after_all() -> void:
	Audio.stop_music(0.0)

func before_each() -> void:
	_old_state = Game.state
	_old_save_fn = Router.save_fn
	Router.switch_scenes = false
	Router.save_fn = func(_slot: int) -> Error: return OK

func after_each() -> void:
	Game.state = _old_state
	Router.save_fn = _old_save_fn
	Router.switch_scenes = true
	Router.args = {}

func _locations() -> Array:
	return Content.defs.json("world").get("locations", [])

func test_world_has_the_three_slice_locations() -> void:
	var ids: Array = []
	for l: Dictionary in _locations(): ids.append(str(l.id))
	for want in ["sarmizegetusa", "strigoi_cave", "crash_site"]: assert_has(ids, want)

func test_every_entity_is_reachable_from_the_entry() -> void:
	for l: Dictionary in _locations():
		var map_def: Dictionary = Content.get_def(&"map", StringName(str(l.map)))
		var grid: Grid = Grid.from_map(map_def, Content.defs.json("tiles"))
		var blocked: Dictionary = {}
		for e: Dictionary in map_def.entities:
			if e.kind == "npc" or e.kind == "container": blocked[Rules.to_cell(e.cell)] = true
		var entry: Vector2i = Rules.to_cell(l.entry_cell)
		assert_true(grid.is_walkable(entry), "%s entry walkable" % l.id)
		var reached: Dictionary = grid.search(entry, -1, 1, blocked).cost
		for e: Dictionary in map_def.entities:
			var c: Vector2i = Rules.to_cell(e.cell)
			match str(e.kind):
				"npc", "container":
					var ok: bool = false
					for d in NEIGHBOURS: ok = ok or reached.has(c + d)
					assert_true(ok, "%s: %s %s at %s has no reachable neighbour" % [l.map, e.kind, e.id, c])
				"exit", "trigger", "spawn_ally":
					assert_true(reached.has(c), "%s: %s %s at %s unreachable" % [l.map, e.kind, e.id, c])

func test_scene_builds_for_every_world_location() -> void:
	Game.new_game(1, &"knight")
	Game.broadcast(Rules.run([["recruit", "vezina"]], Game.state, Game.rng, Content.defs))
	for l: Dictionary in _locations():
		Router.args = {"location_id": str(l.id)}
		var loc: Node2D = load("res://src/modes/location/location.tscn").instantiate()
		add_child(loc)
		await wait_frames(2)
		assert_eq(loc.map_id, StringName(str(l.map)))
		assert_eq(loc.leader_cell(), Rules.to_cell(l.entry_cell), str(l.id))
		assert_eq(loc.followers.size(), 1)
		assert_eq(loc.name_label.text, tr(str(Content.get_def(&"map", loc.map_id).name_key)))
		loc.free()
		await wait_frames(1)

func test_every_town_npc_dialogue_opens() -> void:
	Game.new_game(1, &"knight")
	Router.args = {"location_id": "sarmizegetusa"}
	var loc: Node2D = load("res://src/modes/location/location.tscn").instantiate()
	add_child(loc)
	await wait_frames(1)
	for id: String in loc.entities.keys():
		if loc.entities[id].kind != "npc": continue
		loc.talk(id)
		assert_not_null(loc.dialogue, id)
		assert_ne(loc.dialogue.text_label.text, "", id)
		loc.dialogue.close()
		await wait_frames(1)
	loc.free()
