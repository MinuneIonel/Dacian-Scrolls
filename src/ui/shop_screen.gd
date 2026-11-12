## Shop overlay for data/shops/<shop_id>. Implemented by WP-24.
class_name ShopScreen
extends Control

signal closed

var shop_id: StringName

static func show_over(parent: Node, id: StringName) -> ShopScreen:
	var s := ShopScreen.new()
	s.shop_id = id
	var layer := CanvasLayer.new()
	layer.layer = 50
	parent.add_child(layer)
	layer.add_child(s)
	s.closed.connect(layer.queue_free)
	return s
