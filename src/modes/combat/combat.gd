## Combat mode. Reads Router.args {encounter_id, return_mode, return_args}, builds a Battle on the
## encounter's arena, and loops: party turns wait for clicks/keys, AI turns ask `ai_chooser`.
## Every action goes through battle.apply(); the events go to the EventPlayer and then to Bus.
## Holds no rules: what is legal comes from battle.legal_actions(), what happened from events.
extends Node2D

const EventPlayer := preload("res://src/modes/combat/event_player.gd")
const UnitView := preload("res://src/modes/combat/unit_view.gd")
const Overlay := preload("res://src/modes/combat/overlay.gd")
const CombatHud := preload("res://src/modes/combat/combat_hud.gd")
const Txt := preload("res://src/modes/combat/combat_text.gd")
const NO_CELL := Vector2i(-999, -999)
const TOP_STRIP: float = 18.0
const PAN_SPEED: float = 260.0
const FALLBACK_SPRITES: Dictionary = {"party": &"knight", "enemy": &"grazi_thrall", "big": &"giant_legs"}

## A party turn's choice (from clicks, keys or submit()).
signal action_chosen(action: Dictionary)
## The battle is over and its result applied; emitted before the banner and Router.go.
signal finished(result: Dictionary)

## Battle, or any object with the same methods (tests use a stub). Set before adding to the tree
## to skip building one from Router.args.
var battle: Object
var encounter_id: StringName = &""
var return_mode: StringName = &"worldmap"
var return_args: Dictionary = {}
## func(battle, uid: int, rng: Rng) -> Dictionary for AI-driven units. Defaults to Ai.choose.
var ai_chooser: Callable
## When valid, party turns are chosen by this too (smoke tests, demos). Same signature.
var party_chooser: Callable
## Apply battle.result() to Game.state through Encounters.apply_battle_result at the end.
var apply_result: bool = true
var auto_start: bool = true
## Seconds the result banner stays before returning (a click returns sooner).
var result_hold: float = 4.0
## Music and sound effects on (tests turn it off before adding the scene).
var audio: bool = true

var map_root: Node2D
var sorted_layer: Node2D
var overlay: Node2D
var fx_layer: Node2D
var camera: Camera2D
var hud: CanvasLayer
var player: Node
var awaiting_input: bool = false
var selected: int = -1
var done: bool = false
var result: Dictionary = {}
var returned: bool = false
## Flow.after_battle()'s answer: where the party wakes up (WP-30).
var after: Dictionary = {}

var _map_bounds: Rect2
var _moves: Dictionary = {}      # Vector2i -> Array[Vector2i]
var _buttons: Array[Dictionary] = []   # {kind: "ability"|"item", id, def, targets: {cell: true}}
var _can_flee: bool = false
var _ap_max: Dictionary = {}     # uid -> AP at turn start
var _fast: bool = false
var _hover: Vector2i = NO_CELL
var _drag_from: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _cam_tween: Tween
var _continue: bool = false

func _ready() -> void:
	var a: Dictionary = Router.args if Router.args is Dictionary else {}
	if battle == null and bool(a.get("debug_party", false)): _debug_party()
	if a.has("encounter_id"): encounter_id = StringName(str(a.encounter_id))
	var rm: String = str(a.get("return_mode", ""))
	return_mode = StringName(rm) if rm != "" else &"worldmap"
	var ra: Variant = a.get("return_args", {})
	return_args = ra if ra is Dictionary else {}
	if battle == null:
		battle = Battle.new(encounter_id, Game.state.party, Game.rng, Content.defs)
		(battle as Battle).inventory = Game.state.inventory.duplicate()
	elif encounter_id == &"":
		encounter_id = StringName(str(battle.get("encounter_id")))
	if not ai_chooser.is_valid(): ai_chooser = _default_ai
	_build_world()
	_build_hud()
	_build_player()
	for u in battle.units(): _add_unit(u)
	_frame_camera()
	_start_music()
	if auto_start: _run.call_deferred()

func _exit_tree() -> void:
	# Release a party turn that is still waiting, so its coroutine ends with the scene.
	if awaiting_input:
		awaiting_input = false
		action_chosen.emit({"_abort": true})

func _default_ai(b: Object, uid: int, rng: Rng) -> Dictionary:
	return Ai.choose(b as Battle, uid, rng)

