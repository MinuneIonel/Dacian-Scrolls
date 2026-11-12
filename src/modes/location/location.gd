## Location mode: walk a town, dungeon or outskirts map, talk to NPCs, open containers, step on
## triggers and exits. Reads Router.args {location_id, cell?}; location_id is a world location id
## (its map and entry_cell come from world.json) or directly a map id.
## Debug args (screenshots): debug_party (start a new game with a knight and Vezina),
## debug_talk (npc entity id: open its dialogue at once), debug_pause (open the pause menu).
## The view never decides outcomes: containers, triggers and dialogue run Rules / DialogueRunner
## and it acts on the returned events.
extends Node2D

const STEP_TIME: float = 0.16
const DEFAULT_MUSIC: StringName = &"sarmizegetusa"
const KEY_DIRS: Dictionary = {
	KEY_W: Vector2i(0, -1), KEY_UP: Vector2i(0, -1),
	KEY_D: Vector2i(1, 0), KEY_RIGHT: Vector2i(1, 0),
	KEY_S: Vector2i(0, 1), KEY_DOWN: Vector2i(0, 1),
	KEY_A: Vector2i(-1, 0), KEY_LEFT: Vector2i(-1, 0)}
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const HILITE := Color(1.35, 1.3, 1.1)

var location_id: StringName = &""
var map_id: StringName = &""
var map_def: Dictionary = {}
var map_node: Node2D
var grid: Grid
var leader: UnitSprite
var followers: Array[UnitSprite] = []
var camera: Camera2D
## Entities shown on the map: {def: Dictionary, node: Node2D (or null)}, by entity id.
var entities: Dictionary = {}
var dialogue: DialogueBox
var step_time: float = STEP_TIME

var hud: CanvasLayer
var name_label: Label
var hover_label: Label
var btn_party: Button
var btn_scroll: Button
var pause_menu: Control
var btn_resume: Button
var btn_quit: Button

var _path: Array[Vector2i] = []
var _moving: bool = false
var _move_t: float = 0.0
var _from: Vector2i
var _to: Vector2i
var _trail: Array[Vector2i] = []
var _trail_from: Array[Vector2i] = []
var _pending_interact: String = ""
var _pending_battle: StringName = &""
var _leaving: bool = false
var _overlay: Control
var _cursor: Line2D
var _hovered: String = ""
var _dialogue_layer: CanvasLayer

func _ready() -> void:
	var a: Dictionary = Router.args
	if a.get("debug_party", false):
		Game.new_game(1, &"knight")
		Game.broadcast(Rules.run([["recruit", "vezina"]], Game.state, Game.rng, Content.defs))
	location_id = StringName(str(a.get("location_id", Game.state.location_id)))
	var entry: Variant = null
	var loc: Dictionary = Rules.location(location_id, Content.defs)
	if not loc.is_empty():
		map_id = StringName(str(loc.get("map", location_id)))
		if loc.has("entry_cell"): entry = Rules.to_cell(loc.entry_cell)
	else:
		map_id = location_id
	if not Content.has(&"map", map_id):
		push_error("Location: unknown location or map '%s'" % location_id)
		return
	map_def = Content.get_def(&"map", map_id)
	_build_background()
	map_node = MapBuilder.build(map_id, Content.defs)
	add_child(map_node)
	grid = map_node.get_meta("grid")
	if map_def.get("kind", "") == "dungeon":
		var cm := CanvasModulate.new()
		cm.color = Color(0.78, 0.74, 0.84)
		add_child(cm)
	_build_cursor()
	_build_entities()
	var start: Vector2i
	if a.has("cell") and a.cell != null: start = Rules.to_cell(a.cell)
	elif entry != null: start = entry
	else: start = _spawn_cell()
	_build_party(start)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.position = leader.position
	camera.reset_smoothing()
	Game.state.location_id = location_id
	Game.state.location_cell = start
	_build_hud()
	Audio.play_music(StringName(str(map_def.get("music", DEFAULT_MUSIC))))
	Audio.set_layer(&"explore", true)
	Audio.set_layer(&"combat", false)
	Audio.set_layer(&"lobizi", false)
	if a.get("debug_pause", false): open_pause()
	if a.has("debug_talk"):
		var id: String = str(a.debug_talk)
		if entities.has(id):
			talk(id)
			if dialogue != null: dialogue.reveal_all()

