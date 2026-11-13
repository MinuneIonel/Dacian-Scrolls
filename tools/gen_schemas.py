#!/usr/bin/env python3
"""Source of truth for data/schemas/*.schema.json. Edit here, then run:
    python3 tools/gen_schemas.py
Schemas are contracts: changing one is a contract change (see docs/CONTRACTS.md)."""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "schemas")

STR = {"type": "string", "minLength": 1}
ID = {"type": "string", "pattern": "^[a-z0-9_]+$"}
INT = {"type": "integer"}
NUM = {"type": "number"}
BOOL = {"type": "boolean"}
CELL = {"type": "array", "items": INT, "minItems": 2, "maxItems": 2}
STAT_NAMES = ["might", "agility", "wits", "spirit"]
STATS = {"type": "object", "properties": {k: INT for k in STAT_NAMES},
         "required": STAT_NAMES, "additionalProperties": False}
RULES = {"type": "array"}  # rules lists are checked by validate_data.py


def obj(props, required=None):
    """Closed object. Keys starting with '_' are allowed everywhere, as comments."""
    return {"type": "object", "properties": props,
            "required": list(props) if required is None else required,
            "patternProperties": {"^_": {}}, "additionalProperties": False}


def optional(o, *names):
    o["required"] = [r for r in o["required"] if r not in names]
    return o


def arr(items, min_items=0):
    a = {"type": "array", "items": items}
    if min_items:
        a["minItems"] = min_items
    return a


EFFECT = {"oneOf": [
    obj({"kind": {"const": "damage"}, "base": INT, "stat": {"enum": STAT_NAMES}, "scale": NUM,
         "ignore_armor": BOOL}, ["kind", "base", "stat", "scale"]),
    obj({"kind": {"const": "heal"}, "base": INT, "stat": {"enum": STAT_NAMES}, "scale": NUM}),
    obj({"kind": {"const": "shield"}, "amount": INT, "turns": INT}),
    obj({"kind": {"const": "taunt"}, "turns": INT}),
    obj({"kind": {"const": "status"},
         "status": {"enum": ["slowed", "stunned", "bleeding", "chilled", "regen", "charmed"]},
         "turns": INT, "value": INT}, ["kind", "status", "turns"]),
    obj({"kind": {"const": "summon"}, "from": {"enum": ["corpse", "machine", "spawn"]}, "enemy": ID},
        ["kind", "from"]),
    obj({"kind": {"const": "cleanse"}}),
    obj({"kind": {"const": "push"}, "cells": INT}),
    obj({"kind": {"const": "hazard"}, "hazard": {"enum": ["gravity_zone", "specimen_tank", "acid"]},
         "turns": INT}),
]}

OPTION = obj({
    "id": {"enum": ["fight", "talk", "sneak", "bribe", "flee", "trade", "help"]},
    "label_key": STR, "if": RULES,
    "roll": {"oneOf": [{"type": "null"}, obj({"stat": {"enum": STAT_NAMES}, "dc": INT})]},
    "pass": RULES, "fail": RULES})

ENTITY = optional(obj({
    "id": ID,
    "kind": {"enum": ["npc", "container", "exit", "trigger", "spawn_ally", "spawn_enemy", "prop"]},
    "cell": CELL, "npc": ID, "dialogue": ID, "once": BOOL, "if": RULES, "effects": RULES,
    "sprite": ID,
    "to": optional(obj({"mode": {"enum": ["worldmap", "location"]}, "location": ID, "cell": CELL}),
                   "location", "cell")}),
    "npc", "dialogue", "once", "if", "effects", "sprite", "to")

NODE = optional(obj({"speaker": STR, "text_key": STR, "do": RULES,
                     "choices": arr(obj({"text_key": STR, "if": RULES, "do": RULES, "goto": ID}))}),
                "do")

