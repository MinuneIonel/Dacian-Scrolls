## Party overlay: stats, gear, equipping up to 4 abilities, using items. Implemented by WP-24.
class_name PartyScreen
extends Control

signal closed

## Adds the screen on top of `parent` (in its own CanvasLayer) and returns it.
static func show_over(parent: Node) -> PartyScreen:
	var s := PartyScreen.new()
	var layer := CanvasLayer.new()
	layer.layer = 50
	parent.add_child(layer)
	layer.add_child(s)
	s.closed.connect(layer.queue_free)
	return s
