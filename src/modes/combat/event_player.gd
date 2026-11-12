## Plays combat events strictly in order: walks, attacks, numbers, statuses, deaths, summons,
## pushes, drift, hazards, the timer. It changes only what is drawn; the Battle decides everything.
## Gore (WP-32) hooks in through unit_damaged / unit_died; nothing gory is drawn here.
extends Node

const UnitView := preload("res://src/modes/combat/unit_view.gd")
const Txt := preload("res://src/modes/combat/combat_text.gd")

const STEP_TIME: float = 0.16
const PUSH_STEP_TIME: float = 0.08
const FLOAT_TIME: float = 0.9
const ATTACK_MAX: float = 0.5
const HIT_PAUSE: float = 0.18

signal event_started(ev: Dictionary)
## Gore hook: one per `damaged` event, after the number shows. `view` is the UnitView node.
signal unit_damaged(uid: int, amount: int, crit: bool, view: Node2D)
## Gore hook: one per `died` event, as the death starts.
signal unit_died(uid: int, gib: bool, corpse: bool, view: Node2D)
signal turn_started(uid: int, ap: int)
signal timer_changed(turns_left: int)
signal round_changed(round: int)
signal battle_ended(outcome: String, reason: String)
## Big centred text (key already translated); the view shows it.
signal banner(text: String, alien: bool)
## The camera should look at this map-local point.
signal focus_requested(point: Vector2)

## 1 normal, 4 fast-forward. `instant` skips every wait (tests, max speed).
var speed: float = 1.0
var instant: bool = false
## False keeps it silent (tests: headless audio leaks stream playbacks at exit).
var audio: bool = true
var units: Dictionary = {}      # uid -> UnitView
var corpses: Dictionary = {}    # Vector2i -> UnitView (bodies that stay on the map)
var overlay: Node2D             # overlay.gd: hazards
var fx_layer: Node2D            # floating text parent (map-local coordinates)
## func(uid: int, def_id: StringName, cell: Vector2i) -> UnitView: builds a summoned unit.
var make_unit: Callable
var playing: bool = false
var active_uid: int = -1
var outcome: String = ""

func play(events: Array[Dictionary]) -> void:
	playing = true
	for e in events:
		await play_one(e)
	playing = false

func play_one(e: Dictionary) -> void:
	event_started.emit(e)
	match str(e.get("type", "")):
		"battle_started":
			round_changed.emit(int(e.get("round", 1)))
			banner.emit(tr("cbt_battle_start"), false)
			await _wait(0.5)
		"turn_started":
			_set_active(int(e.get("uid", -1)))
			var v: UnitView = units.get(active_uid)
			if v != null: focus_requested.emit(v.position)
			turn_started.emit(active_uid, int(e.get("ap", 0)))
			await _wait(0.15)
		"moved":
			await _walk(int(e.get("uid", -1)), e.get("path", []))
		"ability_used":
			await _ability(e)
		"missed":
			var t: UnitView = units.get(int(e.get("target", -1)))
			_sfx(&"miss")
			if t != null: _float(t, tr("cbt_miss"), Color("d8d0b8"))
			await _wait(HIT_PAUSE)
		"damaged":
			await _damaged(e)
		"healed":
			var t: UnitView = units.get(int(e.get("target", -1)))
			if t != null:
				t.set_hp(t.hp + int(e.get("amount", 0)))
				_float(t, "+%d" % int(e.get("amount", 0)), Color("8fe06a"))
			_sfx(&"heal")
			await _wait(HIT_PAUSE)
		"status":
			var t: UnitView = units.get(int(e.get("target", -1)))
			if t != null:
				t.add_status(str(e.get("status", "")), int(e.get("turns", 0)))
				_float(t, tr("cbt_st_" + str(e.get("status", ""))), UnitView._status_color(str(e.get("status", ""))))
			await _wait(HIT_PAUSE)
		"status_ended":
			var t: UnitView = units.get(int(e.get("target", -1)))
			if t != null: t.remove_status(str(e.get("status", "")))
		"pushed":
			await _slide(int(e.get("target", -1)), e.get("path", []), PUSH_STEP_TIME)
		"drifted":
			var v: UnitView = units.get(int(e.get("uid", -1)))
			if v != null: _float(v, tr("cbt_drift"), Color("5ff2e6"))
			await _slide(int(e.get("uid", -1)), [e.get("to")], 0.35)
		"died":
			await _died(e)
		"summoned":
			await _summoned(e)
		"hazard":
			if overlay != null:
				overlay.set_hazard(_cell(e.get("cell")), str(e.get("hazard", "")), int(e.get("turns", 0)))
		"timer":
			var left: int = int(e.get("turns_left", 0))
			timer_changed.emit(left)
			banner.emit(Txt.trf("cbt_timer_banner", left), true)
			_sfx(&"alarm")
			await _wait(0.7)
		"fled":
			var ok: bool = bool(e.get("success", false))
			banner.emit(tr("cbt_flee_ok") if ok else tr("cbt_flee_failed"), false)
			await _wait(0.6)
		"battle_ended":
			outcome = str(e.get("outcome", ""))
			_set_active(-1)
			battle_ended.emit(outcome, str(e.get("reason", "")))
		_:
			pass

