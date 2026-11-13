#!/usr/bin/env python3
"""Validates game data: schemas, cross-references, string keys, rules, design constraints.

    python3 tools/validate_data.py                 # data/ and tests/fixtures/data/
    python3 tools/validate_data.py data            # one root
    python3 tools/validate_data.py --strict data   # placeholder art warnings become errors

Exit code 1 on any error. Warnings never fail unless --strict.
"""
import csv
import glob
import json
import os
import sys

try:
    import jsonschema
except ImportError:
    sys.exit("validate_data: pip install jsonschema")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCHEMAS = os.path.join(ROOT, "data", "schemas")
DIRS = {"class": "classes", "ability": "abilities", "item": "items", "enemy": "enemies",
        "encounter": "encounters", "map": "maps", "dialogue": "dialogue", "quest": "quests",
        "page": "pages", "npc": "npcs", "shop": "shops"}
SINGLETONS = ["world", "fanfi", "tiles"]

# Must match src/core/rules.gd CONDITIONS / EFFECTS (a unit test checks they agree).
CONDITIONS = {"flag": 3, "quest": 3, "has_item": 2, "gold": 2, "class": 1, "in_party": 1,
              "has_page": 1, "stat": 3, "night": 0, "not": 1, "any": 1}
EFFECTS = {"set_flag": 2, "give_item": 2, "take_item": 2, "gold": 1, "food": 1, "quest": 2,
           "page": 1, "xp": 1, "recruit": 1, "heal_party": 0, "restore_charge": 1, "battle": 1, "shop": 1,
           "discover": 1, "teleport": 1, "narrate": 1, "roll": 4}
OPS = {"==", "!=", ">=", "<=", ">", "<"}
STATS = {"might", "agility", "wits", "spirit"}
# String keys every root's code relies on, beyond what data references.
CODE_KEYS = ["title", "opt_fight", "opt_flee"]
MAX_EQUIPPED = 4


class Report:
    def __init__(self, root):
        self.root = root
        self.errors = []
        self.warnings = []

    def err(self, where, msg):
        self.errors.append("%s: %s" % (where, msg))

    def warn(self, where, msg):
        self.warnings.append("%s: %s" % (where, msg))


def load_json(path, rep):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:  # noqa: BLE001
        rep.err(os.path.relpath(path, ROOT), "invalid JSON: %s" % e)
        return None


def load_schema(name):
    with open(os.path.join(SCHEMAS, name + ".schema.json")) as f:
        return json.load(f)


def load_root(root, rep):
    defs = {k: {} for k in DIRS}
    where = {}
    for kind, d in DIRS.items():
        schema = load_schema(kind)
        for path in sorted(glob.glob(os.path.join(root, d, "*.json"))):
            data = load_json(path, rep)
            if data is None:
                continue
            items = data if isinstance(data, list) else [data]
            for i, item in enumerate(items):
                loc = "%s[%d]" % (os.path.relpath(path, ROOT), i) if isinstance(data, list) else os.path.relpath(path, ROOT)
                for e in jsonschema.Draft202012Validator(schema).iter_errors(item):
                    rep.err(loc, "%s at %s" % (e.message, "/".join(str(p) for p in e.absolute_path) or "root"))
                if not isinstance(item, dict) or "id" not in item:
                    continue
                if item["id"] in defs[kind]:
                    rep.err(loc, "duplicate %s id '%s' (also in %s)" % (kind, item["id"], where[(kind, item["id"])]))
                defs[kind][item["id"]] = item
                where[(kind, item["id"])] = loc
    singles = {}
    for s in SINGLETONS:
        path = os.path.join(root, s + ".json")
        if os.path.exists(path):
            data = load_json(path, rep)
            if data is not None:
                for e in jsonschema.Draft202012Validator(load_schema(s)).iter_errors(data):
                    rep.err(os.path.relpath(path, ROOT), "%s at %s" % (e.message, "/".join(str(p) for p in e.absolute_path) or "root"))
                singles[s] = data
    return defs, where, singles


