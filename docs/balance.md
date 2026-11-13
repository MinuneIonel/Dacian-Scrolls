# Balance (WP-20)

## Running the simulator

```bash
tools/balance.sh <data_root> <encounter_id|all> <n> <good|random|both> [options]
tools/balance.sh tests/fixtures/data all 300 both
tools/balance.sh data saucer_surgeon 300 good --party=knight,necromancer --level=3   # ids illustrative
```

Options: `--party=class,...` (hero first; default a class whose id contains `knight`, then the
other classes, max 4), `--level=N` (default 1), `--items=item:n,...` (battle inventory),
`--seed=S` (first seed, default 1). Battle `i` uses seed `S + i`, so runs are reproducible.

Party units use the chosen policy (`Ai.policy_good` or `Ai.policy_random`); enemies, summons and
charmed units use `Ai.choose`. Columns: `win%`; `fled`; `t/o` = lost to `turn_limit`;
`rounds` = average rounds; `hp_left%` = party HP left (downed count as 0) over party max HP,
averaged over all battles. About 1 s per 100 battles on the fixtures. A GDScript error leaves the
headless process running; stop it with Ctrl-C.

## Policies

- `good`: focus fire on the hostile closest to death, heal allies under 50%, raise/reanimate
  corpses, ward/taunt when an ally is threatened, light preference for cover, never flees.
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

## Tuning against data/ (to do when WP-17 content lands)

Targets (plan, WP-20), 300 battles each: `good` wins >= 80% of regular encounters and 55-75%
against `saucer_surgeon`; `random` wins <= 25% of every encounter. Only numbers in data/ may be
changed, not ids or structure. Record here: the command line (party, level, items), the table,
and each number changed with the reason.

| encounter | good win% | rounds | hp_left% | random win% | changes |
|---|---|---|---|---|---|
| (pending) | | | | | |
