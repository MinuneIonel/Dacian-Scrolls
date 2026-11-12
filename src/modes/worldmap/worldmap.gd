## World map mode: Fallout-style travel. Click a cell to preview the route (hours, food), click it
## again to go. Each Travel.step is animated, broadcast with Bus.emit_events, and the journey
## stops on encounter, abducted, arrived or discovered. Never decides outcomes itself.
## Router.args: {} normally; debug: {debug_party: true, debug_reveal_all: true, debug_encounter: id}.
extends Control

const MapCanvas := preload("res://src/modes/worldmap/map_canvas.gd")
const FogLayer := preload("res://src/modes/worldmap/fog_layer.gd")
const UfoShadow := preload("res://src/modes/worldmap/ufo_shadow.gd")

const CELL: int = 16
const MANIFEST: String = "res://assets/worldmap/manifest_worldmap.json"
const HUD_H: float = 20.0
const PAN_SPEED: float = 260.0
const EDGE: float = 6.0
const DRAG_THRESHOLD: float = 4.0
const FOLLOW_MARGIN: float = 64.0
const NIGHT := Color(0.05, 0.07, 0.22, 0.42)

## Seconds per Travel.step while travelling. Tests may set 0.
var step_time: float = 0.15
var defs: Defs
var traveling: bool = false
## The previewed route (click the same cell again to go).
var pending_target: Vector2i = Vector2i(-1, -1)
var pending_path: Array[Vector2i] = []
var travel_path: Array[Vector2i] = []
## The encounter whose panel is open, or &"".
var encounter_id: StringName = &""
var option_ids: Array[String] = []
var option_buttons: Array[Button] = []
## The open modal panel (encounter or enter prompt), or null.
var modal: Control
var enter_location: StringName = &""
var cam: Vector2 = Vector2.ZERO
var cam_target: Vector2 = Vector2.ZERO
var following: bool = true

var map_view: Control
var world: Node2D
var canvas: MapCanvas                # terrain, under the fog
var overlay: MapCanvas               # route and markers, above the fog
var fog: FogLayer
var ufo_layer: Node2D
var party_sprite: Sprite2D
var night_tint: ColorRect
var tooltip: PanelContainer
var tooltip_label: Label
var hud_clock: Label
var hud_food: Label
var hud_gold: Label
var hud_pages: Label
var btn_party: Button
var btn_scroll: Button
var ufo_nodes: Dictionary = {}       # ufo id -> UfoShadow

var _textures: Dictionary = {}
var _step_accum: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _pressed: bool = false
var _dragging: bool = false
var _mouse_seen: bool = false
var _lobizi_on: bool = false

func _ready() -> void:
	defs = Content.defs
	var args: Dictionary = Router.args if Router.args is Dictionary else {}
	if bool(args.get("debug_party", false)):
		Game.new_game(1, &"knight")
		Game.state.mode = &"worldmap"
	if bool(args.get("debug_reveal_all", false)):
		var size: Vector2i = Travel.world_size(defs)
		Fog.reveal(Game.state, Vector2i.ZERO, maxi(size.x, size.y), size)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	_load_textures()
	_build()
	_center_on_party(true)
	refresh_hud()
	Audio.play_music(&"sarmizegetusa")
	_update_music()
	var dbg: String = str(args.get("debug_encounter", ""))
	if dbg != "": open_encounter(StringName(dbg))

# ---------------------------------------------------------------- building

func _load_textures() -> void:
	if not FileAccess.file_exists(MANIFEST): return
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (m is Dictionary): return
	var tex: Variant = m.get("textures", {})
	if not (tex is Dictionary): return
	for id in tex:
		var t: Texture2D = Assets.load_png(str(tex[id]))
		if t != null: _textures[str(id)] = t

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	map_view = Control.new()
	map_view.name = "MapView"
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.clip_contents = true
	map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	map_view.gui_input.connect(_on_map_input)
	add_child(map_view)

	world = Node2D.new()
	world.name = "World"
	map_view.add_child(world)
	canvas = MapCanvas.new()
	canvas.setup(defs, _textures.get("worldmap_terrain"), _textures)
	world.add_child(canvas)
	fog = FogLayer.new()
	world.add_child(fog)
	fog.setup(Travel.world_size(defs))
	overlay = MapCanvas.new()
	overlay.overlay = true
	overlay.setup(defs, null, _textures)
	world.add_child(overlay)
	ufo_layer = Node2D.new()
	world.add_child(ufo_layer)
	party_sprite = Sprite2D.new()
	party_sprite.centered = false
	party_sprite.texture = _textures.get("worldmap_party", Assets.placeholder())
	party_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(party_sprite)
	_build_ufos()
	_place_party(Game.state.world_pos, 0.0)

	night_tint = ColorRect.new()
	night_tint.color = NIGHT
	night_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	night_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.add_child(night_tint)

	tooltip = UiKit.panel()
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label = UiKit.label("")
	tooltip.add_child(tooltip_label)
	tooltip.visible = false
	map_view.add_child(tooltip)

	_build_hud()

