## The golden path (WP-31): new game with seed 101, recruit Vezina, both quests, the fast road,
## the abduction and the saucer, all 12 pages. Pure core through the Bot; the result of each
## class's run is cached for the whole test process (the Knight test compares with the
## Necromancer run without playing it twice).
extends RefCounted

const Bot := preload("res://tests/bot/bot.gd")
const SEED: int = 101

static var _cache: Dictionary = {}

## {bot, ms, ended: bool} for a class; plays it once per process.
static func run(hero_class: StringName, pacifist: bool) -> Dictionary:
	var key: String = "%s:%s" % [hero_class, pacifist]
	if _cache.has(key): return _cache[key]
	var t0: int = Time.get_ticks_msec()
	Game.new_game(SEED, hero_class)
	var bot = Bot.new(Game.state, Game.rng, Content.defs)
	bot.pacifist = pacifist
	var ended: bool = play(bot)
	var out: Dictionary = {"bot": bot, "ms": Time.get_ticks_msec() - t0, "ended": ended}
	_cache[key] = out
	return out

## The route. Each phase loops until its goal holds, so a lost battle (wake at the temple) or
## a detour just sends the bot round again. Returns false if a phase gives up.
static func play(bot) -> bool:
	var s: GameState = bot.state
	bot.note("new game as %s" % s.party[0].class_id)
	# 1. Sarmizegetusa: Vezina joins, the four containers, Zia's story, both quests start.
	bot.talk(&"vezina", ["dlg_vezina_hello_c3"] as Array[String])
	for c in ["sun_disc_page", "old_well", "temple_offering_box", "tavern_cellar"]:
		bot.open_container(Bot.TOWN, c)
	bot.talk(&"zia", ["dlg_zia_hello_c2"] as Array[String])
	bot.talk(&"mucapor", ["dlg_mucapor_hello_c0"] as Array[String])
	bot.talk(&"tsinna", ["dlg_tsinna_hello_c0", "dlg_tsinna_explain_c0", "dlg_tsinna_explain2_c0"] as Array[String])
	# 2. The strigoi cave: both ambushes, Duras (talked round, or fought), the crypt crate.
	var tries: int = 0
	while int(s.quests.get(&"dead_dont_pay_taxes", 0)) < 50 and tries < 8:
		tries += 1
		if not bot.travel_to_location(Bot.CAVE): continue
		bot.fire_trigger(Bot.CAVE, "ambush_wolves")
		if not bot.at_location(Bot.CAVE): continue        # lost: woke up at the temple
		bot.fire_trigger(Bot.CAVE, "graves_open")
		if not bot.at_location(Bot.CAVE): continue
		bot.open_container(Bot.CAVE, "crypt_crate")
		if bot.npc_visible(Bot.CAVE, "duras"):
			bot.talk(&"duras", duras_choices(bot))
		bot.open_container(Bot.CAVE, "duras_coffin")    # only after Duras lost the fight
	if int(s.quests.get(&"dead_dont_pay_taxes", 0)) < 50: return _gave_up(bot, "cave")
	# 3. Back to town: Mucapor's taxes are paid.
	if not _to_town(bot): return false
	bot.talk(&"mucapor", ["dlg_mucapor_hello_c2"] as Array[String])
	bot.rest_in_town()
	# 4. The fast road east, until the saucer takes the party and loses.
	tries = 0
	while not bool(s.flags.get("won_saucer_surgeon", false)) and tries < 6:
		tries += 1
		if tries > 1:
			if not _to_town(bot): return false
			bot.rest_in_town()
		var before: int = bot.stats.abductions
		if bot.stats.saucer_sim.is_empty():
			bot.stats.saucer_sim = bot.saucer_win_rate(40)
		bot.travel_to_location(Bot.CRASH)
		if bot.stats.abductions == before: bot.loiter_for_abduction()
	if not bool(s.flags.get("won_saucer_surgeon", false)): return _gave_up(bot, "saucer")
	# 5. The crash site: Ozo leaves (or is fought), the parcel, the flight recorder.
	tries = 0
	while int(s.quests.get(&"delivery_in_188_hours", 0)) < 60 and tries < 6:
		tries += 1
		if not bot.travel_to_location(Bot.CRASH): continue
		bot.open_container(Bot.CRASH, "flight_recorder")
		if bot.npc_visible(Bot.CRASH, "ozo"): bot.talk(&"ozo", ozo_choices(bot))
		if not bot.at_location(Bot.CRASH): continue
		bot.open_container(Bot.CRASH, "parcel")
	if int(s.quests.get(&"delivery_in_188_hours", 0)) < 60: return _gave_up(bot, "crash site")
	# 6. Tsinna gets her parcel.
	if not _to_town(bot): return false
	bot.talk(&"tsinna", ["dlg_tsinna_hello_c2"] as Array[String])
	bot.rest_in_town()
	# 7. The road pages: the trader and the deserters, met on the quiet southern road.
	var legs: int = 0
	while (not s.pages.has(&"page_trader") or not s.pages.has(&"page_deserters")) and legs < 60:
		bot.travel_to(Bot.SOUTH_ROAD[legs % 2], 80)
		legs += 1
		if bot.party_hurt() and bot.at_location(Bot.TOWN): bot.rest_in_town()
	# 8. Home for the night.
	_to_town(bot)
	bot.rest_in_town()
	bot.note("done: %d pages" % s.pages.size())
	return s.pages.size() == 12

static func _to_town(bot) -> bool:
	if bot.travel_to_location(Bot.TOWN): return true
	return _gave_up(bot, "town")

static func _gave_up(bot, phase: String) -> bool:
	bot.problems.append("route gave up at: " + phase)
	bot.note("gave up: " + phase)
	return false

## Necromancer: the necromancer's bargain. Pacifist Knight: the spirit roll (best odds), and
## the fight only once Duras has refused to talk.
static func duras_choices(bot) -> Array[String]:
	var s: GameState = bot.state
	if Rules.check([["class", "necromancer"]], s, bot.defs): return ["dlg_duras_hello_c1"] as Array[String]
	if bool(s.flags.get("duras_refused", false)): return ["dlg_duras_hello_c2"] as Array[String]
	return ["dlg_duras_hello_c0", "dlg_duras_taxes_c1"] as Array[String]

## The strigoi ally if the Necromancer has it, a bribe if affordable, the wits roll, and the
## fight only when nothing else is left.
static func ozo_choices(bot) -> Array[String]:
	var s: GameState = bot.state
	if bool(s.flags.get("strigoi_ally", false)): return ["dlg_ozo_hello_c2"] as Array[String]
	if s.gold >= 36: return ["dlg_ozo_hello_c0"] as Array[String]
	if not bool(s.flags.get("ozo_doubts", false)): return ["dlg_ozo_hello_c1"] as Array[String]
	return ["dlg_ozo_hello_c3"] as Array[String]
