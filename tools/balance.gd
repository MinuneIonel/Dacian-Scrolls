## Balance simulator (WP-20). Runs N seeded battles per encounter and prints win rates.
## Usage: tools/balance.sh <data_root> <encounter_id|all> <n> <good|random|both> [options]
##   --party=class_a,class_b   party classes, hero first (default: a knight-like class, then the rest, max 4)
##   --level=N                 party level (default 1)
##   --items=item:n,item:n     consumables in the battle inventory (default none)
##   --seed=S                  first seed (default 1)
##   --log                     print the events of the first battle of each run
## Enemies use Ai.choose; party units use the policy (summons and charmed units use Ai.choose).
extends SceneTree

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var pos: Array[String] = []
	var opt: Dictionary = {}
	for a in args:
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			opt[kv[0]] = kv[1] if kv.size() > 1 else "true"
		else:
			pos.append(a)
	if pos.size() < 4:
		printerr("usage: tools/balance.sh <data_root> <encounter_id|all> <n> <good|random|both> [--party=a,b] [--level=N] [--items=id:n] [--seed=S]")
		quit(2)
		return
	var root: String = pos[0]
	if not root.begins_with("res://") and not root.begins_with("/"): root = "res://" + root
	var defs: Defs = ContentLoader.load_root(root)
	var n: int = maxi(1, int(pos[2]))
	var policies: Array[String] = []
	if pos[3] == "both": policies.assign(["good", "random"])
	else: policies.append(pos[3])
	var classes: Array[StringName] = _party_classes(defs, str(opt.get("party", "")))
	if classes.is_empty():
		printerr("balance: no classes in %s" % root)
		quit(1)
		return
	var encs: Array[StringName] = []
	if pos[1] == "all":
		for e in defs.all(&"encounter"):
			if not (e.get("enemies", []) as Array).is_empty(): encs.append(StringName(str(e.id)))
	elif defs.has(&"encounter", StringName(pos[1])):
		encs.append(StringName(pos[1]))
	else:
		printerr("balance: unknown encounter '%s'" % pos[1])
		quit(1)
		return
	var level: int = maxi(1, int(opt.get("level", "1")))
	var items: Dictionary = _items(str(opt.get("items", "")))
	var seed0: int = int(opt.get("seed", "1"))
	print("root=%s party=%s level=%d items=%s n=%d" % [root, ",".join(classes), level, items, n])
	print("%-22s %-7s %6s %6s %6s %7s %8s" % ["encounter", "policy", "win%", "fled", "t/o", "rounds", "hp_left%"])
	for enc in encs:
		for pol in policies:
			var st: Dictionary = run_many(defs, enc, classes, level, items, pol, n, seed0, opt.has("log"))
			print("%-22s %-7s %6.1f %6d %6d %7.1f %8.1f" % [enc, pol, 100.0 * st.wins / n, st.fled, st.timeout,
				float(st.rounds) / n, 100.0 * st.hp_frac / n])
	quit(0)

static func _party_classes(defs: Defs, spec: String) -> Array[StringName]:
	var out: Array[StringName] = []
	if spec != "":
		for c in spec.split(",", false):
			if defs.has(&"class", StringName(c)): out.append(StringName(c))
			else: printerr("balance: unknown class '%s'" % c)
		return out
	var all: Array[Dictionary] = defs.all(&"class")
	for c in all:
		if str(c.id).contains("knight"): out.append(StringName(str(c.id)))
	for c in all:
		if out.size() >= 4: break
		if not out.has(StringName(str(c.id))): out.append(StringName(str(c.id)))
	return out

static func _items(spec: String) -> Dictionary:
	var out: Dictionary = {}
	for part in spec.split(",", false):
		var kv: PackedStringArray = part.split(":")
		out[StringName(kv[0])] = int(kv[1]) if kv.size() > 1 else 1
	return out

static func build_party(defs: Defs, classes: Array[StringName], level: int) -> Array[Character]:
	var out: Array[Character] = []
	for i in classes.size():
		var cd: Dictionary = defs.get_def(&"class", classes[i])
		var c := Character.create(StringName("p%d" % i), cd, str(cd.get("name_key", "")))
		for l in level - 1: c.level_up(cd)
		out.append(c)
	return out

## {wins, fled, timeout, rounds, hp_frac} summed over n battles.
static func run_many(defs: Defs, enc: StringName, classes: Array[StringName], level: int, items: Dictionary,
		policy: String, n: int, seed0: int, log: bool = false) -> Dictionary:
	var st: Dictionary = {"wins": 0, "fled": 0, "timeout": 0, "rounds": 0, "hp_frac": 0.0}
	for i in n:
		var s: int = seed0 + i
		var party: Array[Character] = build_party(defs, classes, level)
		var b := Battle.new(enc, party, Rng.new(s), defs)
		b.inventory = items.duplicate()
		var r := Rng.new(s * 7919 + 17)
		var ev0: Array[Dictionary] = b.start()
		if log and i == 0: _log(b, -1, ev0)
		var guard: int = 0
		while not b.is_over() and guard < 20000:
			var uid: int = b.current_unit()
			var a: Dictionary
			if b.is_ai(uid): a = Ai.choose(b, uid, r)
			elif policy == "random": a = Ai.policy_random(b, uid, r)
			else: a = Ai.policy_good(b, uid, r)
			var ev: Array[Dictionary] = b.apply(a)
			if log and i == 0: _log(b, uid, ev)
			guard += 1
		var res: Dictionary = b.result()
		if res.outcome == "win": st.wins += 1
		if res.outcome == "fled": st.fled += 1
		if res.reason == "timeout": st.timeout += 1
		st.rounds += b.round
		var hp: int = 0
		var mx: int = 0
		for c in party:
			if not res.downed.has(c.id): hp += int(res.party_hp.get(c.id, 0))
			mx += c.max_hp
		st.hp_frac += float(hp) / maxf(1.0, float(mx))
	return st

static func _log(b: Battle, uid: int, ev: Array[Dictionary]) -> void:
	for e in ev:
		var who: Dictionary = b.unit(int(e.get("uid", e.get("target", uid))))
		var name: String = str(who.get("char_id", "")) if str(who.get("char_id", "")) != "" else str(who.get("def_id", ""))
		var parts: Array[String] = []
		for k in e:
			if k != "type": parts.append("%s=%s" % [k, e[k]])
		print("  r%d %-14s %-13s %s" % [b.round, name, e.type, " ".join(parts)])