## Shots and manual testing: a knight hero plus Vezina, without going through the menu.
func _debug_party() -> void:
	Game.new_game(1, &"knight")
	Rules.run([["recruit", "vezina"]], Game.state, Game.rng, Content.defs)

# ---- building -----------------------------------------------------------------

func _encounter_def() -> Dictionary:
	return Content.get_def(&"encounter", encounter_id) if Content.has(&"encounter", encounter_id) else {}

func _rules() -> Dictionary:
	var r: Variant = battle.get("rules")
	return r if r is Dictionary else {}

func _build_world() -> void:
	var map_id := StringName(str(_encounter_def().get("map", "")))
	map_root = MapBuilder.build(map_id, Content.defs)
	add_child(map_root)
	sorted_layer = map_root.get_node("Sorted")
	overlay = Overlay.new()
	overlay.name = "Overlay"
	overlay.z_index = -5
	overlay.sorted_layer = sorted_layer
	map_root.add_child(overlay)
	fx_layer = Node2D.new()
	fx_layer.name = "Fx"
	fx_layer.z_index = 50
	map_root.add_child(fx_layer)
	var size: Vector2i = map_root.get_meta("size", Vector2i(1, 1))
	var tl: Vector2 = Iso.cell_to_world(Vector2i(0, 0))
	var tr_: Vector2 = Iso.cell_to_world(Vector2i(size.x - 1, 0))
	var bl: Vector2 = Iso.cell_to_world(Vector2i(0, size.y - 1))
	var br: Vector2 = Iso.cell_to_world(Vector2i(size.x - 1, size.y - 1))
	_map_bounds = Rect2(Vector2(bl.x - 32, tl.y - 64), Vector2(tr_.x - bl.x + 64, br.y - tl.y + 64 + 16))
	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()
	if battle.has_method("hazards"):
		for h in battle.hazards():
			overlay.set_hazard(EventPlayer._cell(h.get("cell")), str(h.get("hazard", "")), int(h.get("turns", 1)))

func _build_hud() -> void:
	hud = CombatHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.ability_pressed.connect(select_button)
	hud.end_turn_pressed.connect(func() -> void: submit({"type": "end_turn"}))
	hud.flee_pressed.connect(func() -> void: if _can_flee: submit({"type": "flee"}))
	hud.result_closed.connect(func() -> void: _continue = true)
	hud.set_round(int(battle.get("round")) if battle.get("round") != null else 1)
	hud.set_timer(int(_rules().get("turn_limit", 0)))
	hud.set_controls(false, false)

func _build_player() -> void:
	player = EventPlayer.new()
	player.name = "EventPlayer"
	add_child(player)
	player.overlay = overlay
	player.fx_layer = fx_layer
	player.make_unit = _make_summon
	player.audio = audio
	player.turn_started.connect(func(uid: int, ap: int) -> void: _ap_max[uid] = ap)
	player.round_changed.connect(func(r: int) -> void: hud.set_round(r))
	player.timer_changed.connect(func(t: int) -> void:
		hud.set_timer(t)
		var limit: int = int(_rules().get("turn_limit", 0))
		if limit > 0: hud.set_round(limit - t + 1))
	player.banner.connect(func(text: String, alien: bool) -> void: hud.show_banner(text, alien, 0.6, player.speed))
	player.focus_requested.connect(focus)
	player.event_started.connect(_on_event_started)

func _on_event_started(e: Dictionary) -> void:
	if str(e.get("type", "")) == "turn_started":
		_frame_turn(int(e.get("uid", -1)))
		_refresh_hud()