func _build_hud() -> void:
	var bar := UiKit.panel()
	bar.name = "Hud"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, HUD_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiKit.UMBER_DARK, 0.94)
	sb.border_color = UiKit.BRONZE
	sb.border_width_bottom = 1
	sb.content_margin_left = 6; sb.content_margin_right = 4
	sb.content_margin_top = 2; sb.content_margin_bottom = 2
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	hud_clock = UiKit.label("")
	hud_food = UiKit.label("")
	hud_gold = UiKit.label("")
	hud_pages = UiKit.label("")
	for l in [hud_clock, hud_food, hud_gold, hud_pages]:
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	btn_party = UiKit.button("wm_party")
	btn_party.pressed.connect(_on_party)
	row.add_child(btn_party)
	btn_scroll = UiKit.button("wm_scroll")
	btn_scroll.pressed.connect(_on_scroll)
	row.add_child(btn_scroll)

func _build_ufos() -> void:
	for u in Game.state.ufos:
		var id := StringName(str(u.get("id", "")))
		var n: UfoShadow = UfoShadow.new(id)
		ufo_layer.add_child(n)
		ufo_nodes[id] = n
		n.place(Rules.to_cell(u.get("pos", Vector2i.ZERO)))
		n.set_state(str(u.get("state", "patrol")))
	_update_ufo_fog()

