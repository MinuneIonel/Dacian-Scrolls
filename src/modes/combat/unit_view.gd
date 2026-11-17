## One unit on the combat map: the animated sprite, a side-coloured ring under its feet, an HP bar
## above its head and short status tags. Holds only what the event player told it.
extends Node2D

const PARTY_COLOR := Color("e0aa5c")
const ENEMY_COLOR := Color("c04040")
const SUMMON_COLOR := Color("8fd06a")
const ACTIVE_COLOR := Color("fff2c0")
const BAR_W: int = 22

var uid: int = 0
var side: String = "party"
var summoned: bool = false
var size: int = 1
var hp: int = 1
var max_hp: int = 1
var cell: Vector2i = Vector2i.ZERO
var name_key: String = ""
var downed: bool = false
var is_corpse: bool = false
var active: bool = false
var hovered: bool = false
var statuses: Dictionary = {}   # status -> turns
var sprite: UnitSprite
var _head: float = 44.0
var _half_w: float = 12.0

func setup(unit_uid: int, sprite_id: StringName, footprint: int, unit_side: String, unit_hp: int, unit_max_hp: int,
		at: Vector2i, tint: Color = Color.WHITE) -> void:
	uid = unit_uid
	size = maxi(1, footprint)
	side = unit_side
	hp = unit_hp
	max_hp = maxi(1, unit_max_hp)
	name = "Unit%d" % uid
	sprite = UnitSprite.new(sprite_id, size)
	sprite.modulate = tint
	add_child(sprite)
	var spec: Dictionary = Assets.manifest.frames.get(String(sprite_id), {})
	var anchor: Array = spec.get("anchor", [16, 30])
	var fs: Array = spec.get("frame_size", [32, 32])
	_head = float(anchor[1])
	_half_w = float(fs[0]) * 0.35
	place(at)

## Feet on the footprint centre of `at`.
func place(at: Vector2i) -> void:
	cell = at
	position = Iso.footprint_center(at, size)

func set_hp(v: int) -> void:
	hp = clampi(v, 0, max_hp)
	queue_redraw()

func set_active(on: bool) -> void:
	active = on
	queue_redraw()

func set_hovered(on: bool) -> void:
	if hovered == on: return
	hovered = on
	queue_redraw()

func add_status(st: String, turns: int) -> void:
	statuses[st] = turns
	queue_redraw()

func remove_status(st: String) -> void:
	statuses.erase(st)
	queue_redraw()

func clear_statuses() -> void:
	statuses.clear()
	queue_redraw()

func hp_ratio() -> float:
	return float(hp) / float(max_hp)

func ring_color() -> Color:
	if summoned: return SUMMON_COLOR
	return PARTY_COLOR if side == "party" else ENEMY_COLOR

## Is a point (in this node's parent space) on the unit's body? Used to pick units by their sprite.
func hit_test(p: Vector2) -> bool:
	if is_corpse or not visible: return false
	var d: Vector2 = p - position
	return absf(d.x) <= _half_w and d.y <= 6.0 * size and d.y >= -_head + 4.0

## Top of the head relative to the feet, for floating text.
func head_offset() -> Vector2:
	return Vector2(0, -_head - 6.0)

func _draw() -> void:
	if is_corpse: return
	# Ring under the feet (drawn before the sprite child).
	var r: float = 11.0 * size + (2.0 if active else 0.0)
	var col: Color = ACTIVE_COLOR if active else ring_color()
	if downed: col = Color(0.4, 0.4, 0.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35), true, -1.0, false)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, col, 2.0 if (active or hovered) else 1.0, false)
	if active:
		draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 24, ring_color(), 1.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if downed: return
	# HP bar above the head.
	var w: int = BAR_W + (10 if size > 1 else 0)
	var top: float = -_head - 4.0
	var x0: float = -w / 2.0
	draw_rect(Rect2(x0 - 1, top - 1, w + 2, 4), Color("120c09"), true)
	var fill: float = floorf(w * hp_ratio())
	var bar_col: Color = Color("6fb04a") if side == "party" and not summoned else (SUMMON_COLOR if summoned else Color("c84030"))
	if fill > 0: draw_rect(Rect2(x0, top, fill, 2), bar_col, true)
	# Status tags under the bar's left end.
	if statuses.is_empty(): return
	var f: Font = UiKit.font()
	var keys: Array = statuses.keys()
	keys.sort()
	var tx: float = x0 - 2.0
	var ty: float = top - 3.0
	for st in keys:
		var tag: String = tr("cbt_sts_" + str(st))
		draw_string(f, Vector2(tx + 1, ty + 1), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE, Color("120c09"))
		draw_string(f, Vector2(tx, ty), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE, _status_color(str(st)))
		tx += f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE).x + 3.0

static func _status_color(st: String) -> Color:
	match st:
		"shield", "regen": return Color("8fd06a")
		"taunted": return Color("e0aa5c")
		"chilled": return Color("9ad0ff")
		"charmed": return Color("ff9ad0")
	return Color("ff7a5a")