## A UnitView for a battle unit dictionary.
func _add_unit(u: Dictionary) -> Node2D:
	var uid: int = int(u.get("uid", -1))
	var side: String = str(u.get("side", "enemy"))
	var size: int = int(u.get("size", 1))
	var is_char: bool = StringName(str(u.get("char_id", ""))) != &""
	var def_id := StringName(str(u.get("def_id", "")))
	var def: Dictionary = {}
	if is_char and Content.has(&"class", def_id): def = Content.get_def(&"class", def_id)
	elif Content.has(&"enemy", def_id): def = Content.get_def(&"enemy", def_id)
	var sprite_id := StringName(str(def.get("sprite", def_id)))
	var tint := Color.WHITE
	if not Assets.manifest.frames.has(String(sprite_id)):
		# No art yet (WP-25): borrow a real sheet so the arena still reads, tinted per def.
		sprite_id = FALLBACK_SPRITES.big if size > 1 else (FALLBACK_SPRITES.party if side == "party" else FALLBACK_SPRITES.enemy)
		tint = Color.from_hsv(float(hash(String(def_id)) % 360) / 360.0, 0.35, 1.0)
	var v: UnitView = UnitView.new()
	v.setup(uid, sprite_id, size, side, int(u.get("hp", 1)), int(u.get("max_hp", 1)), EventPlayer._cell(u.get("cell")), tint)
	v.summoned = bool(u.get("summoned", false))
	v.name_key = _name_key(u, def)
	v.downed = bool(u.get("downed", false))
	if side == "enemy": v.sprite.face("sw")
	var statuses: Variant = u.get("statuses", {})
	if statuses is Dictionary:
		for st in statuses: v.statuses[str(st)] = int((statuses[st] as Dictionary).get("turns", 1)) if statuses[st] is Dictionary else 1
	sorted_layer.add_child(v)
	player.units[uid] = v
	return v

func _make_summon(uid: int, _def_id: StringName, _cell: Vector2i) -> Node2D:
	var u: Dictionary = battle.unit(uid)
	if u.is_empty(): return null
	return _add_unit(u)

func _name_key(u: Dictionary, def: Dictionary) -> String:
	var cid := StringName(str(u.get("char_id", "")))
	if cid != &"":
		for ch in Game.state.party:
			if ch.id == cid: return ch.name_key
	return str(def.get("name_key", u.get("def_id", "")))

func _start_music() -> void:
	if not audio: return
	var map_def: Dictionary = {}
	var map_id := StringName(str(_encounter_def().get("map", "")))
	if Content.has(&"map", map_id): map_def = Content.get_def(&"map", map_id)
	var track := StringName(str(map_def.get("music", "")))
	if track == &"": track = &"saucer" if bool(_rules().get("magic_disabled", false)) else &"sarmizegetusa"
	Audio.play_music(track)
	Audio.set_layer(&"combat", true, 1.0)

# ---- turn loop ------------------------------------------------------------------

func _run() -> void:
	var ev: Array[Dictionary] = []
	ev.assign(battle.start())
	await _play(ev)
	var since_yield: int = 0
	var last_uid: int = -1
	var same: int = 0
	while not battle.is_over():
		var uid: int = battle.current_unit()
		if uid < 0: break
		var ai: bool = battle.is_ai(uid)
		if not ai and not party_chooser.is_valid():
			_begin_input(uid)
			var act: Dictionary = await action_chosen
			if not is_inside_tree() or act.has("_abort"): return
			_end_input()
			await _do(act, false)
			continue
		same = same + 1 if uid == last_uid else 0
		last_uid = uid
		var chooser: Callable = ai_chooser if ai else party_chooser
		var action: Dictionary = {"type": "end_turn"} if same > 60 else chooser.call(battle, uid, Game.rng)
		await _do(action, true)
		since_yield += 1
		if player.instant and since_yield >= 20:
			since_yield = 0
			await get_tree().process_frame
		elif not player.instant:
			await _pause(0.12)
	await _finish()

func _do(action: Dictionary, from_chooser: bool) -> void:
	var ev: Array[Dictionary] = []
	ev.assign(battle.apply(action))
	if ev.size() == 1 and str(ev[0].get("type", "")) == "illegal":
		if not from_chooser: return
		ev.assign(battle.apply({"type": "end_turn"}))
	await _play(ev)

func _play(ev: Array[Dictionary]) -> void:
	await player.play(ev)
	Bus.emit_events(ev)
	_refresh_hud()

func _pause(t: float) -> void:
	if player.instant: return
	await get_tree().create_timer(t / player.speed).timeout

func _finish() -> void:
	done = true
	awaiting_input = false
	hud.set_controls(false, false)
	overlay.clear_marks()
	result = battle.result()
	var outcome: String = str(result.get("outcome", ""))
	var ev: Array[Dictionary] = []
	if apply_result:
		ev.append_array(Encounters.apply_battle_result(encounter_id, result, Game.state, Game.rng, Content.defs))
		after = Flow.after_battle(encounter_id, result, Game.state, Game.rng, Content.defs)
		ev.append_array(after.events)
		if after.mode != &"":
			return_mode = after.mode
			return_args = after.args
	if outcome == "fled": ev.append({"type": "fled_battle"})
	Bus.emit_events(ev)
	finished.emit(result)
	if audio:
		Audio.set_layer(&"combat", false, 1.5)
		if outcome == "lose": Audio.stinger(&"defeat")
	hud.show_result(_result_title(outcome), _result_body(result))
	if not player.instant:
		var left: float = result_hold
		while left > 0.0 and not _continue and is_inside_tree():
			await get_tree().process_frame
			left -= get_process_delta_time()
	returned = true
	Router.go(return_mode, return_args)
	Flow.show_wake(after)