# ---- handlers -----------------------------------------------------------------

func _set_active(uid: int) -> void:
	if units.has(active_uid): (units[active_uid] as UnitView).set_active(false)
	active_uid = uid
	if units.has(uid): (units[uid] as UnitView).set_active(true)

func _walk(uid: int, path: Array) -> void:
	var v: UnitView = units.get(uid)
	if v == null or path.is_empty(): return
	if instant:
		v.place(_cell(path[-1]))
		var prev: Vector2i = _cell(path[-2]) if path.size() > 1 else v.cell
		v.sprite.face(Iso.facing(prev, v.cell))
		return
	v.sprite.play(&"walk")
	for p in path:
		var c: Vector2i = _cell(p)
		v.sprite.face(Iso.facing(v.cell, c))
		v.sprite.play(&"walk")
		_sfx(&"step")
		await _tween_to(v, c, STEP_TIME)
		focus_requested.emit(v.position)
	v.sprite.play(&"idle")

func _slide(uid: int, path: Array, step_t: float) -> void:
	var v: UnitView = units.get(uid)
	if v == null or path.is_empty(): return
	for p in path:
		if instant: v.place(_cell(p))
		else: await _tween_to(v, _cell(p), step_t)

func _tween_to(v: UnitView, c: Vector2i, t: float) -> void:
	v.cell = c
	var tw: Tween = v.create_tween()
	tw.tween_property(v, "position", Iso.footprint_center(c, v.size), t / speed)
	await tw.finished

func _ability(e: Dictionary) -> void:
	var v: UnitView = units.get(int(e.get("uid", -1)))
	var ab_id := StringName(str(e.get("ability", "")))
	var ab: Dictionary = Content.get_def(&"ability", ab_id) if Content.has(&"ability", ab_id) else {}
	var src: String = str(ab.get("source", "steel"))
	if src == "tech": _sfx(&"beam")
	for eff in ab.get("effects", []):
		if str(eff.get("kind", "")) == "summon": _sfx(&"summon")
	if v == null: return
	var c: Vector2i = _cell(e.get("cell"))
	if c != v.cell: v.sprite.face(Iso.facing(v.cell, c))
	if ab.has("name_key"): _float(v, tr(str(ab.name_key)), Color("eadbb4"), 0.7)
	if instant: return
	v.sprite.animated_sprite().speed_scale = speed
	v.sprite.play(&"attack")
	await _wait(_anim_len(v, &"attack", ATTACK_MAX))
	if is_instance_valid(v):
		v.sprite.animated_sprite().speed_scale = 1.0
		v.sprite.play(&"idle")

func _damaged(e: Dictionary) -> void:
	var t: UnitView = units.get(int(e.get("target", -1)))
	var amount: int = int(e.get("amount", 0))
	var crit: bool = bool(e.get("crit", false))
	_sfx(&"crit" if crit else &"hit")
	if t == null: return
	t.set_hp(t.hp - amount)
	var txt: String = ("%s -%d" % [tr("cbt_crit"), amount]) if crit else "-%d" % amount
	_float(t, txt, Color("ff5a4a") if crit else Color("ffb070"), 1.0, 2 if crit else 1)
	var absorbed: int = int(e.get("shield_absorbed", 0))
	if absorbed > 0: _float(t, Txt.trf("cbt_absorbed", absorbed), Color("8fd06a"), 0.8, 1, Vector2(0, 12))
	unit_damaged.emit(t.uid, amount, crit, t)
	if instant: return
	if t.hp > 0: t.sprite.play(&"hit")
	await _wait(HIT_PAUSE)
	if is_instance_valid(t) and t.hp > 0: t.sprite.play(&"idle")

