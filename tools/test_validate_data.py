#!/usr/bin/env python3
"""The validator catches what it promises to. Run: python3 tools/test_validate_data.py"""
import json
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import validate_data as v  # noqa: E402

FIX = os.path.join(v.ROOT, "tests", "fixtures", "data")


def run_with(mutate):
    tmp = tempfile.mkdtemp()
    root = os.path.join(tmp, "data")
    shutil.copytree(FIX, root)
    mutate(root)
    rep = v.validate(root, strict=False)
    shutil.rmtree(tmp)
    return rep.errors


def edit(root, rel, fn):
    p = os.path.join(root, rel)
    data = json.load(open(p))
    fn(data)
    json.dump(data, open(p, "w"))


CASES = [
    ("clean fixtures pass", lambda r: None, None),
    ("missing ability ref", lambda r: edit(r, "classes/fx_knight.json", lambda d: d["abilities"].append("nope")), "unknown ability 'nope'"),
    ("missing string key", lambda r: edit(r, "quests/fx_quest.json", lambda d: d.update(name_key="nope_key")), "string key 'nope_key'"),
    ("unknown effect", lambda r: edit(r, "items/fx_items.json", lambda d: d[1].update(use_effects=[["explode", 1]])), "unknown effect 'explode'"),
    ("wrong arg count", lambda r: edit(r, "items/fx_items.json", lambda d: d[1].update(use_effects=[["food"]])), "takes 1 args"),
    ("encounter needs fight and flee", lambda r: edit(r, "encounters/fx_wolves.json", lambda d: d.update(options=[o for o in d["options"] if o["id"] != "flee"])), "'fight' and 'flee'"),
    ("schema type error", lambda r: edit(r, "enemies/fx_enemies.json", lambda d: d[0].update(hp="ten")), "is not of type 'integer'"),
    ("price multiple of 12", lambda r: edit(r, "items/fx_items.json", lambda d: d[0].update(price=25)), "multiple of 12"),
    ("dialogue goto", lambda r: edit(r, "dialogue/fx_priest.json", lambda d: d["nodes"]["quest"]["choices"][0].update(goto="nowhere")), "goto unknown node"),
    ("unreachable location", lambda r: edit(r, "world.json", lambda d: d["locations"][1].update(cell=[11, 0])), "unreachable"),
    ("spawn on wall", lambda r: edit(r, "encounters/fx_wolves.json", lambda d: d["enemies"][0].update(cell=[0, 0])), "not walkable"),
]

failed = 0
for name, mutate, expect in CASES:
    errors = run_with(mutate)
    ok = (not errors) if expect is None else any(expect in e for e in errors)
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else "  -> %s" % errors))
    failed += not ok
print("%d/%d validator cases passed" % (len(CASES) - failed, len(CASES)))
sys.exit(1 if failed else 0)