# ---------------------------------------------------------------- building

func _build_background() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	var r := ColorRect.new()
	r.color = UiKit.INK
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(r)
	add_child(bg)

func _build_cursor() -> void:
	_cursor = Line2D.new()
	_cursor.points = PackedVector2Array([Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0), Vector2(0, -16)])
	_cursor.width = 1.0
	_cursor.default_color = Color(UiKit.PARCHMENT, 0.55)
	_cursor.z_index = -5
	_cursor.visible = false
	map_node.add_child(_cursor)

func _spawn_cell() -> Vector2i:
	for e: Dictionary in map_def.get("entities", []):
		if e.get("kind", "") == "spawn_ally": return Rules.to_cell(e.get("cell", []))
	return Vector2i.ZERO

func _build_entities() -> void:
	var sorted: Node2D = map_node.get_node("Sorted")
	for e: Dictionary in map_def.get("entities", []):
		var kind: String = str(e.get("kind", ""))
		var id: String = str(e.get("id", ""))
		var c: Vector2i = Rules.to_cell(e.get("cell", []))
		var node: Node2D = null
		match kind:
			"npc":
				if not Rules.check(e.get("if", []), Game.state, Content.defs): continue
				var npc: Dictionary = _npc_def(e)
				var u := UnitSprite.new(StringName(str(e.get("sprite", npc.get("sprite", "")))))
				u.place(c)
				u.face("sw")
				node = u
			"container", "prop":
				node = _prop_node(StringName(str(e.get("sprite", ""))))
				node.position = Iso.cell_to_world(c)
				if kind == "container" and _opened(id): node.modulate = Color(0.55, 0.55, 0.55)
			"exit":
				var mark := Line2D.new()
				mark.points = PackedVector2Array([Vector2(0, -10), Vector2(20, 0), Vector2(0, 10), Vector2(-20, 0), Vector2(0, -10)])
				mark.width = 1.0
				mark.default_color = Color(UiKit.BRONZE_LIGHT, 0.7)
				mark.position = Iso.cell_to_world(c)
				mark.z_index = -6
				map_node.add_child(mark)
			"trigger":
				pass
			_:
				continue
		if node != null: sorted.add_child(node)
		entities[id] = {"def": e, "node": node, "cell": c, "kind": kind}

func _prop_node(sprite: StringName) -> Node2D:
	if sprite != &"" and Assets.has_tex(sprite):
		var s := Sprite2D.new()
		s.texture = Assets.tex(sprite)
		s.centered = false
		s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height() + 4)
		return s
	# No art yet: a small chest-like block.
	var holder := Node2D.new()
	var b: Node2D = MapBuilder.block(UiKit.WOOD_LIGHT, 14)
	b.scale = Vector2(0.4, 0.4)
	holder.add_child(b)
	var lid: Node2D = MapBuilder.block(UiKit.BRONZE, 4)
	lid.scale = Vector2(0.4, 0.4)
	lid.position = Vector2(0, -5)
	holder.add_child(lid)
	return holder

func _npc_def(e: Dictionary) -> Dictionary:
	var nid := StringName(str(e.get("npc", "")))
	if nid != &"" and Content.has(&"npc", nid): return Content.get_def(&"npc", nid)
	return {}

func _member_sprite(m: Character) -> StringName:
	if m.id != &"hero" and Content.has(&"npc", m.id):
		var s: String = str(Content.get_def(&"npc", m.id).get("sprite", ""))
		if s != "": return StringName(s)
	if Content.has(&"class", m.class_id):
		return StringName(str(Content.get_def(&"class", m.class_id).get("sprite", m.class_id)))
	return &"knight"

func _build_party(start: Vector2i) -> void:
	var sorted: Node2D = map_node.get_node("Sorted")
	var party: Array[Character] = Game.state.party
	leader = UnitSprite.new(_member_sprite(party[0]) if not party.is_empty() else &"knight")
	leader.place(start)
	sorted.add_child(leader)
	var used: Dictionary = {start: true}
	var prev: Vector2i = start
	for i in range(1, party.size()):
		var c: Vector2i = _free_neighbour(prev, used)
		used[c] = true
		_trail.append(c)
		var u := UnitSprite.new(_member_sprite(party[i]))
		u.place(c)
		sorted.add_child(u)
		followers.append(u)
		prev = c

