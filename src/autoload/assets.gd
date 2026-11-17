## Textures and sprite frames by id, from assets/manifest.json. Unknown ids return a magenta placeholder and never crash.
extends Node

const MANIFEST: String = "res://assets/manifest.json"

var manifest: Dictionary = {"textures": {}, "frames": {}, "audio": {}}
var _tex_cache: Dictionary = {}
var _frames_cache: Dictionary = {}
var _placeholder: Texture2D
var _warned: Dictionary = {}

func _ready() -> void:
	if FileAccess.file_exists(MANIFEST):
		var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if m is Dictionary:
			for k in ["textures", "frames", "audio"]:
				manifest[k] = m.get(k, {})

func tex(id: StringName) -> Texture2D:
	if _tex_cache.has(id): return _tex_cache[id]
	var path: String = manifest.textures.get(String(id), "")
	var t: Texture2D = load_png(path) if path != "" else null
	if t == null:
		_warn(id)
		t = placeholder()
	_tex_cache[id] = t
	return t

## Sprite sheets: manifest.frames[id] = {sheet, frame_size: [w, h],
##   anims: {name: {row: int, frames: int, fps: float, loop: bool}}}
func frames(id: StringName) -> SpriteFrames:
	if _frames_cache.has(id): return _frames_cache[id]
	var sf := SpriteFrames.new()
	var spec: Dictionary = manifest.frames.get(String(id), {})
	var sheet: Texture2D = load_png(spec.get("sheet", "")) if not spec.is_empty() else null
	if sheet == null:
		_warn(id)
		sf.add_frame(&"default", placeholder())
		for a in ["idle", "walk", "attack", "hit", "death"]:
			sf.add_animation(a); sf.add_frame(a, placeholder())
	else:
		var fs: Array = spec.get("frame_size", [32, 48])
		for anim_name in spec.get("anims", {}):
			var a: Dictionary = spec.anims[anim_name]
			if not sf.has_animation(anim_name): sf.add_animation(anim_name)
			sf.set_animation_speed(anim_name, float(a.get("fps", 6)))
			sf.set_animation_loop(anim_name, bool(a.get("loop", true)))
			for i in int(a.get("frames", 1)):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(i * fs[0], int(a.get("row", 0)) * fs[1], fs[0], fs[1])
				sf.add_frame(anim_name, at)
	_frames_cache[id] = sf
	return sf

func has_tex(id: StringName) -> bool:
	return manifest.textures.has(String(id))

func audio_path(id: StringName) -> String:
	return manifest.audio.get(String(id), "")

## Imported resource when available (export-safe); raw PNG for files generated since the last import.
static func load_png(path: String) -> Texture2D:
	if path == "": return null
	if ResourceLoader.exists(path, "Texture2D"): return load(path)
	if not FileAccess.file_exists(path): return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty(): return null
	return ImageTexture.create_from_image(img)

func placeholder() -> Texture2D:
	if _placeholder == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				img.set_pixel(x, y, Color.MAGENTA if ((x / 8) + (y / 8)) % 2 == 0 else Color.BLACK)
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder

func _warn(id: StringName) -> void:
	if not _warned.has(id):
		_warned[id] = true
		print_verbose("Assets: placeholder for '%s'" % id)
