## Gore and juice for the combat view (WP-32). Listens to the EventPlayer's signals and draws:
## deaths by Settings.gore, a 60 ms hit pause on crits, camera shake and push nudges, floaty
## bobbing, small hit puffs and ability fx. Presentation only: it never touches the Battle,
## Game.rng or the events, and its own randomness is a private RandomNumberGenerator.
##
## Deaths: gore 0 = fade + dust puff. Gore 1 = blood splat under the fall. Gore 2, or `gib` at
## gore >= 1 = chunks that stay, splat decals and a screen shake. A 2x2 giant at gore 2 pops like
## a water balloon and coats every cell around it. Machines leak oil and spark instead of bleeding.
## A downed party character is never gibbed (they are only resting, loudly).
extends Node

const Puff := preload("res://src/ui/fx/puff.gd")
const OneShot := preload("res://src/ui/fx/one_shot.gd")
const Gib := preload("res://src/modes/combat/fx/gib.gd")

const HIT_PAUSE: float = 0.06
const SPLATS: Array[StringName] = [&"fx_blood_splat_1", &"fx_blood_splat_2", &"fx_blood_splat_3"]
const GIBS: Array[StringName] = [&"fx_gib_1", &"fx_gib_2", &"fx_gib_3", &"fx_gib_4", &"fx_gib_5", &"fx_gib_6"]
const OIL := Color(0.32, 0.33, 0.42)
const DUST := Color(0.78, 0.72, 0.6, 0.85)
const SPARK := Color(1.0, 0.9, 0.45, 0.95)
const BLOOD_PUFF := Color(0.86, 0.16, 0.14, 0.9)
const SHAKE_DECAY: float = 18.0
const BOB_PX: float = 3.0

## 0 Off, 1 Normal, 2 Bloody Mess. Read from Settings.gore in setup(); tests may set it after.
var gore: int = 1
var player: Node
var fx_layer: Node2D
var decals: Node2D
var camera: Camera2D
var battle: Object
var grid: Grid
var floaty: bool = false
## Counters, for tests and curiosity.
var shakes: int = 0
var pauses: int = 0
var nudges: int = 0
## How many of each effect were spawned: dust puff splat gib balloon heal zap glyph.
var counts: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _shake: float = 0.0
var _nudge := Vector2.ZERO
var _nudge_tw: Tween
var _t: float = 0.0
var _paused: bool = false

## `view` is the combat view (combat.gd). Call after its player, map and camera exist.
func setup(view: Node2D) -> void:
	player = view.get("player")
	fx_layer = view.get("fx_layer")
	camera = view.get("camera")
	battle = view.get("battle")
	var map_root: Node2D = view.get("map_root")
	decals = Node2D.new()
	decals.name = "Decals"
	decals.z_index = -8   # over the ground (-10), under the overlay (-5) and the units
	map_root.add_child(decals)
	var g: Variant = map_root.get_meta("grid", null)
	grid = g if g is Grid else null
	gore = clampi(int(Settings.gore), 0, 2)
	var rules: Variant = battle.get("rules") if battle != null else null
	floaty = rules is Dictionary and str((rules as Dictionary).get("gravity", "normal")) == "floaty"
	_rng.seed = hash(str(view.get("encounter_id")))
	player.unit_damaged.connect(_on_damaged)
	player.unit_died.connect(_on_died)
	player.event_started.connect(_on_event)

func _exit_tree() -> void:
	if _paused: Engine.time_scale = 1.0
	_paused = false

func _count(kind: String) -> void:
	counts[kind] = int(counts.get(kind, 0)) + 1

func _instant() -> bool:
	return player == null or bool(player.get("instant"))

func _speed() -> float:
	return maxf(0.1, float(player.get("speed"))) if player != null else 1.0

# ---- signals ----------------------------------------------------------------------

func _on_event(e: Dictionary) -> void:
	match str(e.get("type", "")):
		"pushed": _on_pushed(e)
		"ability_used": _on_ability(e)
		"healed":
			var v: Node2D = player.units.get(int(e.get("target", -1)))
			if v != null and not _instant():
				_count("heal")
				OneShot.spawn(fx_layer, &"fx_heal_sparkle", &"play", _body(v), _speed())

func _on_damaged(uid: int, amount: int, crit: bool, view: Node2D) -> void:
	if view == null or _instant(): return
	if amount > 0:
		_count("puff")
		var col: Color = DUST if gore == 0 else (SPARK if _is_machine(uid) else BLOOD_PUFF)
		Puff.spawn(fx_layer, _body(view), col, 5.0 + (3.0 if crit else 0.0) + 2.0 * gore, _speed(), _rng.randi())
	if crit:
		shake(2.5)
		hit_pause()