def load_strings(root, rep):
    keys = {}
    paths = sorted(glob.glob(os.path.join(root, "strings", "*.csv")))
    if not paths:
        rep.err(os.path.relpath(root, ROOT), "no strings/*.csv")
    for path in paths:
        load_string_file(path, keys, rep)
        imp = path + ".import"
        if not os.path.exists(imp) or 'importer="keep"' not in open(imp, encoding="utf-8").read():
            rep.err(os.path.relpath(path, ROOT), 'needs a committed %s.import with importer="keep" (else exports drop the CSV)' % os.path.basename(path))
    return keys


def load_string_file(path, keys, rep):
    with open(path, encoding="utf-8", newline="") as f:
        for i, row in enumerate(csv.reader(f)):
            if i == 0 or not row or not row[0]:
                continue
            if row[0] in keys:
                rep.err("%s:%d" % (os.path.relpath(path, ROOT), i + 1), "duplicate key '%s'" % row[0])
            if len(row) < 2 or row[1].strip() == "":
                rep.err("%s:%d" % (os.path.relpath(path, ROOT), i + 1), "empty text for '%s'" % row[0])
            keys[row[0]] = row[1] if len(row) > 1 else ""


class Checker:
    def __init__(self, rep, defs, singles, strings, manifest):
        self.rep = rep
        self.defs = defs
        self.singles = singles
        self.strings = strings
        self.manifest = manifest
        self.locations = {l["id"] for l in singles.get("world", {}).get("locations", []) if isinstance(l, dict) and "id" in l}

    def ref(self, where, kind, id_):
        if id_ not in self.defs[kind]:
            self.rep.err(where, "unknown %s '%s'" % (kind, id_))

    def key(self, where, k):
        if isinstance(k, str) and k not in self.strings:
            self.rep.err(where, "string key '%s' not in strings/*.csv" % k)

    def sprite(self, where, id_, section="textures"):
        m = self.manifest
        if id_ not in m.get("textures", {}) and id_ not in m.get("frames", {}):
            self.rep.warn(where, "placeholder art for '%s'" % id_)

    def all_keys(self, where, obj):
        """Every *_key field anywhere inside obj must exist in the string table."""
        if isinstance(obj, dict):
            for k, v in obj.items():
                if (k.endswith("_key") or k == "speaker") and isinstance(v, str):
                    self.key(where, v)
                else:
                    self.all_keys(where, v)
        elif isinstance(obj, list):
            for v in obj:
                self.all_keys(where, v)

    # ---- rules -------------------------------------------------------------
    def cond(self, where, c):
        if not isinstance(c, list) or not c or not isinstance(c[0], str):
            self.rep.err(where, "condition must be [name, args...]: %r" % (c,))
            return
        name, args = c[0], c[1:]
        if name not in CONDITIONS:
            self.rep.err(where, "unknown condition '%s'" % name)
            return
        if len(args) != CONDITIONS[name]:
            self.rep.err(where, "condition '%s' takes %d args, got %d" % (name, CONDITIONS[name], len(args)))
            return
        if name in ("flag", "quest", "stat") and args[1] not in OPS:
            self.rep.err(where, "bad operator '%s'" % args[1])
        if name == "gold" and args[0] not in OPS:
            self.rep.err(where, "bad operator '%s'" % args[0])
        if name == "quest":
            self.ref(where, "quest", args[0])
        elif name == "has_item":
            self.ref(where, "item", args[0])
        elif name == "class":
            self.ref(where, "class", args[0])
        elif name == "has_page":
            self.ref(where, "page", args[0])
        elif name == "in_party":
            self.ref(where, "npc", args[0])
        elif name == "stat" and args[0] not in STATS:
            self.rep.err(where, "unknown stat '%s'" % args[0])
        elif name == "not":
            self.cond(where, args[0])
        elif name == "any":
            self.conds(where, args[0])

    def conds(self, where, cs):
        if not isinstance(cs, list):
            self.rep.err(where, "conditions must be a list")
            return
        for c in cs:
            self.cond(where, c)

    def effect(self, where, e):
        if not isinstance(e, list) or not e or not isinstance(e[0], str):
            self.rep.err(where, "effect must be [name, args...]: %r" % (e,))
            return
        name, args = e[0], e[1:]
        if name not in EFFECTS:
            self.rep.err(where, "unknown effect '%s'" % name)
            return
        if len(args) != EFFECTS[name]:
            self.rep.err(where, "effect '%s' takes %d args, got %d" % (name, EFFECTS[name], len(args)))
            return
        if name in ("give_item", "take_item"):
            self.ref(where, "item", args[0])
        elif name == "quest":
            self.ref(where, "quest", args[0])
            q = self.defs["quest"].get(args[0])
            if q and str(args[1]) not in q.get("stages", {}) and args[1] != 0:
                self.rep.err(where, "quest '%s' has no stage %s" % (args[0], args[1]))
        elif name == "page":
            self.ref(where, "page", args[0])
        elif name == "recruit":
            self.ref(where, "npc", args[0])
            npc = self.defs["npc"].get(args[0])
            if npc is not None and "recruit_class" not in npc:
                self.rep.err(where, "npc '%s' has no recruit_class" % args[0])
        elif name == "battle":
            self.ref(where, "encounter", args[0])
        elif name == "shop":
            self.ref(where, "shop", args[0])
        elif name in ("discover", "teleport"):
            if args[0] not in self.locations:
                self.rep.err(where, "unknown location '%s'" % args[0])
        elif name == "narrate":
            self.key(where, args[0])
        elif name == "roll":
            if args[0] not in STATS:
                self.rep.err(where, "unknown stat '%s'" % args[0])
            self.effects(where, args[2])
            self.effects(where, args[3])

    def effects(self, where, es):
        if not isinstance(es, list):
            self.rep.err(where, "effects must be a list")
            return
        for e in es:
            self.effect(where, e)

    # ---- per kind ----------------------------------------------------------
    def run(self, where_of):
        d = self.defs
        tiles = self.singles.get("tiles", {})
        for id_, c in d["class"].items():
            w = where_of[("class", id_)]
            self.all_keys(w, c)
            for a in c.get("abilities", []):
                self.ref(w, "ability", a)
            self.ref(w, "ability", c.get("basic_attack"))
            self.sprite(w, c.get("sprite"))
        for id_, a in d["ability"].items():
            w = where_of[("ability", id_)]
            self.all_keys(w, a)
            if a.get("source") == "steel" and a.get("cost", 0) != 0:
                self.rep.err(w, "steel abilities cost 0")
            for eff in a.get("effects", []):
                if isinstance(eff, dict) and eff.get("kind") == "summon" and "enemy" in eff:
                    self.ref(w, "enemy", eff["enemy"])
            self.sprite(w, a.get("icon"))
        for id_, it in d["item"].items():
            w = where_of[("item", id_)]
            self.all_keys(w, it)
            self.effects(w, it.get("use_effects", []))
            if "use_ability" in it:
                self.ref(w, "ability", it["use_ability"])
            self.sprite(w, it.get("icon"))
        for id_, en in d["enemy"].items():
            w = where_of[("enemy", id_)]
            self.all_keys(w, en)
            for a in en.get("abilities", []):
                self.ref(w, "ability", a)
            for l in en.get("loot", []):
                self.ref(w, "item", l.get("item"))
            self.sprite(w, en.get("sprite"))
        for id_, enc in d["encounter"].items():
            w = where_of[("encounter", id_)]
            self.all_keys(w, enc)
            self.ref(w, "map", enc.get("map"))
            for e in enc.get("enemies", []):
                self.ref(w, "enemy", e.get("enemy"))
            opts = enc.get("options", [])
            ids = [o.get("id") for o in opts]
            if "fight" not in ids or "flee" not in ids:
                self.rep.err(w, "every encounter keeps 'fight' and 'flee' options")
            if len(set(ids)) != len(ids):
                self.rep.err(w, "duplicate option ids")
            for o in opts:
                self.conds(w, o.get("if", []))
                self.effects(w, o.get("pass", []))
                self.effects(w, o.get("fail", []))
            m = d["map"].get(enc.get("map"))
            if m:
                grid = self.map_grid(m, tiles)
                cells = [tuple(c) for c in enc.get("party_spawn", [])] + [tuple(e["cell"]) for e in enc.get("enemies", []) if "cell" in e]
                for c in cells:
                    if not grid.get(c, False):
                        self.rep.err(w, "spawn cell %s is not walkable on map '%s'" % (list(c), m["id"]))
        for id_, m in d["map"].items():
            w = where_of[("map", id_)]
            self.all_keys(w, m)
            rows = m.get("ground", [])
            if len({len(r) for r in rows}) > 1:
                self.rep.err(w, "ground rows differ in length")
            for r in rows:
                for ch in r:
                    if ch not in m.get("legend", {}):
                        self.rep.err(w, "char '%s' not in legend" % ch)
                        break
            for t in m.get("legend", {}).values():
                if t not in tiles:
                    self.rep.err(w, "tile '%s' not in tiles.json" % t)
            grid = self.map_grid(m, tiles)
            for ent in m.get("entities", []):
                cell = tuple(ent.get("cell", [-1, -1]))
                if cell not in grid:
                    self.rep.err(w, "entity '%s' cell %s outside map" % (ent.get("id"), list(cell)))
                if ent.get("kind") == "npc":
                    self.ref(w, "npc", ent.get("npc"))
                if "dialogue" in ent:
                    self.ref(w, "dialogue", ent["dialogue"])
                self.conds(w, ent.get("if", []))
                self.effects(w, ent.get("effects", []))
                to = ent.get("to", {})
                if to.get("mode") == "location" and to.get("location") not in self.locations and to.get("location") not in d["map"]:
                    self.rep.err(w, "exit to unknown location '%s'" % to.get("location"))
        for id_, dl in d["dialogue"].items():
            w = where_of[("dialogue", id_)]
            self.all_keys(w, dl)
            nodes = dl.get("nodes", {})
            if dl.get("start") not in nodes:
                self.rep.err(w, "start node '%s' missing" % dl.get("start"))
            for nid, n in nodes.items():
                self.effects("%s/%s" % (w, nid), n.get("do", []))
                if not n.get("choices"):
                    self.rep.err("%s/%s" % (w, nid), "node has no choices (use a goto 'end' choice)")
                for ch in n.get("choices", []):
                    self.conds("%s/%s" % (w, nid), ch.get("if", []))
                    self.effects("%s/%s" % (w, nid), ch.get("do", []))
                    if ch.get("goto") != "end" and ch.get("goto") not in nodes:
                        self.rep.err("%s/%s" % (w, nid), "goto unknown node '%s'" % ch.get("goto"))
                if n.get("choices") and all(ch.get("if") for ch in n["choices"]):
                    self.rep.warn("%s/%s" % (w, nid), "every choice is conditional; the player may be stuck")
        for id_, q in d["quest"].items():
            self.all_keys(where_of[("quest", id_)], q)
            for v in q.get("stages", {}).values():
                self.key(where_of[("quest", id_)], v)
        orders = {}
        for id_, p in d["page"].items():
            w = where_of[("page", id_)]
            self.all_keys(w, p)
            if p.get("order") in orders:
                self.rep.err(w, "page order %s also used by '%s'" % (p.get("order"), orders[p.get("order")]))
            orders[p.get("order")] = id_
        for id_, n in d["npc"].items():
            w = where_of[("npc", id_)]
            self.all_keys(w, n)
            self.ref(w, "dialogue", n.get("dialogue"))
            if "recruit_class" in n:
                self.ref(w, "class", n["recruit_class"])
            if "shop" in n:
                self.ref(w, "shop", n["shop"])
            self.sprite(w, n.get("sprite"))
        for id_, s in d["shop"].items():
            w = where_of[("shop", id_)]
            self.all_keys(w, s)
            for st in s.get("stock", []):
                self.ref(w, "item", st.get("item"))
        self.check_world()
        fanfi = self.singles.get("fanfi", {})
        for ev, entries in fanfi.items() if isinstance(fanfi, dict) else []:
            for e in entries:
                self.conds("fanfi.json/" + ev, e.get("if", []))
                for k in e.get("lines", []):
                    self.key("fanfi.json/" + ev, k)
        for t, td in tiles.items() if isinstance(tiles, dict) else []:
            self.sprite("tiles.json/" + t, td.get("sprite"))
        for k in CODE_KEYS:
            self.key("code", k)

    def map_grid(self, m, tiles):
        grid = {}
        legend = m.get("legend", {})
        for y, row in enumerate(m.get("ground", [])):
            for x, ch in enumerate(row):
                grid[(x, y)] = bool(tiles.get(legend.get(ch, ""), {}).get("walkable", False))
        return grid

    def check_world(self):
        world = self.singles.get("world")
        if not world:
            return
        w = "world.json"
        self.all_keys(w, world)
        size = world.get("size", [0, 0])
        rows = world.get("terrain", [])
        if len(rows) != size[1] or any(len(r) != size[0] for r in rows):
            self.rep.err(w, "terrain must be %d rows of %d chars" % (size[1], size[0]))
        legend = world.get("legend", {})
        rules = world.get("terrain_rules", {})
        for t in set(legend.values()):
            if t not in rules:
                self.rep.err(w, "no terrain_rules for '%s'" % t)
            elif t != "river" and t not in world.get("tables", {}):
                self.rep.err(w, "no encounter table for '%s'" % t)

        def terrain(c):
            x, y = c
            if 0 <= y < len(rows) and 0 <= x < len(rows[y]):
                return legend.get(rows[y][x])
            return None

        def passable(c):
            t = terrain(c)
            return t is not None and rules.get(t, {}).get("passable", False)

        if world.get("start") not in self.locations:
            self.rep.err(w, "start '%s' is not a location" % world.get("start"))
        for l in world.get("locations", []):
            self.ref(w, "map", l.get("map"))
            if not passable(tuple(l.get("cell", [-1, -1]))):
                self.rep.err(w, "location '%s' is on impassable terrain" % l.get("id"))
        for u in world.get("ufos", []):
            self.ref(w, "encounter", u.get("encounter"))
            for c in u.get("route", []):
                if terrain(tuple(c)) is None:
                    self.rep.err(w, "ufo '%s' route leaves the map at %s" % (u.get("id"), c))
        for t, tab in world.get("tables", {}).items():
            for e in tab:
                self.ref(w, "encounter", e.get("encounter"))
        # every location reachable from the start over passable terrain
        start = next((l for l in world.get("locations", []) if l.get("id") == world.get("start")), None)
        if start:
            seen = {tuple(start["cell"])}
            todo = [tuple(start["cell"])]
            while todo:
                x, y = todo.pop()
                for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if n not in seen and passable(n):
                        seen.add(n)
                        todo.append(n)
            for l in world.get("locations", []):
                if tuple(l.get("cell", [-1, -1])) not in seen:
                    self.rep.err(w, "location '%s' unreachable from start" % l.get("id"))


