## Placeholder for the combat mode. Replaced by its owning work package.
extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var l := Label.new()
	l.text = tr("title") + "\n\n[combat mode: not built yet]"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(l)