func _free_neighbour(c: Vector2i, used: Dictionary) -> Vector2i:
	var blocked: Dictionary = blocked_cells()
	for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if grid.is_walkable(n) and not used.has(n) and not blocked.has(n): return n
	return c

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var root := Control.new()
	root.theme = UiKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 6; top.offset_right = -6; top.offset_top = 6
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var name_panel: PanelContainer = UiKit.panel()
	name_panel.add_theme_stylebox_override("panel", _small_box())
	name_label = UiKit.label(str(map_def.get("name_key", "")))
	name_label.add_theme_color_override("font_color", UiKit.BRONZE_LIGHT)
	name_panel.add_child(name_label)
	top.add_child(name_panel)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	btn_party = UiKit.button("loc_party")
	btn_party.pressed.connect(open_party)
	btn_party.focus_mode = Control.FOCUS_NONE
	top.add_child(btn_party)
	btn_scroll = UiKit.button("loc_scroll")
	btn_scroll.pressed.connect(open_scroll)
	btn_scroll.focus_mode = Control.FOCUS_NONE
	top.add_child(btn_scroll)
	var hint: Label = UiKit.label("loc_hint")
	hint.theme_type_variation = &"DimLabel"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 6; hint.offset_top = -16; hint.offset_bottom = -4
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(hint)
	hover_label = UiKit.label("")
	hover_label.visible = false
	hover_label.add_theme_color_override("font_color", UiKit.BRONZE_LIGHT)
	root.add_child(hover_label)
	_build_pause(root)

func _small_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UiKit.UMBER_DARK, 0.9)
	s.border_color = UiKit.BRONZE
	s.set_border_width_all(1)
	s.content_margin_left = 6; s.content_margin_right = 6
	s.content_margin_top = 2; s.content_margin_bottom = 2
	return s

func _build_pause(root: Control) -> void:
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.visible = false
	root.add_child(pause_menu)
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)
	var p: PanelContainer = UiKit.panel()
	center.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	var title: Label = UiKit.label("loc_paused")
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	btn_resume = UiKit.button("loc_resume")
	btn_resume.pressed.connect(close_pause)
	col.add_child(btn_resume)
	var b_scroll: Button = UiKit.button("loc_scroll")
	b_scroll.pressed.connect(open_scroll)
	col.add_child(b_scroll)
	btn_quit = UiKit.button("loc_quit_menu")
	btn_quit.pressed.connect(func() -> void: Router.go(&"menu"))
	col.add_child(btn_quit)
	var hint: Label = UiKit.label("loc_save_hint")
	hint.theme_type_variation = &"DimLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(170, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

# ---------------------------------------------------------------- queries

## Cells the party cannot walk through: visible NPCs and containers.
func blocked_cells() -> Dictionary:
	var out: Dictionary = {}
	for id: String in entities:
		var k: String = entities[id].kind
		if k == "npc" or k == "container": out[entities[id].cell] = true
	return out

func leader_cell() -> Vector2i:
	return leader.cell if leader != null else Vector2i.ZERO

func is_busy() -> bool:
	return _leaving or (dialogue != null and is_instance_valid(dialogue)) or pause_menu.visible \
		or (_overlay != null and is_instance_valid(_overlay))

func is_walking() -> bool:
	return _moving or not _path.is_empty()

## The interactable entity (npc or container) on a cell, or "".
func interactable_at(c: Vector2i) -> String:
	for id: String in entities:
		var en: Dictionary = entities[id]
		if (en.kind == "npc" or en.kind == "container") and en.cell == c: return id
	return ""

func _entity_at(c: Vector2i, kind: String) -> String:
	for id: String in entities:
		if entities[id].kind == kind and entities[id].cell == c: return id
	return ""

func _opened(id: String) -> bool:
	return bool(Game.state.flags.get("opened_%s_%s" % [map_id, id], false))

func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) == 1

