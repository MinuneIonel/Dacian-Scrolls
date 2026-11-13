## Instances a scene, waits some frames, saves a screenshot, quits. Driven by tools/shots.sh.
## Extra args: --args=<json> is passed to Router.args before the scene loads.
extends Node

func _ready() -> void:
	var scene: String = ""; var out: String = "user://shot.png"; var frames: int = 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="): scene = a.trim_prefix("--scene=")
		elif a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--frames="): frames = int(a.trim_prefix("--frames="))
		elif a.begins_with("--args="): Router.args = JSON.parse_string(a.trim_prefix("--args="))
	var packed: PackedScene = load(scene)
	if packed == null:
		push_error("shot_runner: cannot load " + scene)
		get_tree().quit(1); return
	add_child(packed.instantiate())
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	print("shot saved: ", out, " ", img.get_size(), " err=", err)
	get_tree().quit(0 if err == OK else 1)
