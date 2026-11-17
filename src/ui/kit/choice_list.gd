## A vertical list of buttons built by UiKit.choice_list(). Keyboard: up/down to move,
## accept to choose. Mouse: click. Emits chosen(index).
class_name ChoiceList
extends VBoxContainer

signal chosen(index: int)

var buttons: Array[Button] = []

func set_items(items: Array[String]) -> void:
	for b in buttons: b.queue_free()
	buttons.clear()
	for i in items.size():
		var b: Button = UiKit.button(items[i])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_pressed.bind(i))
		add_child(b)
		buttons.append(b)
	if is_inside_tree(): _link()

func _ready() -> void:
	_link()

## Up from the first choice wraps to the last, and down from the last to the first.
func _link() -> void:
	if buttons.size() < 2: return
	buttons[0].focus_neighbor_top = buttons[0].get_path_to(buttons[-1])
	buttons[-1].focus_neighbor_bottom = buttons[-1].get_path_to(buttons[0])

## Gives keyboard focus to the first enabled choice.
func focus_first() -> void:
	for b in buttons:
		if not b.disabled:
			b.grab_focus()
			return

func _on_pressed(i: int) -> void:
	chosen.emit(i)
