## Golden path as a Knight that takes a non-combat option wherever one exists (it still fights
## the cave ambushes and the saucer, which offer nothing else). Its level must end within 1 of
## the Necromancer's run, which fights everything it can: XP does not come from kills.
extends TestCase

const GoldenPath := preload("res://tests/bot/golden_path.gd")
const Necro := preload("res://tests/bot/test_golden_path.gd")

var knight: Dictionary
var necro: Dictionary

func before_all() -> void:
	knight = GoldenPath.run(&"knight", true)
	Necro.print_route(knight, "knight, pacifist")
	necro = GoldenPath.run(&"necromancer", false)

func after_all() -> void:
	Game.state = GameState.new()
	Game.rng = Rng.new(0)

func test_route_completes() -> void:
	assert_true(knight.ended, "route did not finish")
	assert_eq(knight.bot.problems, [])
	assert_false(knight.bot.stats.saucer_forced, "saucer win was synthetic: %s" % [knight.bot.stats.saucer_results])
	assert_true(knight.bot.stats.saucer_won_in_battle)
	assert_eq(knight.bot.state.pages.size(), 12)
	assert_eq(int(knight.bot.state.quests.get(&"dead_dont_pay_taxes", 0)), 100)
	assert_eq(int(knight.bot.state.quests.get(&"delivery_in_188_hours", 0)), 100)

func test_never_chose_to_fight() -> void:
	assert_false(knight.bot.stats.options.has("fight"), "options: %s" % [knight.bot.stats.options])

func test_fought_fewer_battles_than_the_necromancer() -> void:
	assert_true(int(knight.bot.stats.battles) < int(necro.bot.stats.battles),
		"knight %d battles, necromancer %d" % [knight.bot.stats.battles, necro.bot.stats.battles])

func test_level_within_one_of_the_necromancer() -> void:
	var k: int = knight.bot.state.party[0].level
	var n: int = necro.bot.state.party[0].level
	assert_true(absi(k - n) <= 1, "knight L%d, necromancer L%d" % [k, n])

func test_runs_under_a_minute() -> void:
	assert_true(int(knight.ms) < 60000, "took %d ms" % knight.ms)
