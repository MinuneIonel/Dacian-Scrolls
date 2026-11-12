## Debug scene: draws a map with a knight at its entry. tools/shots.sh res://tools/map_preview.tscn out.png 10 1280x720 --args='{"map":"sarmizegetusa"}'
extends Node2D

func _ready() -> void:
	var map_id := StringName(Router.args.get("map", "arena_forest"))
	var m: Node2D = MapBuilder.build(map_id, Content.defs)
	add_child(m)
	var entry := Vector2i(0, 0)
	for e in Content.get_def(&"map", map_id).get("entities", []):
		if e.get("kind") == "spawn_ally": entry = Vector2i(e.cell[0], e.cell[1])
	var u := UnitSprite.new(&"knight")
	u.place(entry)
	m.get_node("Sorted").add_child(u)
	var cam := Camera2D.new()
	cam.position = Iso.cell_to_world(entry)
	cam.zoom = Vector2(float(Router.args.get("zoom", 1.0)), float(Router.args.get("zoom", 1.0)))
	add_child(cam)
