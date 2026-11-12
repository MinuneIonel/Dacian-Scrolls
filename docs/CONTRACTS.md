# Contracts

Frozen interfaces every work package builds against. The code stubs in `src/` carry the exact
signatures; this file pins the **meaning**. Changing anything here is a contract change
(see `docs/plan.md` section 6.3): agents ask, the orchestrator edits.

## 1. Layers

| Layer | Path | May use |
|---|---|---|
| Core | `src/core/**` | Only other core classes, `Rng`, `Defs`, built-in value types. No `Node`, scene tree, autoloads, files, clock, global random. Enforced by `tests/unit/test_lint_core.gd`. |
| Content | `src/content_loader.gd`, `data/**` | Files. Produces a `Defs`. |
| Autoloads | `src/autoload/*` | Everything. Thin glue. |
| Views | `src/modes/**`, `src/ui/**` | Everything. Never computes game outcomes; plays back events. |

Core classes take `defs: Defs` and, when random, `rng: Rng` as explicit arguments. In the game
those are `Content.defs` and `Game.rng`. In tests, build `Defs` from `tests/fixtures/data` with
`ContentLoader.load_root("res://tests/fixtures/data")`, or by hand with `Defs.add()`.

**Tests for core logic use the fixtures, never `data/`**, so content changes cannot break them.
Fixture ids start with `fx_`.

## 2. Ids, keys and naming

- Ids are `snake_case`, unique per kind. Characters recruited from NPCs use the NPC id. The hero's id is `hero`, its `name_key` is `hero_name`.
- Every player-facing string is a key in a `<root>/strings/*.csv` file (`keys,en` header). Files are split by owner: `en.csv` (base, WP-00), `ui.csv` (WP-16), `numbers.csv` (WP-17), `writing.csv` (WP-18), `views.csv` (Wave 2 views). Keys must be unique across files. Fields ending in `_key`, plus `speaker`, are string keys.
- Asset ids: character and enemy sprites use the def's `sprite` (a `frames` entry), tiles `tile_<name>`, ability and item icons `icon_<name>`, portraits `portrait_<name>`, world markers `marker_<name>`.
- Audio ids: music tracks `sarmizegetusa`, `saucer`; layers `explore`, `combat`, `lobizi`; stingers and sfx by plain name (`hit`, `beam`).

## 3. Data

Schemas: `data/schemas/*.schema.json`, generated from `tools/gen_schemas.py`. Validator:
`python3 tools/validate_data.py`. Each kind lives in `data/<dir>/*.json`, one def or an array per file.
Singletons: `data/world.json`, `data/fanfi.json`, `data/tiles.json` (read with `defs.json("world")` etc).
The fixtures in `tests/fixtures/data/` are a complete, valid example of every kind: copy their shape.

Maps are one ASCII layer (`ground`) plus `legend` (char to tile id). Tiles in `tiles.json` carry
`walkable`, `cover` (0, 20, 40), `sprite`, optional `tall` (drawn y-sorted above the floor).
Cells are `[x, y]`, origin top-left. Units of size 2 are anchored at their top-left cell.

## 4. Characters and progression

- `Character.create(id, class_def, name_key)`: level 1, `max_hp = hp = base_hp`, `max_mana = mana = base_mana`, `max_charge = charge = base_charge`, `stats` copied from `base_stats`, `known` = class `abilities`, `equipped` = first 4 of `known`.
- XP to go from level L to L+1: `120 * L` (`Formulas.xp_to_next`). XP is shared: every XP grant goes to **each** party member.
- Level up: `max_hp += hp_per_level`, `hp += hp_per_level`, +1 to the class's highest base stat (ties broken in the order might, agility, wits, spirit). Emits `level_up`.
- XP sources, and only these: pages (page `xp`), quest completion (stage 100, quest `xp_on_done`), resolving an encounter by any option except flee (encounter `xp`, same amount for fight and non-fight), `["xp", n]` effects. **Never per kill.**
- Recruiting: a new `Character` with the NPC's id, `name_key`, class `recruit_class`, raised to the hero's level. At most 4 in the party; a 5th emits `toast{text_key: "party_full"}` and does nothing.

## 5. New game (`Game.new_game(seed, hero_class)`)

`food = 12`, `gold = 24`, `day = 1`, `hour = 8`, party = `[hero]`, `world_pos` = the `start`
location's cell, fog revealed within radius 2 of it, `discovered = [start]`, UFOs seeded from
`world.ufos` at their first route cell in state `patrol`, `mode = &"location"`,
`location_id` = start, `location_cell` = its `entry_cell`. `Game.rng = Rng.new(seed)`,
`state.seed = seed`. Before saving, `state.rng_state = Game.rng.get_state()`; after loading,
`Game.rng.set_state(state.rng_state)`.

## 6. Events

Every core call that changes state returns `Array[Dictionary]`, each with `type`. Views play them
in order and broadcast them with `Bus.emit_events(events)` (the narrator, toasts and HUDs listen).
Unit references are `uid: int` in combat and character ids (`StringName`) elsewhere.

