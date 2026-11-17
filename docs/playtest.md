# Playtest pass (WP-34)

Build: the Web export (`build/web`, served locally), Chromium at 1280x720, driven with Playwright
by mouse and keyboard. Seed 101, Necromancer, so the run can be compared with the bot's golden route.

## What was really played, and what was not

**Played by hand in the browser:** menu, new game, the séance, all of Sarmizegetusa (recruit
Vezina, both quests from Mucapor and Tsinna, Zia's story page, Dida's shop, the temple offering
box, the tavern cellar, the sun disc page, the old well), the town gate, the world map, one wolf
battle fought to the end (Bone Dart, Raise Strigoi on a wolf corpse, Vezina's heals), a second
wolf encounter settled with the Spirit option, the walk to the cave, and the first rounds of the
cave ambush. I reloaded the page between builds and used Continue, so the save and resume path
was used too.

**Not played by hand:** Duras, the graves fight, the road east, the abduction, the saucer battle,
the crash site and the last pages. For those this report relies on the bot (`tools/test.sh
tests/bot`, the golden route in `docs/handoff/WP-31.md`), which finishes with 12 pages, both
quests at 100 and the saucer beaten in a real battle, for both classes. The abduction, saucer
and wake-up flows are covered by `tests/integration/test_flow.gd` and the combat view smoke tests.

## Time estimate

- Town: about 6 to 8 minutes for a first-timer (5 conversations, 4 containers, a shop).
- One hand-played battle: 3 to 5 minutes with the animations (the wolf fight took me 6 rounds).
- Travel and encounter panels are fast in real time, a few seconds per leg.
- Bot routes: the pacifist Knight finishes with 4 battles and 69 world steps; the Necromancer who
  fights by choice needs 17 battles, 231 steps and 17 in-game days.

A player who talks, sneaks and bribes their way through (the Knight-like route) lands at about
**20 to 30 minutes**, on target. A player who picks Fight every time needs **45 to 60 minutes**
and will probably wake at the temple at least once. Expect a first run somewhere around 30 to 40.

## Checklist: spec "In scope"

| Item | Result |
|---|---|
| One region with travel, fog of war, 3 discoverable locations | Met. Town, cave, crash site; fog clears around the party. |
| One town with 5 to 8 NPCs, a trader, a healer, 2 short quests | Met. 7 NPCs (Vezina, Dida, Zia, Mucapor, Tsinna, Rholes, Bitus); Dida trades, Vezina heals; 2 quests. |
| One outskirts area or cave with a small dungeon | Met. The cave under the hill: ambush, graves, Duras, crate. |
| 2 playable classes plus 1 recruitable companion | Met. Knight, Necromancer; Vezina joins. |
| AP combat, 6 to 8 abilities, 4 to 5 enemy types | Met. Played: AP pips, 4 equipped abilities plus items, wolves and a strigoi; the rest by tests and data. |
| Random encounter table, 3 to 4 types | Met. Wolves twice by hand; bot meets deserters, trader, wolves and more. |
| One UFO abduction with its mini-boss arena | Met by bot and tests, not by hand. |
| One music track with explore and combat layers, ambience, SFX | Partial. Heard nothing (headless browser); files and layer tests exist. Needs a human ear. |
| Save and load, main menu, settings | Met. Autosave + Continue used across reloads; Scroll save tab seen; settings screen seen. |
| Scroll as goal and save screen; XP not from kills | Met. 12-page scroll; XP came from pages and the encounter, never from kills. |
| Magic off and broken gravity in the saucer | Met by tests (`test_battle`, saucer smoke), not by hand. |
| Gore Off / Normal / Bloody Mess | Partial. Normal seen (gibs, splatter). Off and Bloody Mess not looked at in this pass; presentation-only is covered by tests. |
| Fanfi as narrator | Met. Captions on pages, recruits, quests, gibs; now placed so they never cover answers or buttons. |

## Checklist: Global Constraints

| Constraint | Result |
|---|---|
| Godot 4.5.1, GDScript only, typed signatures | Met. |
| Core is pure (no Node, autoloads, files, clock, global random) | Met. Lint test green. |
| 640x360 base, integer scaling, nearest filtering | Met. Crisp pixels at 1280x720. |
| 64x32 tiles, 32x48 humans, giants with 2x2 feet | Met for what was seen; giants not seen by hand. |
| No player-facing string literals | Met. Validator green. |
| XP never from kills | Met. |
| Every encounter offers at least 2 options, fight and flee kept | Met. The wolves offered 5. |
| At most 4 equipped abilities | Met. Party screen shows "Abilities 4/4". |
| Gore is presentation only | Met by tests. |
| Tone: deadpan narrator, one meme per scene at most | Met in what I read. Some Fanfi lines repeat (see rough list). |
| Base 12: 12 pages, prices in 12s | Met. Dida's prices are all multiples of 12. |
| Small commits, tests green | Met. 421 unit/integration, 26 bot, validator 0 errors. |

## Broken and fixed

| Commit | What was wrong |
|---|---|
| afb0fdf | Menu subtitle read "Daciá": a background star sat right on the letter. No stars behind the title now. |
| ae95352 | Space to skip the typewriter landed on answer 1 and picked it (Vezina healed us unasked). Arrows now focus answers; a lone Continue still takes Space. |
| 9a39e5e | Vezina joined but did not follow until the next map load. |
| b252b3f | New-game panel and séance text was light-on-parchment (a stale theme cache dropped the ink). Also 14 px panel padding so first letters stop touching the frame. |
| 02d2a7c, 680cd9b | Fanfi's caption covered dialogue answers and the combat ability bar (and ate their clicks). It moves to the top while either is open. |
| 9c2c6c6 | Dialogue speaker names and the settings heading were pale bronze on parchment. Red ink now. |
| 7466cf1 | The old well (a page and 12 gold) was completely hidden behind the town's south wall. Moved north of the river. |
| 80af5fb | Barrels, stalls and tables were drawn under units standing behind them. Their upper half is y-sorted now. |
| 720fdb1 | The logbook and shard stayed in the pack after their pages were read; waking in the forest or temple took no time (now 4 h and 8 h). |
| acd91dd, 48a6144 | "Resources still in use" at exit: `Audio.quit()` stops music first (menu Quit, window close, test runner). |
| 7af5cef | WASD walked along the grid, so W went up-right. Keys are screen directions now; W+D is one diagonal step. |
| eaef392 | Combat HUD printed "Vezina, Priest of Zalmoxis" under the AP pips. |
| 41bf4ad | The Round counter stayed at 1 in untimed battles. |
| 2d25431 | An encounter's outcome text was shown twice: in the panel and again in Fanfi's caption. |
| a224f54 | "The Cave Under the Hill" label covered "Sarmizegetusa Regia" on the world map. |

## Rough but OK for now

- Long ability names are cut on the combat buttons ("Blessing of Zalmo", "Reanimate Dr"). The hover tip has the full name.
- The combat hover tooltip often sits on top of the unit you are about to act with.
- Trees at the edge of the forest arena can hide a wolf completely; only its HP bar shows. Units behind tall pillars in the sanctuary vanish too (no outline).
- Healing outside battle exists only at Vezina in town, and HP does not come back after a won fight. After the first wolf fight the hero was at 6/22 with two days of forest between him and the temple. The pacifist options are the sane route; new players will not know that.
- The walk from town to the cave through forest took two in-game days and 4 food for a target 3 cells away. Fine for food (12 at start), but it feels slow.
- Fanfi repeats a few lines ("Another page. Mirg's book of fates..." twice in ten minutes). Who Mirg is is never explained in the slice.
- Zia shares Bitus's sprite (a man in green) while the portrait and text read as a woman.
- The bridge over the town river now leads to a strip hidden behind the wall (harmless, nothing there).
- The world map shows very little until explored; at first it is three islands in black.
- The Fanfi caption at the top of combat can cover units standing on the top rows. Clicking it skips it.
- Headless test runs can still print "resources still in use" now and then (playbacks stopped during tests that the dummy audio driver drops late). Real quits are clean.
- Music, ambience and SFX were not heard in this pass. Gore Off and Bloody Mess were not looked at.

## How to play the slice (for Cojo and the kid)

1. Open the game link in Chrome, Edge or Firefox on a computer. Click once on the page so the keyboard works.
2. **New Game**, pick the Knight (hits things) or the Necromancer (raises dead things), then **Begin**. Leave the seed empty.
3. In town, click the ground to walk, or use WASD/arrows (W walks up the screen). Stand next to a person or a box and press **E**.
4. Talk to everyone. The old priest Vezina in the temple heals you for free and can join you. Mucapor and Tsinna give you the two jobs. Open every box and barrel.
5. Walk out of the south gate to the world map. Click a place to see how long it takes, click again to go.
6. When something blocks the road, you choose: fight, run, or a smarter option (with its chance shown). **Smart options are usually better than fighting**, and you get experience either way.
7. In a fight: press 1 to 5 to pick an action, click a target, Space ends your turn, Tab speeds it up. If you lose, you wake up in the temple: no game over.
8. The goal is the 12 missing pages of the scroll (button top right). The scroll is also where you save.
9. Something odd in the sky will find you eventually. Let it.

Tell us what broke, what confused you, and what was funny. A screenshot helps.