# ---------------------------------------------------------------- walking

## Walks to a cell (or, for an npc/container cell, next to it and then interacts).
## Returns false when there is no path.
func walk_to(target: Vector2i) -> bool:
	if _leaving: return false
	var from: Vector2i = _to if _moving else leader.cell
	var blocked: Dictionary = blocked_cells()
	var ent: String = interactable_at(target)
	if ent != "":
		if not _moving and _adjacent(leader.cell, target):
			_path.clear()
			interact(ent)
			return true
		var res: Dictionary = grid.search(from, -1, 1, blocked)
		var best: Vector2i = from
		var best_cost: int = -1
		for d: Vector2i in NEIGHBOURS:
			var n: Vector2i = target + d
			if not res.cost.has(n): continue
			if best_cost < 0 or int(res.cost[n]) < best_cost:
				best_cost = int(res.cost[n]); best = n
		if best_cost < 0: return false
		_path = Grid.path_from(res.parent, from, best)
		_pending_interact = ent
		if _path.is_empty() and not _moving: _do_pending()
		return true
	var p: Array[Vector2i] = Pathfinder.path(grid, from, target, 1, blocked)
	if p.is_empty(): return false
	_path = p
	_pending_interact = ""
	return true

## Completes every queued step at once (tests, skipping).
func finish_walk() -> void:
	while is_walking() and not _leaving and not is_busy():
		if not _moving: _begin_step()
		if _moving: _end_step()

func _begin_step() -> void:
	if _path.is_empty(): return
	var nxt: Vector2i = _path.pop_front()
	if not grid.is_walkable(nxt) or blocked_cells().has(nxt):
		_path.clear()
		return
	_from = leader.cell
	_to = nxt
	_moving = true
	_move_t = 0.0
	leader.face(Iso.facing(_from, _to))
	leader.play(&"walk")
	_trail_from = _trail.duplicate()
	if not _trail.is_empty():
		_trail.push_front(_from)
		_trail.pop_back()
	for i in followers.size():
		if _trail[i] != _trail_from[i]:
			followers[i].face(Iso.facing(_trail_from[i], _trail[i]))
			followers[i].play(&"walk")

func _end_step() -> void:
	_moving = false
	leader.place(_to)
	for i in followers.size(): followers[i].place(_trail[i])
	_arrive(_to)
	if _path.is_empty() or is_busy():
		leader.play(&"idle")
		for f in followers: f.play(&"idle")
	if _path.is_empty() and _pending_interact != "" and not is_busy(): _do_pending()

func _do_pending() -> void:
	var id: String = _pending_interact
	_pending_interact = ""
	if entities.has(id) and _adjacent(leader.cell, entities[id].cell): interact(id)

func _arrive(c: Vector2i) -> void:
	Game.state.location_cell = c
	var ex: String = _entity_at(c, "exit")
	if ex != "":
		_path.clear()
		_leave(entities[ex].def)
		return
	var tr_id: String = _entity_at(c, "trigger")
	if tr_id != "": _fire_trigger(tr_id)

func _process(delta: float) -> void:
	if leader == null: return
	if _moving:
		_move_t += delta / maxf(step_time, 0.001)
		var t: float = minf(_move_t, 1.0)
		leader.position = Iso.cell_to_world(_from).lerp(Iso.cell_to_world(_to), t)
		for i in followers.size():
			followers[i].position = Iso.cell_to_world(_trail_from[i]).lerp(Iso.cell_to_world(_trail[i]), t)
		if _move_t >= 1.0: _end_step()
	if not _moving and not _path.is_empty() and not is_busy(): _begin_step()
	if not _moving and _path.is_empty() and not is_busy(): _poll_keys()
	camera.position = leader.position + Vector2(0, -16)
	_update_hover()

func _poll_keys() -> void:
	if get_viewport().gui_get_focus_owner() != null: return
	for k: int in KEY_DIRS:
		if Input.is_key_pressed(k as Key):
			step(KEY_DIRS[k])
			return

## One step in a grid direction (keyboard). Bumping an npc or container faces it.
func step(dir: Vector2i) -> void:
	var n: Vector2i = leader.cell + dir
	if interactable_at(n) != "" or not grid.is_walkable(n):
		leader.face(Iso.facing(leader.cell, n))
		return
	_path = [n]
	_pending_interact = ""