func _on_died(uid: int, gib: bool, corpse: bool, view: Node2D) -> void:
	if view == null: return
	var size: int = int(view.get("size"))
	var cell: Vector2i = view.get("cell")
	var machine: bool = _is_machine(uid)
	if str(view.get("side")) == "party" and not bool(view.get("summoned")):
		# Downed, not dead: dust at 0, a modest splat otherwise. Never chunks.
		if gore == 0: _dust(view)
		else: _splat(cell, machine, 0.6, 0.25)
		return
	if gore == 0:
		_dust(view)
	elif not (gore == 2 or gib):
		_splat(cell, machine, 1.0, 0.3)   # lands as the body falls
		if size > 1: _splat(cell + Vector2i(1, 1), machine, 1.0, 0.3)
	elif size > 1 and gore == 2:
		_balloon(view, machine, corpse)
	else:
		_burst(view, machine, corpse)

func _on_pushed(e: Dictionary) -> void:
	var v: Node2D = player.units.get(int(e.get("target", -1)))
	var path: Array = e.get("path", [])
	if v == null or path.is_empty(): return
	var to: Vector2i = _cell(path[-1])
	var dir: Vector2 = (Iso.cell_to_world(to) - Iso.cell_to_world(v.get("cell"))).normalized()
	nudge(dir * 4.0)

func _on_ability(e: Dictionary) -> void:
	if _instant(): return
	var ab_id := StringName(str(e.get("ability", "")))
	if not Content.has(&"ability", ab_id): return
	var ab: Dictionary = Content.get_def(&"ability", ab_id)
	var c: Vector2i = _cell(e.get("cell"))
	var p: Vector2 = Iso.cell_to_world(c)
	var target: Node2D = _unit_at(c)
	if target != null: p = target.position
	match str(ab.get("source", "steel")):
		"magic":
			_count("glyph")
			OneShot.spawn(fx_layer, &"fx_magic_glyph", &"play", p, _speed(), 0.7)
		"tech":
			_count("zap")
			OneShot.spawn(fx_layer, &"fx_tech_zap", &"play", (_body(target) if target != null else p - Vector2(0, 16)), _speed())

# ---- deaths ---------------------------------------------------------------------

func _dust(view: Node2D) -> void:
	_count("dust")
	if _instant(): return
	var size: int = int(view.get("size"))
	Puff.spawn(fx_layer, view.position - Vector2(0, 4), DUST, 9.0 * size, _speed(), _rng.randi())

## Chunks: hide the body, scatter gibs that stay, splats around the cell, shake.
func _burst(view: Node2D, machine: bool, _corpse: bool) -> void:
	_hide_body(view)
	var cell: Vector2i = view.get("cell")
	_splat(cell, machine, 1.15, 0.0)
	for i in 2:
		var n: Vector2i = cell + [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)][_rng.randi() % 4]
		_splat(n, machine, 0.7, 0.0, true)
	_gibs(view, 6, 30.0, machine)
	if not _instant():
		Puff.spawn(fx_layer, _body(view), SPARK if machine else BLOOD_PUFF, 12.0, _speed(), _rng.randi())
	shake(4.0)

## Water-balloon pop for a 2x2 giant: burst anim, every cell around the footprint coated.
func _balloon(view: Node2D, machine: bool, _corpse: bool) -> void:
	_hide_body(view)
	var cell: Vector2i = view.get("cell")
	_count("balloon")
	if not _instant():
		var b: AnimatedSprite2D = OneShot.spawn(fx_layer, &"fx_balloon_burst", &"burst", view.position - Vector2(0, 56), _speed())
		b.scale = Vector2(1.6, 1.6)
	for y in range(cell.y - 1, cell.y + 3):
		for x in range(cell.x - 1, cell.x + 3):
			_splat(Vector2i(x, y), machine, _rng.randf_range(0.9, 1.3), 0.08, true)
	_gibs(view, 8, 56.0, machine)
	shake(7.0)

func _hide_body(view: Node2D) -> void:
	var s: Variant = view.get("sprite")
	if s is Node2D: (s as Node2D).visible = false

func _gibs(view: Node2D, n: int, spread: float, machine: bool) -> void:
	var from: Vector2 = _body(view)
	for i in n:
		_count("gib")
		var g: Sprite2D = Gib.new()
		g.texture = Assets.tex(GIBS[_rng.randi() % GIBS.size()])
		g.rotation = _rng.randf_range(0.0, TAU)
		g.flip_h = _rng.randf() < 0.5
		if machine: g.modulate = OIL.lightened(0.35)
		var a: float = _rng.randf_range(0.0, TAU)
		var r: float = _rng.randf_range(spread * 0.35, spread)
		g.from = from
		g.to = view.position + Vector2(cos(a) * r, sin(a) * r * 0.5)
		g.height = view.position.y - from.y
		g.arc = _rng.randf_range(14.0, 34.0)
		g.decals = decals
		g.add_to_group(&"fx_gib")
		g.add_to_group(&"fx_gib_flying")
		fx_layer.add_child(g)
		if _instant(): g.land()
		else: g.launch(_rng.randf_range(0.45, 0.7) / _speed(), _rng.randf_range(-9.0, 9.0))

