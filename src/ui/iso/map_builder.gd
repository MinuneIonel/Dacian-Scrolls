## Builds a drawable isometric map from a map definition (data/maps/*.json) and data/tiles.json.
## Ground tiles go in one layer; tall tiles (walls, trees, props) are y-sorted with units in
## `sorted`. Tiles without art are drawn as flat coloured diamonds so maps stay readable.
class_name MapBuilder
extends RefCounted

## Returns a Node2D named after the map with children:
##   "Ground" (Node2D, z_index -10): flat tiles
##   "Sorted" (Node2D, y_sort_enabled): tall tiles; add units here too so they sort with walls
## The node has metadata "grid" (Grid), "size" (Vector2i) and "map_id".
static func build(map_id: StringName, defs: Defs) -> Node2D:
	var map_def: Dictionary = defs.get_def(&"map", map_id)
	var tiles: Dictionary = defs.json("tiles")
	var root := Node2D.new()
	root.name = String(map_id) if map_id != &"" else "Map"
	var ground := Node2D.new(); ground.name = "Ground"; ground.z_index = -10
	var sorted := Node2D.new(); sorted.name = "Sorted"; sorted.y_sort_enabled = true
	root.add_child(ground); root.add_child(sorted)
	var rows: Array = map_def.get("ground", [])
	var legend: Dictionary = map_def.get("legend", {})
	var size := Vector2i(0 if rows.is_empty() else String(rows[0]).length(), rows.size())
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var tile_id: String = legend.get(row[x], "")
			var tdef: Dictionary = tiles.get(tile_id, {})
			var c := Vector2i(x, y)
			var node: Node2D = tile_node(tile_id, tdef)
			node.position = Iso.cell_to_world(c)
			if tdef.get("tall", false):
				# Tall tiles need a ground under them too.
				var floor_poly := diamond(_fallback_color(tile_id, tdef).darkened(0.35))
				floor_poly.position = node.position
				ground.add_child(floor_poly)
				sorted.add_child(node)
			else:
				ground.add_child(node)
	root.set_meta("grid", Grid.from_map(map_def, tiles))
	root.set_meta("size", size)
	root.set_meta("map_id", map_id)
	return root

## One tile, positioned so its origin is the diamond centre.
static func tile_node(tile_id: String, tdef: Dictionary) -> Node2D:
	var sprite_id := StringName(tdef.get("sprite", "tile_" + tile_id))
	if Assets.has_tex(sprite_id):
		var s := Sprite2D.new()
		var tex: Texture2D = Assets.tex(sprite_id)
		s.texture = tex
		s.centered = false
		# Ground: 64x32 at (-32,-16). Tall: diamond is the bottom 32 rows.
		s.offset = Vector2(-Iso.TILE_W / 2, -(tex.get_height() - Iso.TILE_H / 2))
		return s
	var col: Color = _fallback_color(tile_id, tdef)
	if tdef.get("tall", false) or not tdef.get("walkable", true):
		return block(col, 24 if tdef.get("tall", false) else 8)
	return diamond(col)

## A flat diamond polygon centred on the origin.
static func diamond(col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)])
	p.color = col
	return p

## A simple extruded block for unwalkable tiles without art.
static func block(col: Color, h: int) -> Node2D:
	var n := Node2D.new()
	var left := Polygon2D.new()
	left.polygon = PackedVector2Array([Vector2(-32, 0), Vector2(0, 16), Vector2(0, 16 - h), Vector2(-32, -h)])
	left.color = col.darkened(0.25)
	var right := Polygon2D.new()
	right.polygon = PackedVector2Array([Vector2(0, 16), Vector2(32, 0), Vector2(32, -h), Vector2(0, 16 - h)])
	right.color = col.darkened(0.45)
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2(0, -16 - h), Vector2(32, -h), Vector2(0, 16 - h), Vector2(-32, -h)])
	top.color = col
	n.add_child(left); n.add_child(right); n.add_child(top)
	return n

static func _fallback_color(tile_id: String, tdef: Dictionary) -> Color:
	var id := tile_id.to_lower()
	var named: Dictionary = {"grass": Color("4f7a3a"), "road": Color("9a7650"), "dirt": Color("8a6a46"),
		"forest": Color("2f5530"), "tree": Color("2a4a2a"), "stone": Color("8c8c86"), "wall": Color("b8b2a0"),
		"water": Color("2e5a7a"), "river": Color("2e5a7a"), "cave": Color("4a4440"), "rock": Color("5e5852"),
		"saucer": Color("3a4a5e"), "metal": Color("6a7a8a"), "glass": Color("6fd3d8"), "wood": Color("7a5232"),
		"sand": Color("c2a46a"), "snow": Color("d8dce0"), "mountain": Color("6e665c"), "floor": Color("7d6e5a")}
	for k in named:
		if id.contains(k): return named[k]
	var h: float = float(hash(tile_id) % 1000) / 1000.0
	return Color.from_hsv(h, 0.25, 0.55 if tdef.get("walkable", true) else 0.35)