# ---------------------------------------------------------------- input and camera

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = true
		var mm := event as InputEventMouseMotion
		var panning: bool = (mm.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0
		if _pressed and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD: _dragging = true
		if panning or _dragging:
			following = false
			cam -= mm.relative
			_apply_cam()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT: return
		if mb.pressed:
			_pressed = true
			_dragging = false
			_press_pos = mb.position
		else:
			var was_drag: bool = _dragging
			_pressed = false
			_dragging = false
			if not was_drag: click_cell(cell_at(mb.position))
		accept_event()

## The map cell under a point in map_view's local coordinates.
func cell_at(local: Vector2) -> Vector2i:
	var p: Vector2 = local + cam
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

## The point in map_view's local coordinates at a cell's centre.
func screen_of(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0) - cam

func _process(delta: float) -> void:
	_pan(delta)
	if following:
		cam = cam.lerp(cam_target, minf(1.0, delta * 6.0))
		_apply_cam()
	if traveling:
		_step_accum += delta
		if _step_accum >= step_time:
			_step_accum = 0.0
			_do_step()

func _pan(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
	if _mouse_seen and modal == null and get_window().has_focus():
		var m: Vector2 = get_local_mouse_position()
		var s: Vector2 = size
		if m.x >= 0 and m.y >= 0 and m.x <= s.x and m.y <= s.y:
			if m.x < EDGE: dir.x -= 1
			elif m.x > s.x - EDGE: dir.x += 1
			if m.y < EDGE: dir.y -= 1
			elif m.y > s.y - EDGE: dir.y += 1
	if dir == Vector2.ZERO: return
	following = false
	cam += dir.normalized() * PAN_SPEED * delta
	_apply_cam()

func _clamp_cam(c: Vector2) -> Vector2:
	var map_px := Vector2(Travel.world_size(defs) * CELL)
	var view: Vector2 = map_view.size if map_view != null and map_view.size != Vector2.ZERO else size
	var out := c
	for axis in 2:
		var lo: float = -32.0 - (HUD_H if axis == 1 else 0.0)
		var hi: float = map_px[axis] - view[axis] + 32.0
		out[axis] = (map_px[axis] - view[axis]) / 2.0 if hi < lo else clampf(c[axis], lo, hi)
	return out

func _apply_cam() -> void:
	cam = _clamp_cam(cam)
	if world != null: world.position = -cam.round()
	_position_tooltip()

func _center_on_party(snap: bool) -> void:
	var view: Vector2 = map_view.size if map_view.size != Vector2.ZERO else get_viewport_rect().size
	cam_target = _clamp_cam(Vector2(Game.state.world_pos * CELL) + Vector2(CELL, CELL) / 2.0 - view / 2.0)
	following = true
	if snap:
		cam = cam_target
		_apply_cam()

## Re-centres when the party nears the edge of the view.
func _keep_party_in_view() -> void:
	var p: Vector2 = screen_of(Game.state.world_pos)
	var view: Vector2 = map_view.size
	if p.x < FOLLOW_MARGIN or p.y < FOLLOW_MARGIN + HUD_H or p.x > view.x - FOLLOW_MARGIN or p.y > view.y - FOLLOW_MARGIN:
		_center_on_party(false)

# ---------------------------------------------------------------- travel

## Click on a map cell: preview the route, or start travelling on a second click.
## Unreachable cells clear the preview and do nothing else.
func click_cell(c: Vector2i) -> void:
	if traveling or modal != null: return
	var st: GameState = Game.state
	if c == st.world_pos:
		_clear_pending()
		var here: StringName = location_at(c)
		if here != &"": show_enter_prompt(here)
		return
	if c == pending_target and not pending_path.is_empty():
		start_travel()
		return
	var p: Array[Vector2i] = Travel.path(st, c, defs)
	if p.is_empty():
		_clear_pending()
		return
	pending_target = c
	pending_path = p
	overlay.route = p.duplicate()
	overlay.queue_redraw()
	var cost: Vector2i = route_cost(p)
	if st.food < cost.y:
		tooltip_label.text = tr("wm_cost_hungry") % [cost.x, cost.y, st.food]
	else:
		tooltip_label.text = tr("wm_cost") % [cost.x, cost.y]
	tooltip_label.text += "\n" + tr("wm_click_again")
	tooltip.visible = true
	tooltip.reset_size()
	_position_tooltip()

## Total hours and food eaten along a route from the current time: Vector2i(hours, food).
func route_cost(p: Array[Vector2i]) -> Vector2i:
	var hours: int = 0
	for c in p: hours += Travel.hours_at(c, defs)
	var midnights: int = (Game.state.hour + hours) / 24
	return Vector2i(hours, midnights * Game.state.party.size())

func start_travel() -> void:
	if pending_path.is_empty(): return
	travel_path = pending_path.duplicate()
	traveling = true
	_step_accum = 0.0
	tooltip.visible = false
	pending_target = Vector2i(-1, -1)
	pending_path = []

func stop_travel() -> void:
	traveling = false
	travel_path = []
	overlay.route = []
	overlay.queue_redraw()

func _clear_pending() -> void:
	pending_target = Vector2i(-1, -1)
	pending_path = []
	tooltip.visible = false
	overlay.route = []
	overlay.queue_redraw()

func _do_step() -> void:
	if travel_path.is_empty():
		stop_travel()
		return
	var next: Vector2i = travel_path.pop_front()
	var events: Array[Dictionary] = Travel.step(Game.state, next, Game.rng, defs)
	if events.is_empty():
		stop_travel()
		return
	overlay.route = travel_path.duplicate()
	Bus.emit_events(events)
	_play(events)
	Audio.sfx(&"step")
	var abd: Dictionary = _first(events, "abducted")
	var enc: Dictionary = _first(events, "encounter")
	var arr: Dictionary = _first(events, "arrived")
	if not abd.is_empty():
		stop_travel()
		play_abduction(StringName(str(abd.get("ufo", ""))), StringName(str(abd.get("encounter", ""))))
	elif not enc.is_empty():
		stop_travel()
		open_encounter(StringName(str(enc.get("encounter", ""))))
	elif not arr.is_empty():
		stop_travel()
		show_enter_prompt(StringName(str(arr.get("location", ""))))
	elif _has(events, "discovered") or travel_path.is_empty():
		stop_travel()

## Animates the events' visible side: party, UFOs, fog, markers, HUD, music.
func _play(events: Array[Dictionary]) -> void:
	var fog_dirty: bool = false
	for e in events:
		match str(e.get("type", "")):
			"stepped":
				_place_party(Rules.to_cell(e.get("pos")), step_time * 0.9)
			"teleported":
				_place_party(Game.state.world_pos, 0.0)
				_center_on_party(false)
			"revealed", "discovered":
				fog_dirty = true
			"ufo_moved":
				var n: UfoShadow = ufo_nodes.get(StringName(str(e.get("id", ""))))
				if n != null:
					n.place(Rules.to_cell(e.get("pos")), step_time * 0.9)
					n.set_state(str(e.get("state", "patrol")))
	if fog_dirty:
		fog.rebuild()
		_update_ufo_fog()
	canvas.queue_redraw()
	overlay.queue_redraw()
	refresh_hud()
	_update_music()
	_keep_party_in_view()

func _place_party(c: Vector2i, animate_s: float) -> void:
	var to := Vector2(c.x * CELL + CELL / 2.0 - 5.0, c.y * CELL + CELL - 23.0)
	if _has_location_marker(c): to += Vector2(10, -6)   # stand beside the marker, not on it
	if animate_s <= 0.0:
		party_sprite.position = to
		return
	var tw: Tween = party_sprite.create_tween()
	tw.tween_property(party_sprite, "position", to, animate_s)

func _update_ufo_fog() -> void:
	for u in Game.state.ufos:
		var n: UfoShadow = ufo_nodes.get(StringName(str(u.get("id", ""))))
		if n != null: n.fogged = not Fog.is_revealed(Game.state, Rules.to_cell(u.get("pos", Vector2i.ZERO)))

func _update_music() -> void:
	var chase: bool = Game.state.ufos.any(func(u: Dictionary) -> bool: return str(u.get("state", "")) == "chase")
	if chase != _lobizi_on:
		_lobizi_on = chase
		Audio.set_layer(&"lobizi", chase, 2.0)

func _has_location_marker(c: Vector2i) -> bool:
	return location_at(c) != &""

## The discovered location on a cell, or &"".
func location_at(c: Vector2i) -> StringName:
	var w: Variant = defs.json("world")
	if not (w is Dictionary): return &""
	for loc in w.get("locations", []):
		var id := StringName(str(loc.get("id", "")))
		if Rules.to_cell(loc.get("cell", [])) == c and Game.state.discovered.has(id): return id
	return &""

func _position_tooltip() -> void:
	if tooltip == null or not tooltip.visible or pending_path.is_empty(): return
	var p: Vector2 = screen_of(pending_target) + Vector2(10, -tooltip.size.y - 6)
	var view: Vector2 = map_view.size
	p.x = clampf(p.x, 2.0, maxf(2.0, view.x - tooltip.size.x - 2.0))
	p.y = clampf(p.y, HUD_H + 2.0, maxf(HUD_H + 2.0, view.y - tooltip.size.y - 2.0))
	tooltip.position = p.round()

# ---------------------------------------------------------------- HUD

func refresh_hud() -> void:
	var st: GameState = Game.state
	hud_clock.text = tr("wm_clock") % [st.day, st.hour]
	if st.is_night(): hud_clock.text += "  " + tr("wm_night")
	hud_food.text = tr("wm_food") % st.food
	hud_gold.text = tr("wm_gold") % st.gold
	var total: int = defs.all(&"page").size()
	hud_pages.text = tr("wm_pages") % [st.pages.size(), total if total > 0 else 12]
	night_tint.visible = st.is_night()

func _on_party() -> void:
	if modal != null or traveling: return
	PartyScreen.show_over(self)

func _on_scroll() -> void:
	if modal != null or traveling: return
	Router.go(&"scroll")

# ---------------------------------------------------------------- panels

func _open_modal(content: Control) -> void:
	_close_modal()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var p := UiKit.panel()
	center.add_child(p)
	p.add_child(content)
	add_child(shade)
	modal = shade

func _close_modal() -> void:
	if modal != null and is_instance_valid(modal): modal.queue_free()
	modal = null
	encounter_id = &""
	option_ids = []
	option_buttons = []
	enter_location = &""

## Encounter panel: intro text and the options from Encounters.options with their roll chance.
func open_encounter(id: StringName) -> void:
	var enc: Dictionary = defs.get_def(&"encounter", id)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	var title: Label = UiKit.label("wm_encounter_title")
	title.theme_type_variation = &"DimLabel"
	box.add_child(title)
	var intro: Label = UiKit.label(str(enc.get("intro_key", "")))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(320, 0)
	box.add_child(intro)
	box.add_child(HSeparator.new())
	_open_modal(box)
	encounter_id = id
	var rolls: Dictionary = {}
	for o in enc.get("options", []):
		if o is Dictionary and o.get("roll") is Dictionary: rolls[str(o.get("id", ""))] = true
	for o in Encounters.options(id, Game.state, defs):
		var b: Button = UiKit.button(str(o.label_key))
		if rolls.has(str(o.id)):
			b.text = tr("wm_option_chance") % [tr(str(o.label_key)), int(o.chance)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var oid: String = str(o.id)
		b.pressed.connect(func() -> void: choose_option(oid))
		box.add_child(b)
		option_ids.append(oid)
		option_buttons.append(b)
	if not option_buttons.is_empty(): option_buttons[0].grab_focus.call_deferred()

## Runs an encounter option through core. A battle goes to combat; anything else shows the outcome.
func choose_option(option_id: String) -> void:
	if encounter_id == &"": return
	var id: StringName = encounter_id
	var events: Array[Dictionary] = Encounters.choose(id, option_id, Game.state, Game.rng, defs)
	if events.is_empty() and option_id != "flee": return
	Bus.emit_events(events)
	_play(events)
	var battle: Dictionary = _first(events, "battle_requested")
	if not battle.is_empty():
		_close_modal()
		var enc_id: StringName = StringName(str(battle.get("encounter", id)))
		Router.go(&"combat", {"encounter_id": enc_id, "return_mode": &"worldmap", "return_args": {}})
		return
	_show_outcome(events)

func _show_outcome(events: Array[Dictionary]) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	var lines: Array[String] = []
	var xp: int = 0
	var shop: StringName = &""
	for e in events:
		match str(e.get("type", "")):
			"roll":
				var stat: String = tr("wm_stat_" + str(e.get("stat", "")))
				lines.append(tr("wm_roll") % [stat, int(e.get("total", 0)), int(e.get("dc", 0)),
					tr("wm_roll_pass") if bool(e.get("passed", false)) else tr("wm_roll_fail")])
			"narrator":
				lines.append(tr(str(e.get("line_key", ""))))
			"xp_gained":
				if xp == 0: xp = int(e.get("amount", 0))
			"shop_requested":
				shop = StringName(str(e.get("shop", "")))
	if lines.is_empty(): lines.append(tr("wm_outcome_none"))
	if xp > 0: lines.append(tr("wm_xp") % xp)
	for t in lines:
		var l: Label = UiKit.label("")
		l.text = t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(320, 0)
		box.add_child(l)
	var ok: Button = UiKit.button("wm_continue")
	ok.pressed.connect(func() -> void:
		_close_modal()
		if shop != &"": ShopScreen.show_over(self, shop))
	box.add_child(ok)
	_open_modal(box)
	ok.grab_focus.call_deferred()

## "Enter <name>?" with Enter / Not yet.
func show_enter_prompt(location_id: StringName) -> void:
	var loc: Dictionary = Rules.location(location_id, defs)
	if loc.is_empty(): return
	var box := VBoxContainer.new()
	var l: Label = UiKit.label("")
	l.text = tr("wm_enter") % tr(str(loc.get("name_key", "")))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes: Button = UiKit.button("wm_enter_yes")
	var no: Button = UiKit.button("wm_enter_no")
	yes.pressed.connect(func() -> void: enter(location_id))
	no.pressed.connect(_close_modal)
	row.add_child(yes)
	row.add_child(no)
	box.add_child(row)
	_open_modal(box)
	enter_location = location_id
	yes.grab_focus.call_deferred()

func enter(location_id: StringName) -> void:
	_close_modal()
	Router.go(&"location", {"location_id": location_id})

## Hook for the abduction cutscene (WP-30 replaces the body with the beam). For now: straight
## to the UFO's battle.
func play_abduction(ufo_id: StringName, encounter: StringName) -> void:
	Audio.stinger(&"abduction")
	_abduction_battle(ufo_id, encounter)

func _abduction_battle(_ufo_id: StringName, encounter: StringName) -> void:
	Router.go(&"combat", {"encounter_id": encounter, "return_mode": &"worldmap", "return_args": {}})

# ---------------------------------------------------------------- helpers

static func _first(events: Array[Dictionary], kind: String) -> Dictionary:
	for e in events:
		if str(e.get("type", "")) == kind: return e
	return {}

static func _has(events: Array[Dictionary], kind: String) -> bool:
	return not _first(events, kind).is_empty()