## A splat decal on a cell's floor; grows in after `delay` seconds. Stays for the battle.
func _splat(cell: Vector2i, machine: bool, scale_k: float, delay: float, skip_walls: bool = false) -> void:
	if grid != null:
		if not grid.in_bounds(cell): return
		if skip_walls and not grid.is_walkable(cell): return
	_count("splat")
	var s := Sprite2D.new()
	s.texture = Assets.tex(SPLATS[_rng.randi() % SPLATS.size()])
	s.flip_h = _rng.randf() < 0.5
	s.position = Iso.cell_to_world(cell) + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-3, 3))
	if machine: s.modulate = OIL
	s.add_to_group(&"fx_splat")
	s.add_to_group(&"fx_decal")
	decals.add_child(s)
	var full := Vector2(scale_k, scale_k)
	if _instant():
		s.scale = full
		return
	s.scale = full * 0.2
	var tw: Tween = s.create_tween()
	if delay > 0.0: tw.tween_interval(delay / _speed())
	tw.tween_property(s, "scale", full, 0.18 / _speed()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---- camera and time ------------------------------------------------------------

## Screen shake of `amount` pixels, decaying. Ignored at instant playback.
func shake(amount: float) -> void:
	if _instant() or camera == null: return
	shakes += 1
	_shake = maxf(_shake, amount)

## A short camera push in `offset` direction and back.
func nudge(offset: Vector2) -> void:
	if _instant() or camera == null: return
	nudges += 1
	if _nudge_tw != null and _nudge_tw.is_valid(): _nudge_tw.kill()
	_nudge_tw = create_tween()
	_nudge_tw.tween_property(self, "_nudge", offset, 0.06 / _speed())
	_nudge_tw.tween_property(self, "_nudge", Vector2.ZERO, 0.16 / _speed()).set_trans(Tween.TRANS_SINE)

## Freezes game time for 60 ms (real time). Waits already queued just run 60 ms later.
func hit_pause() -> void:
	if _instant() or _paused or not is_inside_tree(): return
	pauses += 1
	_paused = true
	Engine.time_scale = 0.0
	await get_tree().create_timer(HIT_PAUSE, true, false, true).timeout
	Engine.time_scale = 1.0
	_paused = false

func _process(delta: float) -> void:
	var real: float = delta if Engine.time_scale > 0.0 else 0.0
	_t += real
	if camera != null:
		var jitter := Vector2.ZERO
		if _shake > 0.05:
			jitter = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake
			_shake = maxf(0.0, _shake - SHAKE_DECAY * real)
		else:
			_shake = 0.0
		camera.offset = (jitter + _nudge).round()
	_bob()

## Units float gently while gravity is floaty (or while standing in a gravity zone).
func _bob() -> void:
	if player == null: return
	var ov: Node = player.get("overlay")
	for v in player.units.values():
		var view: Node2D = v
		var s: Node2D = view.get("sprite")
		if s == null: continue
		var up: bool = (floaty or (ov != null and ov.has_method("has_hazard") and ov.has_hazard(view.get("cell"), "gravity_zone"))) \
			and not bool(view.get("downed")) and not bool(view.get("is_corpse"))
		s.position.y = (-BOB_PX - sin(_t * 2.6 + float(view.get("uid"))) * BOB_PX) if up else 0.0

# ---- helpers --------------------------------------------------------------------

## Middle of a unit's body (feet minus half its height).
func _body(view: Node2D) -> Vector2:
	var head: Vector2 = view.call("head_offset") if view.has_method("head_offset") else Vector2(0, -40)
	return view.position + Vector2(0, head.y * 0.5)

func _unit_at(c: Vector2i) -> Node2D:
	for v in player.units.values():
		var view: Node2D = v
		var vc: Vector2i = view.get("cell")
		var n: int = int(view.get("size"))
		if c.x >= vc.x and c.y >= vc.y and c.x < vc.x + n and c.y < vc.y + n: return view
	return null

func _is_machine(uid: int) -> bool:
	if battle == null or not battle.has_method("unit"): return false
	var u: Dictionary = battle.unit(uid)
	var def_id := StringName(str(u.get("def_id", "")))
	if not Content.has(&"enemy", def_id): return false
	return bool(Content.get_def(&"enemy", def_id).get("machine", false))

static func _cell(v: Variant) -> Vector2i:
	if v is Vector2i: return v
	if v is Array and (v as Array).size() == 2: return Vector2i(int(v[0]), int(v[1]))
	if v is Vector2: return Vector2i(v)
	return Vector2i(-1, -1)