| Group | Event |
|---|---|
| Combat | `battle_started{round}` `turn_started{uid, ap}` `moved{uid, path: Array[Vector2i]}` `ability_used{uid, ability, cell}` `missed{uid, target}` `damaged{target, amount, crit: bool, shield_absorbed: int}` `healed{target, amount}` `status{target, status, turns}` `status_ended{target, status}` `pushed{target, path}` `died{target, gib: bool, corpse: bool}` `summoned{uid, def_id, cell, from_corpse: bool}` `hazard{cell, hazard, turns}` `drifted{uid, from, to}` `timer{turns_left}` `fled{success: bool}` `battle_ended{outcome, reason}` `illegal{reason}` |
| World | `stepped{pos, hours}` `time_changed{day, hour}` `revealed{cells}` `discovered{location}` `arrived{location}` `food_changed{food, delta}` `starved{amount}` `encounter{encounter}` `ufo_moved{id, pos, state}` `abducted{ufo, encounter}` |
| Story | `flag_set{flag, value}` `item_changed{item, delta}` `gold_changed{delta}` `quest_changed{quest, stage}` `page_found{page}` `xp_gained{unit, amount}` `level_up{unit, level}` `recruited{unit}` `healed_party{}` `battle_requested{encounter}` `shop_requested{shop}` `teleported{location}` `narrator{line_key}` `roll{stat, dc, total, passed}` `toast{text_key}` |
| Flow (emitted by views) | `new_game{}` `saved{slot}` `defeat{}` `fled_battle{}` |

## 7. Rules mini-language (`Rules`)

Used by dialogue (`do`, choice `if`/`do`), encounter options (`if`, `pass`, `fail`), map entities
(`if`, `effects`), item `use_effects` and `fanfi.json` (`if`).

**Conditions** (all must hold; empty list is true; `op` is one of `== != >= <= > <`):

| Form | True when |
|---|---|
| `["flag", name, op, value]` | `state.flags.get(name)` compared to value (missing flag counts as `false`) |
| `["quest", id, op, stage]` | quest stage compared (not started is 0) |
| `["has_item", id, n]` | inventory count ≥ n |
| `["gold", op, n]` | gold compared |
| `["class", class_id]` | the hero's class |
| `["in_party", id]` | a party member has that id |
| `["has_page", id]` | page collected |
| `["stat", stat, op, n]` | the best value of that stat in the party, compared |
| `["night"]` | `state.is_night()` |
| `["not", cond]` / `["any", [conds]]` | negation / at least one |

**Effects** (applied in order; each emits the event in brackets):

