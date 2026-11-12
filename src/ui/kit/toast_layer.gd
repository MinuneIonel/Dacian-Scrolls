## Short messages under the top edge. Listens to Bus.toast(text_key) and to `toast` events
## broadcast through Bus.events_emitted. Each shows for SHOW_S seconds; new ones stack below.
class_name ToastLayer
extends CanvasLayer

const SHOW_S: float = 2.5
const FADE_S: float = 0.3
const MAX_SHOWN: int = 4

var stack: VBoxContainer

func _init() -> void:
	layer = 50
	name = "ToastLayer"
	stack = VBoxContainer.new()
	stack.theme = UiKit.theme()
	stack.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.position.y = 8
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(stack)

func _ready() -> void:
	Bus.toast.connect(show_toast)
	Bus.events_emitted.connect(_on_events)

func _on_events(events: Array[Dictionary]) -> void:
	for e in events:
		if e.get("type", "") == "toast": show_toast(String(e.get("text_key", "")))

## Shows tr(text_key). Returns the toast's panel (tests look at it).
func show_toast(text_key: String) -> PanelContainer:
	while stack.get_child_count() >= MAX_SHOWN:
		var old: Node = stack.get_child(0)
		stack.remove_child(old)
		old.queue_free()
	var p: PanelContainer = UiKit.panel()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l: Label = UiKit.label(text_key)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	stack.add_child(p)
	var tw: Tween = p.create_tween()
	tw.tween_interval(SHOW_S)
	tw.tween_property(p, "modulate:a", 0.0, FADE_S)
	tw.tween_callback(p.queue_free)
	return p

func count() -> int:
	return stack.get_child_count()
