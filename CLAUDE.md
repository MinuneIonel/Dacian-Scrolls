# Dacian Scrolls: guide for agents

A 2D isometric, turn-based party RPG in Godot 4.5.1 (GDScript). Dacia, year 101, versus the
Lobizi, 15-metre giants from a 1953 séance book. Claude builds everything; the humans play-test.

Read, in order: this file, `docs/CONTRACTS.md`, your work package in `docs/plan.md` section 7.
The game design is `docs/spec/game-plan.md`.

## Commands

```bash
tools/get_godot.sh                       # once; downloads the pinned Godot to .godot-bin/
tools/test.sh                            # all unit + integration tests, headless
tools/test.sh --filter=battle            # files or test names containing "battle"
tools/test.sh tests/bot                  # another test directory
python3 tools/validate_data.py           # data + fixtures: schemas, references, strings, rules
python3 tools/test_validate_data.py      # the validator's own tests
tools/shots.sh res://path/scene.tscn out.png [frames] [WxH] [--args='{"k":1}']   # screenshot
tools/godot.sh --headless -s some_script.gd   # run anything else with the pinned Godot
```

Look at the screenshots you take (open the PNG). A view is not done until you have seen it.

## Tests

Our own small runner (`tests/framework/`), not GUT. Files `tests/**/test_*.gd`, `extends TestCase`,
methods `test_*`. Assertions: `assert_eq assert_ne assert_true assert_false assert_almost_eq
assert_between assert_has assert_not_has assert_null assert_not_null fail`. Helpers:
`find_event(events, type)`, `count_events(events, type)`, `await wait_frames(n)`.
`before_each/after_each/before_all/after_all` may be overridden. **Any engine error during a test
fails it** (push_error, null calls, parse errors) unless the test calls `expect_errors(n)` first.
`assert_eq` treats String and StringName as equal, and int and float by value.

Core tests use fixture data: `var defs := ContentLoader.load_root("res://tests/fixtures/data")`.
Never point core tests at `data/`.

## Rules that are not negotiable

- `src/core/**` is pure logic: no Node, scene tree, autoloads, files, `Time`, `OS`, or global
  `randi()`/`randf()`. Randomness only from an `Rng` argument. Lint test enforces it.
- Views never decide outcomes. They send actions to core and animate the returned events.
- Static types on every function signature. No C#, no plugins.
- No player-facing string literals in code: `tr("key")`, keys in `data/strings/<your file>.csv` (see CONTRACTS section 2).
- XP never comes from kills. Every encounter keeps `fight` and `flee`. Max 4 equipped abilities.
- Gore (`Settings.gore` 0/1/2) is presentation only, never changes results.
- Tone: the world takes itself seriously, the narrator Fanfi does not. Deadpan and self-aware,
  at most one meme reference per scene. Splatter comedy, never grim.
- **Edit only the files your work package owns.** If you need a contract changed, stop and write
  the request in your handoff file instead of editing someone else's file.
- Small commits; each leaves `tools/test.sh` and `tools/validate_data.py` green.

## When you finish a package

Write `docs/handoff/WP-NN.md` (15 lines max): what exists, how to call it, known gaps, any
contract change requests. Then report back.

## Godot gotchas we hit

- New `class_name` scripts need the class cache rebuilt: `tools/test.sh` does it every run;
  for other commands set `GODOT_REIMPORT=1`.
- Hand-written `.tscn` files: keep them tiny (root node + script). Build node trees in code.
- Generated PNG/OGG files are loaded through `Assets`/`Audio`, which fall back to raw files when
  the editor import has not run yet.
- Typed arrays: `Array[Dictionary]` return values need typed locals (`var out: Array[Dictionary] = []`).
- A new `strings/*.csv` needs a committed `<file>.csv.import` with `[remap]` and `importer="keep"`, or exports ship no text. The validator checks it.
