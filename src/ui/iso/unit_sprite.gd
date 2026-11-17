## An animated unit standing on the iso map. Handles anchors, the SE/NE art + flips, and size-2
## footprints. Animations: idle walk attack hit death (Assets.frames gives placeholders if missing).
class_name UnitSprite
extends Node2D

var sprite_id: StringName
var footprint: int = 1
var facing: String = "se"
var cell: Vector2i
var _anim: AnimatedSprite2D

func _init(id: StringName = &"", size: int = 1) -> void:
	sprite_id = id
	footprint = size
	_anim = AnimatedSprite2D.new()
	_anim.centered = false
	add_child(_anim)
	_anim.sprite_frames = Assets.frames(id)
	var spec: Dictionary = Assets.manifest.frames.get(String(id), {})
	var fs: Array = spec.get("frame_size", [32, 48])
	var anchor: Array = spec.get("anchor", [fs[0] / 2, fs[1] - 4])
	if spec.is_empty():
		# Placeholder frames are 32x32.
		anchor = [16, 30]
	_anim.offset = Vector2(-anchor[0], -anchor[1])
	play(&"idle")

func place(c: Vector2i) -> void:
	cell = c
	position = Iso.footprint_center(c, footprint)

func face(dir: String) -> void:
	facing = dir
	play(_base(_anim.animation))

## Plays name in the current facing; north-facing uses the "_ne" rows when they exist.
func play(anim_name: StringName) -> void:
	var base: String = _base(anim_name)
	var north: bool = facing.begins_with("n")
	var want: String = base + ("_ne" if north else "")
	var sf: SpriteFrames = _anim.sprite_frames
	if not sf.has_animation(want): want = base
	if not sf.has_animation(want): want = "idle" if sf.has_animation("idle") else "default"
	_anim.flip_h = facing.ends_with("w")
	if _anim.animation != StringName(want) or not _anim.is_playing():
		_anim.play(want)

func current_animation() -> StringName:
	return _anim.animation

func animated_sprite() -> AnimatedSprite2D:
	return _anim

## Plays a one-shot animation and waits for it (returns at once if it loops or has 1 frame).
func play_once(anim_name: StringName) -> void:
	play(anim_name)
	var sf: SpriteFrames = _anim.sprite_frames
	if sf.get_animation_loop(_anim.animation) or sf.get_frame_count(_anim.animation) <= 1:
		return
	await _anim.animation_finished

static func _base(a: StringName) -> String:
	return String(a).trim_suffix("_ne")
