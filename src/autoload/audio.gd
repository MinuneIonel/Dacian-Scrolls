## Music (layered stems played in sync) and sound effects. Missing files are silent.
## Implemented by WP-15; this stub keeps the API callable.
extends Node

func play_music(track: StringName) -> void:
	pass

## Layers: "explore", "combat", "lobizi".
func set_layer(layer: StringName, on: bool, fade_s: float = 1.0) -> void:
	pass

func sfx(id: StringName) -> void:
	pass

func stinger(id: StringName) -> void:
	pass

func stop_music(fade_s: float = 1.0) -> void:
	pass
