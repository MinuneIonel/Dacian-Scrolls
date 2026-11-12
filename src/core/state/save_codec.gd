## Turns a GameState into text and back. Never trusts its input.
class_name SaveCodec
extends RefCounted

const CORRUPT: String = "save_corrupt"
const TOO_NEW: String = "save_too_new"
const MAX_PARTY: int = 4

## Top-level key -> expected shape (see _shape_ok).
const SHAPE: Dictionary = {
	"version": "int", "seed": "bigint", "rng_state": "bigint", "day": "int", "hour": "int",
	"food": "int", "gold": "int", "party": "party", "inventory": "int_map", "flags": "dict",
	"quests": "int_map", "pages": "str_list", "world_pos": "cell", "revealed": "dict",
	"discovered": "str_list", "ufos": "ufos", "mode": "str", "location_id": "str",
	"location_cell": "cell",
}
const CHAR_SHAPE: Dictionary = {
	"id": "str", "name_key": "str", "class_id": "str", "level": "int", "xp": "int",
	"hp": "int", "max_hp": "int", "mana": "int", "max_mana": "int", "charge": "int",
	"max_charge": "int", "stats": "stats", "known": "str_list", "equipped": "str_list",
	"gear": "gear",
}

static func encode(state: GameState) -> String:
	return JSON.stringify(state.to_dict(), "", false)

## Returns {ok: bool, state: GameState or null, error_key: String}.
## error_key is a string-table key such as "save_corrupt" or "save_too_new".
static func decode(text: String) -> Dictionary:
	if text.strip_edges() == "": return _fail(CORRUPT)
	var j := JSON.new()
	if j.parse(text) != OK: return _fail(CORRUPT)
	var d: Variant = j.data
	if not (d is Dictionary): return _fail(CORRUPT)
	var v: Variant = d.get("version")
	if not _is_int(v) or int(v) < 1: return _fail(CORRUPT)
	if int(v) > GameState.VERSION: return _fail(TOO_NEW)
	# Older versions would be migrated here; version 1 is the first.
	for k in SHAPE:
		if not d.has(k) or not _shape_ok(d[k], SHAPE[k]): return _fail(CORRUPT)
	return {"ok": true, "state": GameState.from_dict(d), "error_key": ""}

static func _fail(key: String) -> Dictionary:
	return {"ok": false, "state": null, "error_key": key}

static func _is_int(v: Variant) -> bool:
	if v is int: return true
	return v is float and is_finite(v) and float(v) == floorf(v) and absf(v) < 9.0e15

static func _shape_ok(v: Variant, shape: String) -> bool:
	match shape:
		"int": return _is_int(v)
		"bigint": return (v is String and (v as String).is_valid_int()) or _is_int(v)
		"str": return v is String
		"dict": return v is Dictionary
		"cell": return v is Array and v.size() == 2 and _is_int(v[0]) and _is_int(v[1])
		"str_list":
			if not (v is Array): return false
			for x in v:
				if not (x is String): return false
			return true
		"int_map":
			if not (v is Dictionary): return false
			for k in v:
				if not _is_int(v[k]): return false
			return true
		"stats":
			if not (v is Dictionary): return false
			for k in Character.STAT_KEYS:
				if not _is_int(v.get(k)): return false
			return true
		"gear":
			if not (v is Dictionary): return false
			for k in v:
				if not (v[k] is String): return false
			return true
		"ufos":
			if not (v is Array): return false
			for u in v:
				if not (u is Dictionary): return false
				if not (u.get("id") is String and u.get("state") is String): return false
				if not _shape_ok(u.get("pos"), "cell") or not _is_int(u.get("route_i")): return false
			return true
		"party":
			if not (v is Array) or v.is_empty() or v.size() > MAX_PARTY: return false
			for c in v:
				if not (c is Dictionary): return false
				for k in CHAR_SHAPE:
					if not c.has(k) or not _shape_ok(c[k], CHAR_SHAPE[k]): return false
			return true
	return false