func _result_title(outcome: String) -> String:
	match outcome:
		"win": return tr("cbt_victory")
		"fled": return tr("cbt_fled")
	return tr("cbt_defeat")

func _result_body(r: Dictionary) -> String:
	var lines: Array[String] = [tr("cbt_reason_" + str(r.get("reason", "")))]
	var loot: Variant = r.get("loot", {})
	if str(r.get("outcome", "")) == "win":
		if loot is Dictionary and not (loot as Dictionary).is_empty():
			lines.append(tr("cbt_loot") + ":")
			var ids: Array = (loot as Dictionary).keys()
			ids.sort()
			for item in ids:
				var key: String = str(Content.get_def(&"item", StringName(str(item))).get("name_key", item)) if Content.has(&"item", StringName(str(item))) else str(item)
				lines.append(Txt.trf("cbt_item", [tr(key), int(loot[item])]))
		else:
			lines.append(tr("cbt_no_loot"))
	return "\n".join(lines)

# ---- party input ----------------------------------------------------------------

func _begin_input(uid: int) -> void:
	awaiting_input = true
	selected = -1
	_moves = {}
	_buttons = []
	_can_flee = false
	var u: Dictionary = battle.unit(uid)
	for ab_id in u.get("abilities", []):
		var id := StringName(str(ab_id))
		var def: Dictionary = Content.get_def(&"ability", id) if Content.has(&"ability", id) else {}
		_buttons.append({"kind": "ability", "id": id, "def": def, "targets": {}})
	var legal: Array = battle.legal_actions(uid)
	for a in legal:
		match str(a.get("type", "")):
			"flee":
				_can_flee = true
			"move":
				var path: Array = a.get("path", [])
				if not path.is_empty(): _moves[EventPlayer._cell(path[-1])] = path
			"ability":
				var b: Dictionary = _button_for("ability", StringName(str(a.get("ability", ""))))
				if not b.is_empty(): b.targets[EventPlayer._cell(a.get("cell"))] = true
			"item":
				var item := StringName(str(a.get("item", "")))
				var b: Dictionary = _button_for("item", item)
				if b.is_empty() and _buttons.size() < CombatHud.MAX_BUTTONS:
					var idef: Dictionary = Content.get_def(&"item", item) if Content.has(&"item", item) else {}
					var ab_id := StringName(str(idef.get("use_ability", "")))
					b = {"kind": "item", "id": item, "item_def": idef,
						"def": Content.get_def(&"ability", ab_id) if Content.has(&"ability", ab_id) else {}, "targets": {}}
					_buttons.append(b)
				if not b.is_empty(): b.targets[EventPlayer._cell(a.get("cell"))] = true
	hud.set_controls(true, _can_flee)
	_refresh_marks()
	_refresh_hud()
	_apply_debug_args()

## Screenshot helpers from Router.args: debug_select (button index), debug_hover ([x, y]).
func _apply_debug_args() -> void:
	var a: Dictionary = Router.args if Router.args is Dictionary else {}
	if a.has("debug_select"): select_button(int(a.debug_select))
	if a.has("debug_hover"):
		_hover = EventPlayer._cell(a.debug_hover)
		overlay.set_hover(_hover)
		_update_hover_marks()
		var v: Vector2 = get_viewport().get_canvas_transform() * map_root.to_global(Iso.cell_to_world(_hover))
		hud.show_tip(hud.tip_label.text if hud.tip_panel.visible else "", v)

func _button_for(kind: String, id: StringName) -> Dictionary:
	for b in _buttons:
		if b.kind == kind and b.id == id: return b
	return {}

func _end_input() -> void:
	awaiting_input = false
	selected = -1
	hud.set_controls(false, false)
	hud.show_tip("", Vector2.ZERO)
	overlay.clear_marks()

## Sends a party action (from UI, keys or tests). Ignored unless a party turn is waiting.
func submit(action: Dictionary) -> void:
	if not awaiting_input: return
	awaiting_input = false
	action_chosen.emit(action)