def validate(root, strict):
    rep = Report(root)
    defs, where_of, singles = load_root(root, rep)
    strings = load_strings(root, rep)
    manifest_path = os.path.join(ROOT, "assets", "manifest.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    Checker(rep, defs, singles, strings, manifest).run(where_of)
    if strict:
        rep.errors += rep.warnings
        rep.warnings = []
    return rep


def check_rules_vocab_matches_gd(rep):
    """rules.gd and this file must list the same conditions and effects."""
    path = os.path.join(ROOT, "src", "core", "rules.gd")
    text = open(path).read()
    for name in list(CONDITIONS) + list(EFFECTS):
        if '"%s":' % name not in text:
            rep.err("src/core/rules.gd", "rules vocabulary out of sync: '%s'" % name)


def main(argv):
    strict = "--strict" in argv
    roots = [a for a in argv if not a.startswith("--")] or ["data", "tests/fixtures/data"]
    failed = False
    for r in roots:
        root = os.path.join(ROOT, r) if not os.path.isabs(r) else r
        rep = validate(root, strict and r != "tests/fixtures/data")
        if r == roots[0]:
            check_rules_vocab_matches_gd(rep)
        placeholder = [w for w in rep.warnings if "placeholder art" in w]
        others = [w for w in rep.warnings if "placeholder art" not in w]
        for w in others:
            print("warning  %s" % w)
        if placeholder:
            print("warning  %s: %d placeholder art ids (use --strict to list)" % (r, len(placeholder)))
        for e in rep.errors:
            print("ERROR    %s" % e)
        print("%s: %d errors, %d warnings" % (r, len(rep.errors), len(rep.warnings)))
        failed = failed or bool(rep.errors)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
