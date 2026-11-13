# Balance (WP-20)

## Running the simulator

```bash
tools/balance.sh <data_root> <encounter_id|all> <n> <good|random|both> [options]
tools/balance.sh tests/fixtures/data all 300 both
tools/balance.sh data saucer_surgeon 300 good --party=knight,necromancer --level=3   # ids illustrative
```

Options: `--party=class,...` (hero first; default a class whose id contains `knight`, then the
other classes, max 4), `--level=N` (default 1), `--items=item:n,...` (battle inventory),
`--seed=S` (first seed, default 1), `--log` (print the events of the first battle). Battle `i` uses
seed `S + i`, so runs are reproducible. A data root outside the project works as an absolute path.

Party units use the chosen policy (`Ai.policy_good` or `Ai.policy_random`); enemies, summons and
charmed units use `Ai.choose`. Columns: `win%`; `fled`; `t/o` = lost to `turn_limit`;
`rounds` = average rounds; `hp_left%` = party HP left (downed count as 0) over party max HP,
averaged over all battles. About 1 s per 100 battles on the fixtures. A GDScript error leaves the
headless process running; stop it with Ctrl-C.

## Policies

- `good`: focus fire on the hostile closest to death, heal allies under 50%, raise/reanimate
  corpses, ward/taunt when an ally is threatened, light preference for cover, never flees.
  Units with a heal stay out of melee and within reach of their allies.
- `random`: uniformly random legal action except `end_turn`/`flee`, turn ends after 6 actions.
  It mostly walks around, so it loses almost everything; that is the floor, not a tuning target.

## Fixture results (tests/fixtures/data, fx_knight + fx_necro, level 1, 300 seeds)

| encounter | good win% | good rounds | good hp_left% | random win% |
|---|---|---|---|---|
| fx_saucer (giant, floaty, no magic, 8-round limit) | 57.7 | 3.7 | 21.4 | 0.0 (225 timeouts) |
| fx_wolves | 95.0 | 2.2 | 67.8 | 2.3 |
| fxa_coven (caster, brute, wolf) | 75.0 | 3.6 | 54.5 | 0.0 |
| fxa_pack (wolf, brute, skirmisher) | 85.7 | 3.0 | 65.5 | 0.3 |
| fxa_saucer (boss_surgeon) | 69.0 | 4.5 | 36.6 | 0.0 (123 timeouts) |
| fxc_box | 100.0 | 5.8 | 86.6 | 0.0 (300 timeouts) |
| fxc_brawl | 80.7 | 2.9 | 57.3 | 1.0 |
| fxc_duel | 100.0 | 2.7 | 97.3 | 3.3 |
| fxc_floaty | 100.0 | 4.6 | 95.3 | 17.0 |
| fxc_lab (surgeon, no magic) | 98.3 | 3.2 | 66.1 | 0.3 |
| fxc_pair | 100.0 | 5.2 | 91.5 | 2.0 |

Fixtures are test data, not tuned content; the table only shows the tool and the policies work.
`tests/unit/test_ai.gd` pins good >= 60 wins and good - random >= 30 on `fxa_pack` over 100 seeds.

## Tuning against data/ (WP-17 content)

### Who fights the saucer, and at what level

Party: the hero (`knight` or `necromancer`) plus Vezina (`healer`, recruited in town, raised to
the hero's level). No other companion exists; Ozo's strigoi ally is one battle and the saucer has
no `help` option. So every table uses two-member parties, both hero variants, no gear, no items.

XP before the abduction (XP to level L+1 is `120 * L`: level 2 at 120, 3 at 360, 4 at 720). The
UFO patrols the road east (x31-34), so a party is abducted on its way to the crash site, after
the town and usually after the strigoi cave:

| source | XP |
|---|---|
| town pages: tavern (Zia), calendar, Sargetia well | 72 |
| strigoi cave: `cave_wolves` 24, `cave_restless` 36, `page_strigoi` 24, Duras `["xp", 48]` or `cave_strigoi` 48 | 132 |
| `dead_dont_pay_taxes` done (180) + `page_taxes` (24) | 204 |
| 1-2 road encounters (wolves 24, deserters 36 + page 24, trader 24 + page 24) | 24-84 |
| **total** | **~430-490: level 3** |

Skipping the cave quest leaves level 1-2; finishing everything west of the river barely reaches 4
(Ozo, the parcel and the crash-site pages come after the saucer). Target level: **3**. Regular
encounters can happen from the first step, so they are tuned at **level 1** (worst case).

### Changes (numbers only)

| what | was | now | why |
|---|---|---|---|
| `lobizi_surgeon` hp / armor | 96 / 3 | 64 / 2 | two level-3 heroes deal ~15-25 a round; 96 behind armor 3 never fell in 12 rounds |
| `surgeon_scalpel` scale | 0.75 | 0.5 | two scalpels a turn (8 each) killed the healer in 2 rounds |
| `saucer_surgeon` starting drones | 2 | 1 | the boss still calls one more at 50% HP |
| `probe_drone` hp / armor / agility | 16 / 2 / 6 | 10 / 1 / 4 | 3 zaps a turn each; the necromancer's darts did 1-2 through armor 2 |
| `probe_zap` ap / base | 3 / 2 | 4 / 1 | 2 zaps a turn for 3; slowed under floaty already costs 3 AP a step |
| `pilum_throw` ap | 4 | 5 | 3 deserters threw 6 pila (30 dmg) a round at a level-1 party |
| `strigoi` hp | 22 | 16 | 3 strigoi with bleed beat a level-1 necromancer + healer 1 time in 3 |
| `bancul_recruit` hp | 44 | 32 | the necromancer's party needed 12+ rounds and lost half the time |

### Results (300 seeds; `tools/balance.sh data all 300 both --party=<hero>,healer --level=1`)

| encounter | knight+healer good | necro+healer good | random (both) |
|---|---|---|---|
| wolves | 98.0 | 93.0 | 1.0 / 0.0 |
| wandering_trader | 100.0 | 99.3 | 0.0 / 0.0 |
| roman_deserters | 97.7 | 83.0 | 0.0 / 0.0 |
| bancul_patrol | 100.0 | 93.0 | 0.0 / 0.0 |
| cave_wolves | 98.3 | 92.7 | 0.3 / 0.0 |
| cave_restless | 90.7 | 86.0 | 0.0 / 0.0 |
| cave_strigoi | 92.7 | 83.3 | 0.0 / 0.0 |
| crash_thrall | 99.7 | 98.3 | 0.0 / 0.0 |

`saucer_surgeon` (`--level=N`, 300 seeds, good policy; random wins 0.0 at every level):

| party | L1 | L2 | **L3** | L4 |
|---|---|---|---|---|
| knight + healer | 13.3 | 46.3 | **61.7** (78 timeouts) | 71.3 |
| necromancer + healer | 15.7 | 26.3 | **63.7** | 79.3 |
| knight + healer, 2 `healing_herbs` | | | 70.3 | |
| knight + healer + necromancer (not reachable in the slice) | | | 100.0 | |

All targets hold: regulars >= 83% for both heroes at level 1, the saucer 62-64% at level 3,
random <= 1% everywhere. The knight's saucer losses are mostly the 12-round timer (floaty
movement costs 2 AP a step); the necromancer's are mostly deaths. Gear from the shop and
herbs push the saucer toward 70%, still inside the band. Re-run the commands above after any
change to classes, abilities or enemies.