## Selects ability button i (0-based); self-targeted abilities fire at once. Again = cancel.
func select_button(i: int) -> void:
	if not awaiting_input or i < 0 or i >= _buttons.size(): return
	var b: Dictionary = _buttons[i]
	if (b.targets as Dictionary).is_empty(): return
	var is_self: bool = str(b.def.get("target", "")) == "self"
	if selected == i and is_self:
		_fire(i, (b.targets as Dictionary).keys()[0])
		return
	elif selected == i:
		selected = -1
	elif is_self and int(b.def.get("area", 0)) == 0:
		_fire(i, (b.targets as Dictionary).keys()[0])
		return
	else:
		selected = i
	_refresh_marks()
	_refresh_abilities()

func cancel_selection() -> void:
	if selected < 0: return
	selected = -1
	_refresh_marks()
	_refresh_abilities()

func _fire(i: int, cell: Vector2i) -> void:
	var b: Dictionary = _buttons[i]
	if b.kind == "item": submit({"type": "item", "item": b.id, "cell": cell})
	else: submit({"type": "ability", "ability": b.id, "cell": cell})

## The legal target cell of button i that the click at `cell` means, or NO_CELL. A click anywhere
## on a big unit counts.
func _target_for(i: int, cell: Vector2i) -> Vector2i:
	if i < 0 or i >= _buttons.size(): return NO_CELL
	var targets: Dictionary = _buttons[i].targets
	if targets.has(cell): return cell
	var uid: int = battle.unit_at(cell)
	if uid < 0: return NO_CELL
	for t in targets:
		if battle.unit_at(t) == uid: return t
	return NO_CELL

func click_cell(cell: Vector2i) -> void:
	if not awaiting_input: return
	if selected >= 0:
		var t: Vector2i = _target_for(selected, cell)
		if t != NO_CELL: _fire(selected, t)
		else:
			selected = -1
			_refresh_marks()
			_refresh_abilities()
		return
	if _moves.has(cell):
		submit({"type": "move", "path": _moves[cell]})
		return
	# Clicking an enemy with nothing selected uses the basic attack.
	var t0: Vector2i = _target_for(0, cell)
	if t0 != NO_CELL: _fire(0, t0)

func _refresh_marks() -> void:
	overlay.clear_marks()
	if not awaiting_input: return
	if selected >= 0:
		var b: Dictionary = _buttons[selected]
		overlay.target_cells = (b.targets as Dictionary).duplicate()
		overlay.target_friendly = str(b.def.get("target", "")) in ["ally", "self", "corpse", "machine"]
	else:
		for c in _moves: overlay.move_cells[c] = true
	_update_hover_marks()
	overlay.queue_redraw()

func _update_hover_marks() -> void:
	overlay.path_cells.clear()
	overlay.area_cells.clear()
	var tip: String = ""
	if awaiting_input and selected >= 0:
		var b: Dictionary = _buttons[selected]
		var t: Vector2i = _target_for(selected, _hover)
		if str(b.def.get("target", "")) == "self": t = (b.targets as Dictionary).keys()[0]
		if t != NO_CELL:
			var area: int = int(b.def.get("area", 0))
			if area > 0:
				for y in range(t.y - area, t.y + area + 1):
					for x in range(t.x - area, t.x + area + 1):
						if absi(x - t.x) + absi(y - t.y) <= area: overlay.area_cells.append(Vector2i(x, y))
			var tgt: int = battle.unit_at(t)
			if tgt >= 0 and not battle.are_allies(player.active_uid, tgt):
				tip = _unit_tip(tgt) + "\n" + Txt.trf("cbt_hit_chance", int(battle.hit_chance(player.active_uid, tgt, StringName(str(b.def.get("id", b.id))))))
	elif awaiting_input and _moves.has(_hover):
		for p in _moves[_hover]: overlay.path_cells.append(EventPlayer._cell(p))
	if tip == "" and _hover != NO_CELL:
		var uid: int = battle.unit_at(_hover)
		if uid >= 0:
			tip = _unit_tip(uid)
			if awaiting_input and selected < 0 and _target_for(0, _hover) != NO_CELL and not _buttons.is_empty():
				tip += "\n" + Txt.trf("cbt_hit_chance", int(battle.hit_chance(player.active_uid, uid, _buttons[0].id)))
	for v in player.units.values(): (v as UnitView).set_hovered(_hover != NO_CELL and battle.unit_at(_hover) == (v as UnitView).uid)
	hud.show_tip(tip, get_viewport().get_mouse_position())
	overlay.queue_redraw()

