extends Node

func _ready() -> void:
	Router.go.call_deferred(&"menu")