func _died(e: Dictionary) -> void:
	var uid: int = int(e.get("target", -1))
	var v: UnitView = units.get(uid)
	if v == null: return
	var corpse: bool = bool(e.get("corpse", false))
	var gib: bool = bool(e.get("gib", false))
	v.set_hp(0)
	v.clear_statuses()
	unit_died.emit(uid, gib, corpse, v)
	if v.side == "party" and not v.summoned:
		v.downed = true
		v.queue_redraw()
		_float(v, tr("cbt_downed"), Color("a8957a"))
		v.sprite.play(&"death")
		await _wait(_anim_len(v, &"death", 0.6))
		if not is_instance_valid(v): return
		v.modulate = Color(0.6, 0.6, 0.6)
		return
	units.erase(uid)
	v.sprite.play(&"death")
	await _wait(_anim_len(v, &"death", 0.6))
	if not is_instance_valid(v): return
	if corpse:
		v.is_corpse = true
		v.modulate = Color(0.55, 0.5, 0.5)
		v.queue_redraw()
		corpses[v.cell] = v
	elif instant:
		v.queue_free()
	else:
		var tw: Tween = v.create_tween()
		tw.tween_property(v, "modulate:a", 0.0, 0.3 / speed)
		await tw.finished
		if is_instance_valid(v): v.queue_free()

func _summoned(e: Dictionary) -> void:
	var c: Vector2i = _cell(e.get("cell"))
	if bool(e.get("from_corpse", false)) or corpses.has(c):
		var body: UnitView = corpses.get(c)
		corpses.erase(c)
		if body != null: body.queue_free()
	if not make_unit.is_valid(): return
	var v: UnitView = make_unit.call(int(e.get("uid", -1)), StringName(str(e.get("def_id", ""))), c)
	if v == null: return
	units[v.uid] = v
	_float(v, tr("cbt_risen") if bool(e.get("from_corpse", false)) else tr("cbt_summoned"), Color("8fd06a"))
	if instant: return
	v.scale = Vector2(0.2, 0.2)
	var tw: Tween = v.create_tween()
	tw.tween_property(v, "scale", Vector2.ONE, 0.25 / speed)
	await tw.finished

# ---- helpers ------------------------------------------------------------------

## Floating text above a unit; rises and fades on its own (never blocks the queue).
func _float(v: UnitView, text: String, col: Color, life: float = 1.0, scale_i: int = 1, offset: Vector2 = Vector2.ZERO) -> void:
	if fx_layer == null or instant: return
	var l := Label.new()
	l.theme = UiKit.theme()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", UiKit.INK)
	l.add_theme_constant_override("outline_size", 2)
	if scale_i > 1: l.scale = Vector2(scale_i, scale_i)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(120, 12)
	var stack: int = fx_layer.get_child_count() % 3
	l.position = v.position + v.head_offset() + offset - Vector2(60 * scale_i, 12 * scale_i + stack * 4)
	fx_layer.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14.0, FLOAT_TIME * life / speed)
	tw.parallel().tween_property(l, "modulate:a", 0.0, FLOAT_TIME * life / speed).set_delay(FLOAT_TIME * life * 0.5 / speed)
	tw.tween_callback(l.queue_free)

func _wait(t: float) -> void:
	if instant or t <= 0.0: return
	await get_tree().create_timer(t / speed).timeout

## Length in seconds (at speed 1) of the unit's current animation, capped.
func _anim_len(v: UnitView, _anim: StringName, cap: float) -> float:
	var a: AnimatedSprite2D = v.sprite.animated_sprite()
	var sf: SpriteFrames = a.sprite_frames
	var n: int = sf.get_frame_count(a.animation)
	var fps: float = maxf(1.0, sf.get_animation_speed(a.animation))
	return minf(cap, maxf(0.15, n / fps))

static func _cell(v: Variant) -> Vector2i:
	if v is Vector2i: return v
	if v is Array and (v as Array).size() == 2: return Vector2i(int(v[0]), int(v[1]))
	if v is Vector2: return Vector2i(v)
	return Vector2i(-1, -1)

func _sfx(id: StringName) -> void:
	if audio: Audio.sfx(id)