SCHEMAS = {
    "class": optional(obj({
        "id": ID, "name_key": STR, "desc_key": STR, "base_stats": STATS, "base_hp": INT,
        "hp_per_level": INT, "base_mana": INT, "base_charge": INT, "basic_attack": ID,
        "abilities": arr(ID, 1), "sprite": ID, "portrait": ID}), "portrait"),
    "ability": optional(obj({
        "id": ID, "name_key": STR, "desc_key": STR, "source": {"enum": ["steel", "magic", "tech"]},
        "ap": {"type": "integer", "minimum": 1}, "cost": {"type": "integer", "minimum": 0},
        "range": {"type": "integer", "minimum": 0}, "area": {"type": "integer", "minimum": 0},
        "target": {"enum": ["enemy", "ally", "cell", "corpse", "machine", "self"]},
        "icon": ID, "sfx": ID, "effects": arr(EFFECT, 1)}), "sfx"),
    "item": optional(obj({
        "id": ID, "name_key": STR, "desc_key": STR,
        "kind": {"enum": ["weapon", "armor", "trinket", "consumable", "quest", "salvage"]},
        "price": {"type": "integer", "minimum": 0, "multipleOf": 12},
        "mods": {"type": "object", "additionalProperties": INT},
        "use_effects": RULES, "use_ability": ID, "icon": ID}), "mods", "use_effects", "use_ability"),
    "enemy": obj({
        "id": ID, "name_key": STR, "size": {"enum": [1, 2]}, "hp": {"type": "integer", "minimum": 1},
        "armor": INT, "stats": STATS, "abilities": arr(ID, 1),
        "ai": {"enum": ["brute", "skirmisher", "caster", "boss_surgeon"]},
        "raiseable": BOOL, "machine": BOOL, "gib": BOOL, "sprite": ID,
        "loot": arr(obj({"item": ID, "chance": {"type": "number", "minimum": 0, "maximum": 1}}))}),
    "encounter": obj({
        "id": ID, "intro_key": STR, "map": ID, "xp": INT, "party_spawn": arr(CELL, 4),
        "enemies": arr(obj({"enemy": ID, "cell": CELL})),
        "rules": obj({"magic_disabled": BOOL, "gravity": {"enum": ["normal", "floaty"]}, "turn_limit": INT}),
        "options": arr(OPTION, 2)}),
    "map": optional(obj({
        "id": ID, "kind": {"enum": ["town", "outskirts", "dungeon", "arena"]}, "name_key": STR,
        "legend": {"type": "object", "additionalProperties": ID}, "ground": arr({"type": "string"}, 1),
        "music": ID, "entities": arr(ENTITY)}), "music"),
    "dialogue": obj({"id": ID, "start": ID, "nodes": {"type": "object", "additionalProperties": NODE}}),
    "quest": obj({"id": ID, "name_key": STR,
                  "stages": {"type": "object", "propertyNames": {"pattern": "^[0-9]+$"}, "additionalProperties": STR},
                  "xp_on_done": INT}),
    "page": obj({"id": ID, "title_key": STR, "body_key": STR,
                 "order": {"type": "integer", "minimum": 1, "maximum": 12}, "xp": INT}),
    "npc": optional(obj({"id": ID, "name_key": STR, "sprite": ID, "portrait": ID, "dialogue": ID,
                         "recruit_class": ID, "shop": ID}), "portrait", "recruit_class", "shop"),
    "shop": obj({"id": ID, "name_key": STR, "stock": arr(obj({"item": ID, "count": INT}))}),
    "tiles": {"type": "object", "additionalProperties": optional(
        obj({"walkable": BOOL, "cover": {"enum": [0, 20, 40]}, "sprite": ID, "tall": BOOL}), "tall")},
    "world": obj({
        "size": CELL, "start": ID,
        "legend": {"type": "object", "additionalProperties": {"enum": ["road", "plains", "forest", "mountain", "river"]}},
        "terrain": arr({"type": "string"}, 1),
        "terrain_rules": {"type": "object", "additionalProperties": obj(
            {"hours": INT, "encounter_chance": NUM, "hides": BOOL, "passable": BOOL})},
        "locations": arr(optional(obj({"id": ID, "name_key": STR, "cell": CELL, "map": ID, "entry_cell": CELL,
                                       "hidden": BOOL, "marker": ID}), "marker")),
        "ufos": arr(obj({"id": ID, "route": arr(CELL, 2), "encounter": ID})),
        "tables": {"type": "object", "additionalProperties": arr(obj({"encounter": ID, "weight": INT}))}}),
    "fanfi": {"type": "object", "additionalProperties": arr(
        obj({"if": RULES, "lines": arr(STR, 1), "once": BOOL}))},
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, schema in SCHEMAS.items():
        s = {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": name}
        s.update(schema)
        with open(os.path.join(OUT, name + ".schema.json"), "w") as f:
            json.dump(s, f, indent=1)
            f.write("\n")
    print("wrote %d schemas to %s" % (len(SCHEMAS), OUT))


if __name__ == "__main__":
    main()
