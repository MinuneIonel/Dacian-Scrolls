## Golden path, Necromancer, seed 101, real data/: the whole slice through the core in one go.
## The run happens once (GoldenPath caches it); each test checks one part of the ending state.
extends TestCase

const GoldenPath := preload("res://tests/bot/golden_path.gd")
const ALL_PAGES: int = 12

var run: Dictionary
var bot

func before_all() -> void:
	run = GoldenPath.run(&"necromancer", false)
	bot = run.bot
	print_route(run, "necromancer")

func after_all() -> void:
	Game.state = GameState.new()
	Game.rng = Rng.new(0)

static func print_route(r: Dictionary, label: String) -> void:
	var b = r.bot
	print("  --- golden path (%s), %d ms ---" % [label, int(r.ms)])
	for line in b.log: print("    " + line)
	var sim: Dictionary = b.stats.saucer_sim
	print("    stats: %s" % JSON.stringify(b.stats))
	if not sim.is_empty():
		print("    saucer win rate for this party (level %d, %d seeds): %.1f%% (%d timeouts)" % [
			sim.level, sim.n, sim.pct, sim.timeouts])
	var levels: Array[String] = []
	for m in b.state.party: levels.append("%s L%d (%d xp)" % [m.id, m.level, b.total_xp(m)])
	print("    party: %s; gold %d, food %d, day %d" % [", ".join(levels), b.state.gold, b.state.food, b.state.day])

func test_runs_under_a_minute() -> void:
	assert_true(int(run.ms) < 60000, "took %d ms" % run.ms)

func test_route_completes_without_problems() -> void:
	assert_true(run.ended, "route did not finish")
	assert_eq(bot.problems, [], "invariant breaches or stuck route")

func test_all_twelve_pages() -> void:
	assert_eq(bot.state.pages.size(), ALL_PAGES, "pages: %s" % [bot.state.pages])
	for p in Content.defs.all(&"page"): assert_has(bot.state.pages, StringName(str(p.id)))

func test_both_quests_done() -> void:
	assert_eq(int(bot.state.quests.get(&"dead_dont_pay_taxes", 0)), 100)
	assert_eq(int(bot.state.quests.get(&"delivery_in_188_hours", 0)), 100)
	assert_false(bot.state.inventory.has(&"strigoi_taxes"))
	assert_false(bot.state.inventory.has(&"lobizi_parcel"))

func test_healer_recruited_and_party_standing() -> void:
	var ids: Array = bot.state.party.map(func(m: Character) -> StringName: return m.id)
	assert_eq(ids, [&"hero", &"vezina"])
	assert_eq(bot.state.party[0].class_id, &"necromancer")
	assert_eq(bot.state.party[1].class_id, &"healer")
	for m in bot.state.party:
		assert_true(m.hp >= 1, "%s at %d HP" % [m.id, m.hp])
		assert_eq(m.level, bot.state.party[0].level, "shared XP keeps levels together")
	assert_true(bot.state.party[0].level >= 3, "level %d" % bot.state.party[0].level)

func test_abducted_and_saucer_down() -> void:
	assert_true(int(bot.state.flags.get("times_abducted", 0)) >= 1)
	assert_eq(bot.state.flags.get("won_saucer_surgeon", false), true)
	for u in bot.state.ufos: assert_eq(u.state, "gone")
	assert_has(bot.state.discovered, &"crash_site")
	assert_has(bot.state.discovered, &"strigoi_cave")

func test_back_home_in_town() -> void:
	assert_true(bot.at_location(&"sarmizegetusa"), "ended at %s" % bot.state.world_pos)
	assert_true(bot.state.food >= 0)

## KNOWN BALANCE BLOCKER (2026-11): the saucer_surgeon battle is near-unwinnable for this
## party, so the bot applies a synthetic win after its real attempts to check the rest of the
## route. This single test fails until the balance change lands; its message gives the rates.
func test_saucer_won_in_real_battle() -> void:
	var sim: Dictionary = bot.stats.saucer_sim
	assert_true(bot.stats.saucer_won_in_battle,
		"BALANCE BLOCKER: saucer lost %d/%d real attempts (%s); win rate at level %d: %.1f%% over %d seeds" % [
			bot.stats.saucer_attempts, bot.stats.saucer_attempts, ", ".join(bot.stats.saucer_results),
			int(sim.get("level", 0)), float(sim.get("pct", 0.0)), int(sim.get("n", 0))])