| Form | Does |
|---|---|
| `["set_flag", name, value]` | [`flag_set`] |
| `["give_item", id, n]` / `["take_item", id, n]` | take never goes below 0; removes the key at 0 [`item_changed`] |
| `["gold", delta]` / `["food", delta]` | never below 0 [`gold_changed`, `food_changed`] |
| `["quest", id, stage]` | only moves forward; stage 100 grants `xp_on_done` [`quest_changed`, then `xp_gained`...] |
| `["page", id]` | once per page; grants the page `xp` [`page_found`, `xp_gained`...] |
| `["xp", n]` | to every party member [`xp_gained`, `level_up`] |
| `["recruit", npc_id]` | see section 4 [`recruited` or `toast`] |
| `["heal_party"]` | full HP, mana, charge for everyone [`healed_party`] |
| `["battle", encounter_id]` / `["shop", shop_id]` | requests only; the view acts [`battle_requested`, `shop_requested`] |
| `["discover", location]` | adds to `discovered` and reveals radius 2 around it [`discovered`, `revealed`] |
| `["teleport", location]` | sets `world_pos` [`teleported`] |
| `["narrate", key]` | [`narrator`] |
| `["roll", stat, dc, pass, fail]` | d20 + best party stat ≥ dc runs `pass`, else `fail` [`roll`, then the branch's events] |

Unknown names: conditions are false, effects are skipped, both `push_error` once. The validator
rejects them in data first. `Rules.CONDITIONS`/`EFFECTS` and the validator must list the same names.

Roll chance shown to players: `clamp((21 - (dc - best_stat)) * 5, 0, 100)` percent.

## 8. Combat

**Setup.** `Battle.new(encounter_id, party, rng, defs)` builds the grid from the encounter's map
(`Grid.from_map(map_def, defs.json("tiles"))`), places party characters with `hp > 0` on
`party_spawn` in order, enemies on their cells, then `start()` rolls initiative once
(`agility + d6`, ties: party first, then list order) and emits `battle_started` and the first
`turn_started`. Mana refills to max at battle start; charge does not (power cells restore it).
Summoned units act right after their summoner.

**Turns.** A unit's AP refills at its own turn start: `6 + agility / 2`, minus `chilled.value` if
chilled. `stunned` skips the turn. `bleeding` deals `value` and `regen` heals `value` at turn start.
Moving costs 1 AP per cell (2 while gravity is `floaty`; `slowed` adds 1). Movement is 4-way.
Every legal action list contains `{type: "end_turn"}` while the battle runs.

**Actions.** `{type: "move", path}` `{type: "ability", ability, cell}` `{type: "item", item, cell}`
`{type: "end_turn"}` `{type: "flee"}`. `apply()` acts for `current_unit()`; anything not legal
returns `[{type: "illegal", reason}]` and changes nothing.

**Abilities.** Range and area are Manhattan distance. `target` is what the clicked cell must hold
(`self` means the caster's own cell). Each effect goes to its natural side within `area` of the
target cell: `damage`, harmful `status` (slowed, stunned, bleeding, chilled, charmed), `taunt`
and `push` hit hostile units; `heal`, `shield`, `cleanse`, `regen` go to friendly units.
With `area = 0` only the unit on the target cell is affected. Harmful effects roll to hit once per
target; heals never miss. `magic` abilities spend mana, `tech` spend charge, `steel` are free.
With `magic_disabled`, magic abilities are not legal. At most 4 equipped abilities plus the
class `basic_attack` are available to a party unit.

**Numbers** (`Formulas`): hit `clamp(75 + 5 * (att_agility - tgt_agility) - cover + flank, 5, 95)`
where `cover` (ranged only, range > 1) is the cover of the cell next to the target on the line
toward the attacker, and `flank` is 15 when an ally of the attacker is adjacent to the target on
the opposite side. Damage `max(1, floor(base + stat * scale) + weapon_damage - armor)`
(`ignore_armor` skips armor). Natural d20 of 20 on the hit roll is a crit: double damage.
Shields absorb damage first. `push` moves the target `cells` away from the caster, stopping at
anything blocking; `floaty` adds 2 cells. Under `floaty`, a unit that ends a move drifts 1 cell in a
random free direction with 25% chance.

**Death.** A party character at 0 HP is downed, not dead. Enemies at 0 HP die: `gib` is true on a
crit kill or overkill ≥ half max HP, if the enemy def has `gib`. Enemies with `raiseable` or
`machine` leave a corpse. `summon from corpse` needs a raiseable corpse; `from machine` a machine
corpse. A summon is a party unit with the enemy's def at half max HP, `summoned = true`,
AI-controlled (`Ai.choose`), and gone after the battle.

**End.** Win when no enemies remain. Lose when every non-summoned party unit is down. With
`turn_limit > 0`, `timer` is emitted each round and the battle is lost with reason `timeout`
after that many rounds. Flee: legal on a party turn when `turn_limit == 0`; d20 + agility ≥
10 + number of living enemies succeeds. `result()` returns
`{outcome: "win"|"lose"|"fled", reason, loot: {item: n}, downed: [char_id], party_hp: {char_id: hp}, party_mana, party_charge}`.
After a win, downed characters return at 1 HP. The battle never runs past 60 rounds (lose, `stalemate`).

## 9. World

`world.json` terrain rules (hours to enter a cell, encounter chance per cell, hides from UFOs):
road 1 / 6% / no, plains 2 / 10% / no, forest 4 / 12% / yes, mountain 6 / 15% / no, river impassable.

`Travel.step`: enter the cell, add its hours (each midnight crossed: `day += 1`, eat 1 food per
party member; if short, food 0 and every member loses 2 HP, never below 1, `starved`), reveal
radius 2 (Chebyshev), discover non-hidden locations within radius 1, emit `arrived` when on a
location's cell, roll the terrain's encounter chance from its table (no roll on location cells,
and none for 3 steps after an encounter, tracked in `flags["enc_cooldown"]`), then `Ufo.tick`.

UFOs fly over any terrain. `patrol`: one route cell per party step, looping. `chase` when the
party is within 5 cells (2 at night) and not in forest: 2 cells toward the party per step.
Back to `patrol` when the party enters forest or gets 8 cells away. On the party's cell:
`abducted`. Flag `decoy_charm` = true makes the next detection fail and clears the flag. A
defeated UFO is `gone`.

`Encounters.options` returns the options whose `if` passes, always keeping `fight` and `flee`.
`Encounters.choose` runs `pass` or `fail` (after a roll when the option has one). An option that
ends without a `battle` effect and is not `flee` resolves the encounter and grants its `xp`.
`Encounters.apply_battle_result(encounter_id, result, state, rng, defs)` applies a finished
battle: party HP, loot to inventory, XP on a win.

## 10. Views and autoloads

- `Router.go(mode, args)` swaps to `res://src/modes/<mode>/<mode>.tscn`; the scene reads `Router.args` in `_ready()`. Autosaves (slot 0) except to `menu` and `combat`. Mode args: `worldmap {}`, `location {location_id, cell?}`, `combat {encounter_id, return_mode, return_args}`, `scroll {}`, `menu {}`.
- `Assets.tex(id)` / `Assets.frames(id)` never return null (magenta placeholder). Sprite frames have animations `idle walk attack hit death`, drawn facing south-east and north-east; flip horizontally for the other two directions.
- `Audio` never errors on unknown ids.
- `Settings.gore`: 0 Off, 1 Normal, 2 Bloody Mess. Presentation only.
- Base resolution 640x360, integer scaling, nearest filtering. Tiles are 64x32 diamonds: `cell_to_world(c) = Vector2((c.x - c.y) * 32, (c.x + c.y) * 16)`.