func _unit_tip(uid: int) -> String:
	var v: UnitView = player.units.get(uid)
	if v == null: return ""
	var s: String = "%s  %s %d/%d" % [tr(v.name_key), tr("cbt_hp"), v.hp, v.max_hp]
	for st in v.statuses: s += "\n" + tr("cbt_st_" + str(st)) + " (%d)" % int(v.statuses[st])
	return s

# ---- HUD ------------------------------------------------------------------------

func _refresh_hud() -> void:
	if hud == null or battle == null: return
	var entries: Array = []
	for uid in battle.turn_order():
		var v: UnitView = player.units.get(uid)
		if v == null: continue
		entries.append({"uid": uid, "name": tr(v.name_key), "side": v.side, "summoned": v.summoned,
			"active": uid == player.active_uid, "downed": v.downed})
	hud.set_turn_order(entries)
	var au: Dictionary = battle.unit(player.active_uid) if player.active_uid >= 0 else {}
	if not au.is_empty():
		var v: UnitView = player.units.get(player.active_uid)
		hud.set_active_unit({"name": tr(v.name_key) if v != null else "", "hp": v.hp if v != null else int(au.get("hp", 0)),
			"max_hp": int(au.get("max_hp", 0)), "mana": int(au.get("mana", 0)), "max_mana": int(au.get("max_mana", 0)),
			"charge": int(au.get("charge", 0)), "max_charge": int(au.get("max_charge", 0)),
			"ap": int(au.get("ap", 0)), "ap_max": int(_ap_max.get(player.active_uid, au.get("ap", 0)))})
	_refresh_abilities()

func _refresh_abilities() -> void:
	var items: Array = []
	var magic_off: bool = bool(_rules().get("magic_disabled", false))
	if awaiting_input:
		for i in _buttons.size():
			var b: Dictionary = _buttons[i]
			var d: Dictionary = b.def
			var label: String = tr(str(d.get("name_key", b.id)))
			if b.kind == "item":
				label = tr(str((b.item_def as Dictionary).get("name_key", b.id)))
			var src: String = str(d.get("source", "steel"))
			var sub: String = Txt.trf("cbt_ap_cost", int(d.get("ap", 0)))
			if src == "magic": sub = Txt.trf("cbt_mana_cost", [int(d.get("ap", 0)), int(d.get("cost", 0))])
			elif src == "tech": sub = Txt.trf("cbt_charge_cost", [int(d.get("ap", 0)), int(d.get("cost", 0))])
			var tip: String = "%s\n%s\n%s" % [label, tr(str(d.get("desc_key", ""))) if d.has("desc_key") else "",
				Txt.trf("cbt_range", [int(d.get("range", 0)), int(d.get("area", 0))])]
			var enabled: bool = not (b.targets as Dictionary).is_empty()
			if src == "magic" and magic_off:
				enabled = false
				sub = tr("cbt_magic_off")
				tip = tr("zalmoxis_cant_hear_you")
			items.append({"label": label, "sub": sub, "enabled": enabled, "tooltip": tip, "selected": i == selected})
	hud.set_abilities(items)

# ---- camera ---------------------------------------------------------------------

func _view_size() -> Vector2:
	return get_viewport_rect().size / camera.zoom

## Clamps a camera centre so the visible map area (between the top strip and the bottom bar)
## stays on the arena; centres the arena on an axis where it is smaller than the view.
func _clamp_cam(p: Vector2) -> Vector2:
	var vs: Vector2 = _view_size()
	var usable_h: float = vs.y - CombatHud.BAR_H - TOP_STRIP
	var off: float = (CombatHud.BAR_H - TOP_STRIP) / 2.0   # visible centre = camera.y - off
	var b: Rect2 = _map_bounds
	var out: Vector2 = p
	if b.size.x <= vs.x: out.x = b.get_center().x
	else: out.x = clampf(p.x, b.position.x + vs.x / 2.0, b.end.x - vs.x / 2.0)
	var vc: float = p.y - off
	if b.size.y <= usable_h: vc = b.get_center().y
	else: vc = clampf(vc, b.position.y + usable_h / 2.0, b.end.y - usable_h / 2.0)
	out.y = vc + off
	return out.round()