# ---------------------------------------------------------------- interaction

func interact(id: String) -> void:
	if not entities.has(id) or is_busy(): return
	var en: Dictionary = entities[id]
	leader.face(Iso.facing(leader.cell, en.cell))
	leader.play(&"idle")
	if en.kind == "npc": talk(id)
	elif en.kind == "container": open_container(id)

## Interacts with the adjacent npc or container in front of the leader, else any adjacent one.
func interact_adjacent() -> bool:
	var best: String = ""
	for id: String in entities:
		var en: Dictionary = entities[id]
		if (en.kind == "npc" or en.kind == "container") and _adjacent(leader.cell, en.cell):
			if best == "" or Iso.facing(leader.cell, en.cell) == leader.facing: best = id
	if best == "": return false
	interact(best)
	return true

func open_container(id: String) -> void:
	var e: Dictionary = entities[id].def
	var once: bool = bool(e.get("once", true))
	if once and _opened(id):
		Bus.toast.emit("loc_searched")
		return
	if not Rules.check(e.get("if", []), Game.state, Content.defs):
		Bus.toast.emit("loc_locked")
		return
	var effects: Array = []
	if once: effects.append(["set_flag", "opened_%s_%s" % [map_id, id], true])
	effects.append_array(e.get("effects", []))
	var evts: Array[Dictionary] = Rules.run(effects, Game.state, Game.rng, Content.defs)
	if once and entities[id].node != null: entities[id].node.modulate = Color(0.55, 0.55, 0.55)
	Audio.sfx(&"open")
	_handle(evts, true)

func _fire_trigger(id: String) -> void:
	var e: Dictionary = entities[id].def
	var once: bool = bool(e.get("once", false))
	var flag: String = "triggered_%s_%s" % [map_id, id]
	if once and bool(Game.state.flags.get(flag, false)): return
	if not Rules.check(e.get("if", []), Game.state, Content.defs): return
	var effects: Array = []
	if once: effects.append(["set_flag", flag, true])
	effects.append_array(e.get("effects", []))
	_handle(Rules.run(effects, Game.state, Game.rng, Content.defs), true)

## Opens the dialogue of an npc entity.
func talk(id: String) -> void:
	if not entities.has(id) or (dialogue != null and is_instance_valid(dialogue)): return
	var e: Dictionary = entities[id].def
	var npc: Dictionary = _npc_def(e)
	var dlg := StringName(str(e.get("dialogue", npc.get("dialogue", ""))))
	if dlg == &"" or not Content.has(&"dialogue", dlg): return
	_path.clear()
	_pending_interact = ""
	if entities[id].node is UnitSprite:
		(entities[id].node as UnitSprite).face(Iso.facing(entities[id].cell, leader.cell))
	_dialogue_layer = CanvasLayer.new()
	_dialogue_layer.layer = 40
	add_child(_dialogue_layer)
	dialogue = DialogueBox.new()
	dialogue.events.connect(_handle.bind(false))
	dialogue.closed.connect(_on_dialogue_closed)
	_dialogue_layer.add_child(dialogue)
	dialogue.begin(dlg, Game.state, Game.rng, Content.defs, StringName(str(npc.get("portrait", ""))))

func _on_dialogue_closed() -> void:
	dialogue = null
	if _dialogue_layer != null: _dialogue_layer.queue_free()
	_dialogue_layer = null
	_refresh_npcs()
	if _pending_battle != &"": _start_battle(_pending_battle)

## Acts on a core event list. `broadcast` is false for lists the dialogue box already sent.
func _handle(evts: Array[Dictionary], broadcast: bool) -> void:
	if broadcast: Bus.emit_events(evts)
	for ev: Dictionary in evts:
		match str(ev.get("type", "")):
			"battle_requested":
				_pending_battle = StringName(str(ev.get("encounter", "")))
			"shop_requested":
				_overlay = ShopScreen.show_over(self, StringName(str(ev.get("shop", ""))))
	if _pending_battle != &"" and (dialogue == null or not is_instance_valid(dialogue) or dialogue.is_closed()):
		_start_battle(_pending_battle)

