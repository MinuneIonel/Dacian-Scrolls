## Plays one animation of a manifest `frames` entry (the `"kind": "fx"` ones: fx_balloon_burst,
## fx_heal_sparkle, fx_tech_zap, fx_magic_glyph, fx_tractor_beam) at a point, then frees itself.
## Looping anims last `hold` seconds and fade out.
extends AnimatedSprite2D

static func spawn(parent: Node, id: StringName, anim: StringName, pos: Vector2, speed: float = 1.0,
		hold: float = 0.6) -> AnimatedSprite2D:
	var s: AnimatedSprite2D = (load("res://src/ui/fx/one_shot.gd") as GDScript).new()
	s.sprite_frames = Assets.frames(id)
	s.centered = false
	var spec: Dictionary = Assets.manifest.frames.get(String(id), {})
	var fs: Array = spec.get("frame_size", [32, 32])
	var anchor: Array = spec.get("anchor", [int(fs[0]) / 2, int(fs[1]) / 2])
	s.offset = Vector2(-float(anchor[0]), -float(anchor[1]))
	s.position = pos
	s.speed_scale = speed
	s.add_to_group(&"fx_anim")
	s.add_to_group(StringName("fx_" + String(id).trim_prefix("fx_")))
	parent.add_child(s)
	var want: StringName = anim if s.sprite_frames.has_animation(anim) else &"default"
	s.play(want)
	var sf: SpriteFrames = s.sprite_frames
	var tw: Tween = s.create_tween()
	if sf.get_animation_loop(want) or sf.get_frame_count(want) <= 1:
		tw.tween_interval(hold / maxf(0.1, speed))
	else:
		var n: float = float(sf.get_frame_count(want)) / maxf(1.0, sf.get_animation_speed(want))
		tw.tween_interval(n / maxf(0.1, speed))
	tw.tween_property(s, "modulate:a", 0.0, 0.15 / maxf(0.1, speed))
	tw.tween_callback(s.queue_free)
	return s
