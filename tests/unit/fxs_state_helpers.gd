## Shared builders for the WP-10/WP-11 tests (not a test file itself).
extends RefCounted

## A state with 3 characters, 5 items, 4 flags, 2 UFOs and something in every field.
static func full(defs: Defs) -> GameState:
	var s := GameState.new()
	s.seed = 7
	s.rng_state = 9007199254740993   # above 2^53: must survive JSON
	s.day = 3; s.hour = 21; s.food = 5; s.gold = 60
	var knight: Dictionary = defs.get_def(&"class", &"fx_knight")
	var necro: Dictionary = defs.get_def(&"class", &"fx_necro")
	s.party.append(Character.create(&"hero", knight, "hero_name"))
	s.party.append(Character.create(&"fx_priest", necro, "fx_npc_priest"))
	s.party.append(Character.create(&"fx_other", necro, "fx_npc_priest"))
	s.party[0].gain_xp(150, knight)
	s.party[1].hp = 2
	s.inventory = {&"fx_sword": 1, &"fx_bread": 3, &"fx_cell": 2, &"fx_a": 4, &"fx_b": 5}
	s.flags = {"met": true, "count": 3, "name": "olt", "enc_cooldown": 0}
	s.quests = {&"fx_quest": 10}
	s.pages = [&"fx_page_1"]
	s.world_pos = Vector2i(4, 5)
	s.revealed = {"4,5": true, "4,6": true}
	s.discovered = [&"fx_town"]
	s.ufos = [
		{"id": &"fx_ufo", "pos": Vector2i(3, 6), "state": "patrol", "route_i": 0},
		{"id": &"fx_ufo2", "pos": Vector2i(8, 4), "state": "chase", "route_i": 2},
	]
	s.mode = &"location"
	s.location_id = &"fx_town"
	s.location_cell = Vector2i(3, 3)
	return s