## NPCs whose "if" stopped holding leave; ones that now pass appear.
func _refresh_npcs() -> void:
	var sorted: Node2D = map_node.get_node("Sorted")
	for e: Dictionary in map_def.get("entities", []):
		if e.get("kind", "") != "npc": continue
		var id: String = str(e.get("id", ""))
		var ok: bool = Rules.check(e.get("if", []), Game.state, Content.defs)
		if ok and not entities.has(id):
			var u := UnitSprite.new(StringName(str(e.get("sprite", _npc_def(e).get("sprite", "")))))
			var c: Vector2i = Rules.to_cell(e.get("cell", []))
			u.place(c)
			sorted.add_child(u)
			entities[id] = {"def": e, "node": u, "cell": c, "kind": "npc"}
		elif not ok and entities.has(id):
			if entities[id].node != null: entities[id].node.queue_free()
			entities.erase(id)

func _start_battle(enc: StringName) -> void:
	_pending_battle = &""
	_path.clear()
	_leaving = true
	Router.go(&"combat", {"encounter_id": enc, "return_mode": &"location",
		"return_args": {"location_id": location_id, "cell": leader.cell}})

func _leave(e: Dictionary) -> void:
	var to: Dictionary = e.get("to", {})
	_leaving = true
	if str(to.get("mode", "worldmap")) == "location":
		var args: Dictionary = {"location_id": StringName(str(to.get("location", "")))}
		if to.has("cell"): args["cell"] = Rules.to_cell(to.cell)
		Router.go(&"location", args)
	else:
		Router.go(&"worldmap")

func open_party() -> void:
	if is_busy(): return
	_overlay = PartyScreen.show_over(self)

func open_scroll() -> void:
	_leaving = true
	Router.go(&"scroll")

func open_pause() -> void:
	pause_menu.visible = true
	_path.clear()
	btn_resume.grab_focus()

func close_pause() -> void:
	pause_menu.visible = false
	var f: Control = get_viewport().gui_get_focus_owner()
	if f != null: f.release_focus()

# ---------------------------------------------------------------- input

func _mouse_cell() -> Vector2i:
	return Iso.world_to_cell(map_node.get_local_mouse_position())

func _update_hover() -> void:
	if map_node == null or hud == null: return
	var c: Vector2i = _mouse_cell()
	var id: String = "" if is_busy() else interactable_at(c)
	if id == "" and not is_busy(): id = _entity_at(c, "exit")
	if id != _hovered:
		if _hovered != "" and entities.has(_hovered) and entities[_hovered].node != null:
			var n: Node2D = entities[_hovered].node
			n.modulate = Color(0.55, 0.55, 0.55) if entities[_hovered].kind == "container" and _opened(_hovered) else Color.WHITE
		_hovered = id
		if id != "" and entities[id].node != null: entities[id].node.modulate = HILITE
	_cursor.visible = not is_busy() and grid.in_bounds(c) and (grid.is_walkable(c) or id != "")
	_cursor.position = Iso.cell_to_world(c)
	_cursor.default_color = Color(UiKit.BRONZE_LIGHT, 0.9) if id != "" else Color(UiKit.PARCHMENT, 0.45)
	hover_label.visible = id != ""
	if id != "":
		hover_label.text = _hover_text(id)
		hover_label.position = get_viewport().get_mouse_position() + Vector2(10, -14)

func _hover_text(id: String) -> String:
	var en: Dictionary = entities[id]
	match en.kind:
		"npc":
			return TranslationServer.translate(str(_npc_def(en.def).get("name_key", "")))
		"container":
			return TranslationServer.translate("loc_searched" if _opened(id) else "loc_search")
		"exit":
			return TranslationServer.translate("loc_exit")
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if leader == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			if _overlay != null and is_instance_valid(_overlay):
				_overlay.closed.emit()
				_overlay = null
			elif pause_menu.visible: close_pause()
			elif not is_busy(): open_pause()
			get_viewport().set_input_as_handled()
		elif k == KEY_E and not is_busy() and not is_walking():
			interact_adjacent()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_busy(): return
		walk_to(_mouse_cell())
		get_viewport().set_input_as_handled()
