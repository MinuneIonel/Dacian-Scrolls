## Every dialogue in data/, walked 50 times with random visible choices from randomised states
## (class, party, gold, quest stages, quest items, flags), so the conditional branches open up.
## No walk may need 200 steps, and no node may be left without a visible choice.
extends TestCase

const WALKS: int = 50
const MAX_STEPS: int = 200
const FLAGS: Array[String] = ["duras_refused", "duras_convinced", "strigoi_ally", "strigoi_ally_taken",
	"won_cave_strigoi", "duras_talked", "ozo_doubts", "ozo_freed", "ozo_gone", "won_crash_thrall"]
const ITEMS: Array[StringName] = [&"strigoi_taxes", &"lobizi_parcel", &"bread"]

var defs: Defs

func before_all() -> void:
	defs = Content.defs

func after_all() -> void:
	Game.state = GameState.new()
	Game.rng = Rng.new(0)

func test_data_has_the_dialogues() -> void:
	assert_true(defs.all(&"dialogue").size() >= 9, "dialogues: %d" % defs.all(&"dialogue").size())

func test_random_walks_end_and_never_dead_end() -> void:
	var r: Dictionary = _walk_all(WALKS, 4242)
	print("    fuzz_dialogue: %d walks, longest %d steps, %d of %d nodes visited" % [r.walks, r.longest,
		r.seen, r.total])
	assert_eq(r.problems, [] as Array[String])

## Coverage: with enough walks every node of every dialogue is reached (no orphan nodes).
func test_every_node_is_reachable() -> void:
	var r: Dictionary = _walk_all(600, 777)
	assert_eq(r.problems, [] as Array[String])
	assert_eq(r.unseen, [] as Array[String], "never reached in %d walks" % r.walks)

func _walk_all(walks_each: int, seed_value: int) -> Dictionary:
	var fz := Rng.new(seed_value)
	var problems: Array[String] = []
	var walks: int = 0
	var longest: int = 0
	var nodes_seen: Dictionary = {}
	for d in defs.all(&"dialogue"):
		var id := StringName(str(d.id))
		for w in walks_each:
			var state: GameState = _random_state(fz)
			var rng := Rng.new(fz.randi_range(1, 1 << 30))
			var r := DialogueRunner.new(id, state, rng, defs)
			r.start()
			var steps: int = 0
			while not r.is_done() and steps < MAX_STEPS:
				var cur: Dictionary = r.current()
				nodes_seen["%s:%s" % [id, cur.text_key]] = true
				var choices: Array = cur.get("choices", [])
				if choices.is_empty():
					problems.append("%s walk %d: dead end at %s" % [id, w, cur.text_key])
					break
				r.choose(int(choices[fz.randi_range(0, choices.size() - 1)].index))
				steps += 1
			if not r.is_done() and steps >= MAX_STEPS:
				problems.append("%s walk %d: still talking after %d steps" % [id, w, MAX_STEPS])
			longest = maxi(longest, steps)
			walks += 1
	var total: int = 0
	var unseen: Array[String] = []
	for d in defs.all(&"dialogue"):
		var nodes: Dictionary = d.get("nodes", {})
		total += nodes.size()
		for n in nodes:
			if not nodes_seen.has("%s:%s" % [d.id, nodes[n].get("text_key", "")]): unseen.append("%s.%s" % [d.id, n])
	return {"problems": problems, "walks": walks, "longest": longest, "seen": nodes_seen.size(),
		"total": total, "unseen": unseen}

func _random_state(fz: Rng) -> GameState:
	var s := GameState.new()
	var cls: StringName = [&"knight", &"necromancer", &"healer"][fz.randi_range(0, 2)]
	s.party.append(Character.create(&"hero", defs.get_def(&"class", cls), "hero_name"))
	if fz.chance(0.5): Rules.recruit(s, &"vezina", defs)
	s.gold = [0, 11, 12, 24, 35, 36, 80][fz.randi_range(0, 6)]
	s.food = fz.randi_range(0, 12)
	s.hour = fz.randi_range(0, 23)
	for q in defs.all(&"quest"):
		var stages: Array = [0]
		for k in (q.get("stages", {}) as Dictionary).keys(): stages.append(int(k))
		s.quests[StringName(str(q.id))] = int(stages[fz.randi_range(0, stages.size() - 1)])
	for f in FLAGS:
		if fz.chance(0.25): s.flags[f] = true
	for item in ITEMS:
		if fz.chance(0.3): s.inventory[item] = 1
	for p in defs.all(&"page"):
		if fz.chance(0.3): s.pages.append(StringName(str(p.id)))
	return s
