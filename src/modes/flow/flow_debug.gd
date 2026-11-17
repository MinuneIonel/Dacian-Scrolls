## Debug scene for screenshots of the WP-30 overlays. Not used by the game.
## tools/shots.sh res://src/modes/flow/flow_debug.tscn out.png 60 640x360 --args='{"show":"seance","line":2}'
## show: seance (line: index, revealed) | beam (t: start time in s) | wake (kind: forest|crash|temple, t)
extends Node

func _ready() -> void:
	var a: Dictionary = Router.args.duplicate()
	Router.switch_scenes = false
	Router.autosave_enabled = false
	var show: String = str(a.get("show", "seance"))
	match show:
		"seance":
			var s: Node = Flow.start_new_game(1, &"knight")
			_add_mode("location", {"location_id": "sarmizegetusa"})
			for i in int(a.get("line", 0)): s.next_line()
			s.reveal()
		"beam":
			Game.new_game(1, &"knight")
			Game.state.world_pos = Vector2i(30, 16)
			Game.state.ufos[0]["pos"] = Vector2i(30, 16)
			Game.state.ufos[0]["state"] = "chase"
			Fog.reveal(Game.state, Vector2i(30, 16), 4, Travel.world_size(Content.defs))
			var wm: Node = _add_mode("worldmap", {})
			await get_tree().process_frame
			wm.play_abduction(&"ufo_sarmizegetusa", &"saucer_surgeon")
			var b: Node = Hud.get_node_or_null("Beam")
			if b != null: b.t = float(a.get("t", 0.0))
		"wake":
			var kind: String = str(a.get("kind", "temple"))
			Game.new_game(1, &"knight")
			if kind == "temple":
				_add_mode("location", {"location_id": "sarmizegetusa", "cell": [8, 8]})
			else:
				Fog.reveal(Game.state, Game.state.world_pos, 6, Travel.world_size(Content.defs))
				if kind == "forest":
					Game.state.world_pos = Flow.forest_cell(Game.state, Rng.new(4), Content.defs)
				else:
					Game.state.world_pos = Vector2i(35, 16)
					Rules.run([["discover", "crash_site"]], Game.state, Game.rng, Content.defs)
				_add_mode("worldmap", {})
			var line: String = Flow.DEFEAT_LINES[0] if kind == "temple" else Flow.FOREST_LINES[0]
			var w: Node = Flow.show_wake({"wake": kind, "wake_events": [{"type": "narrator", "line_key": line}]})
			w.t = float(a.get("t", 0.0))

func _add_mode(mode: String, args: Dictionary) -> Node:
	Router.args = args
	var n: Node = load(Router.scene_path(StringName(mode))).instantiate()
	add_child(n)
	return n