func _frame_camera() -> void:
	var sum := Vector2.ZERO
	var n: int = 0
	for v in player.units.values():
		sum += (v as Node2D).position
		n += 1
	var c: Vector2 = sum / n if n > 0 else _map_bounds.get_center()
	camera.position = _clamp_cam(c + Vector2(0, (CombatHud.BAR_H - TOP_STRIP) / 2.0))

## At a turn start, prefer a view of the whole fight (all units' centre) as long as the active
## unit stays well inside it; otherwise pan to the active unit.
func _frame_turn(uid: int) -> void:
	var v: UnitView = player.units.get(uid)
	if v == null or camera == null: return
	var box := Rect2(v.position, Vector2.ZERO)
	for u in player.units.values(): box = box.expand((u as Node2D).position)
	box = box.grow_individual(16, 50, 16, 8)   # heads above the feet
	var off: float = (CombatHud.BAR_H - TOP_STRIP) / 2.0
	var cand: Vector2 = _clamp_cam(box.get_center() + Vector2(0, off))
	var vs: Vector2 = _view_size()
	var usable := Vector2(vs.x, vs.y - CombatHud.BAR_H - TOP_STRIP)
	var safe := Rect2(cand - Vector2(0, off) - usable / 2.0 + Vector2(24, 48), usable - Vector2(48, 56))
	if safe.has_point(v.position): _pan_to(cand)
	else: focus(v.position)

func _pan_to(to: Vector2) -> void:
	if player.instant:
		camera.position = to
		return
	if _cam_tween != null: _cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.tween_property(camera, "position", to, 0.35 / player.speed).set_trans(Tween.TRANS_SINE)

## Pans so a map point is comfortably on screen (no move when it already is).
func focus(point: Vector2) -> void:
	if camera == null: return
	var vs: Vector2 = _view_size()
	var off: float = (CombatHud.BAR_H - TOP_STRIP) / 2.0
	var usable := Vector2(vs.x, vs.y - CombatHud.BAR_H - TOP_STRIP)
	# Visible map area centre is camera - off; keep the point inside its middle 80% x 70%.
	var inner := Rect2(camera.position - Vector2(0, off) - usable * Vector2(0.4, 0.35), usable * Vector2(0.8, 0.7))
	if inner.has_point(point): return
	_pan_to(_clamp_cam(point + Vector2(0, off)))

func _process(delta: float) -> void:
	if camera == null: return
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): d.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): d.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): d.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): d.y += 1
	if d != Vector2.ZERO:
		if _cam_tween != null: _cam_tween.kill()
		camera.position = _clamp_cam(camera.position + d * PAN_SPEED * delta)

# ---- input ----------------------------------------------------------------------

func set_fast(on: bool) -> void:
	_fast = on
	player.speed = 4.0 if on else 1.0
	hud.set_fast(on)

## Skips every animation wait (tests, max speed).
func set_instant(on: bool) -> void:
	player.instant = on

func unit_view(uid: int) -> Node2D:
	if player.units.has(uid): return player.units[uid]
	for v in player.corpses.values():
		if (v as UnitView).uid == uid: return v
	return null

## The cell under the mouse; a unit's body counts as its cell.
func _pick_cell() -> Vector2i:
	var p: Vector2 = map_root.get_local_mouse_position()
	var best: UnitView = null
	for v in player.units.values():
		var uv: UnitView = v
		if uv.hit_test(p) and (best == null or uv.position.y > best.position.y): best = uv
	if best != null: return best.cell
	var c: Vector2i = Iso.world_to_cell(p)
	var size: Vector2i = map_root.get_meta("size", Vector2i(1, 1))
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y: return NO_CELL
	return c

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _dragging:
			camera.position = _clamp_cam(camera.position - (event as InputEventMouseMotion).relative / camera.zoom)
		var c: Vector2i = _pick_cell()
		if c != _hover:
			_hover = c
			overlay.set_hover(c)
		_update_hover_marks()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if done: _continue = true
			else: click_cell(_pick_cell())
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_selection()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: Key = (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_8: select_button(k - KEY_1)
		elif k == KEY_SPACE:
			if done: _continue = true
			else: submit({"type": "end_turn"})
		elif k == KEY_ESCAPE: cancel_selection()
		elif k == KEY_TAB or k == KEY_F: set_fast(not _fast)
		elif k == KEY_ENTER and done: _continue = true
		else: return
		get_viewport().set_input_as_handled()
