## Shared helpers for the battle tests (WP-12). Not a test file itself.
extends TestCase

var defs: Defs

func before_all() -> void:
	defs = ContentLoader.load_root("res://tests/fixtures/data")

## A party member built by hand (Character.create belongs to WP-10).
func mk(id: String, class_id: String = "fx_knight", stats: Dictionary = {}, equipped: Array = [], hp: int = 30) -> Character:
	var c := Character.new()
	c.id = StringName(id)
	c.class_id = StringName(class_id)
	c.hp = hp
	c.max_hp = 30
	c.max_mana = 10
	c.mana = 0
	c.max_charge = 6
	c.charge = 6
	var st: Dictionary = {"might": 6, "agility": 4, "wits": 4, "spirit": 3}
	for k in stats: st[k] = stats[k]
	c.stats = st
	var eq: Array[StringName] = []
	for a in equipped: eq.append(StringName(a))
	c.known = eq.duplicate()
	c.equipped = eq
	return c

func party(chars: Array) -> Array[Character]:
	var out: Array[Character] = []
	for c in chars: out.append(c)
	return out

func battle(enc: String, chars: Array, seed: int = 1) -> Battle:
	return Battle.new(StringName(enc), party(chars), Rng.new(seed), defs)

## uid of the first unit with that char id or def id.
func uid_of(b: Battle, id: String) -> int:
	for u in b.units():
		if str(u.char_id) == id or (str(u.char_id) == "" and str(u.def_id) == id): return u.uid
	return -1

## Ends turns until it is uid's turn. Returns the events of the last end_turn (or []).
func until_turn(b: Battle, uid: int) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	for i in 200:
		if b.is_over() or b.current_unit() == uid: return ev
		ev = b.apply({"type": "end_turn"})
	return ev

func has_action(acts: Array, want: Dictionary) -> bool:
	for a in acts:
		var ok: bool = true
		for k in want:
			if not a.has(k) or str(a[k]) != str(want[k]): ok = false
		if ok: return true
	return false

func abilities_in(acts: Array) -> Array[String]:
	var out: Array[String] = []
	for a in acts:
		if a.type == "ability" and not out.has(str(a.ability)): out.append(str(a.ability))
	return out

func events_of(ev: Array, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in ev:
		if e.type == type: out.append(e)
	return out

## The battle used by the last first_hit() call.
var hb: Battle

## Builds battles with build.call(seed) for seeds 1.. until `action` lands with no miss and no
## crit; returns its events (and leaves the battle in hb). Fails the test if no seed works.
func first_hit(build: Callable, action: Dictionary, allow_crit: bool = false) -> Array[Dictionary]:
	for s in range(1, 60):
		var b: Battle = build.call(s)
		var ev: Array[Dictionary] = b.apply(action)
		if count_events(ev, "illegal") > 0:
			fail("illegal: %s" % str(ev))
			return ev
		if count_events(ev, "missed") > 0: continue
		var crit: bool = false
		for e in ev:
			if e.type == "damaged" and e.crit: crit = true
		if crit and not allow_crit: continue
		hb = b
		return ev
	fail("no seed hit")
	return []
