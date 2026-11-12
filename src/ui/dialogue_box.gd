## Dialogue overlay: speaker name, optional portrait, typewriter text and a numbered choice list.
## Drives a DialogueRunner. Every event list it produces goes to Bus.emit_events and to the
## `events` signal, so the owning view can act on requests (battle_requested, shop_requested).
## Input: click or space finishes the text; number keys or the list pick a choice; Esc closes.
class_name DialogueBox
extends Control

signal events(evts: Array[Dictionary])
signal closed

const CHARS_PER_SEC: float = 60.0
const PORTRAIT_SIZE: int = 48

var runner: DialogueRunner
var portrait_id: StringName = &""
var speaker_label: Label
var text_label: Label
var portrait: TextureRect
var choices: ChoiceList
var hint_label: Label
## The choices on screen: [{index, text_key}] from DialogueRunner.current().
var shown: Array[Dictionary] = []
var _reveal: float = 0.0
var _closed: bool = false

func _init() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel: PanelContainer = UiKit.panel()
	panel.anchor_left = 0.0; panel.anchor_right = 1.0
	panel.anchor_top = 1.0; panel.anchor_bottom = 1.0
	panel.offset_left = 8; panel.offset_right = -8
	panel.offset_top = -132; panel.offset_bottom = -6
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.visible = false
	row.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	speaker_label = UiKit.label("")
	speaker_label.add_theme_color_override("font_color", UiKit.BRONZE_LIGHT)
	col.add_child(speaker_label)
	text_label = UiKit.label("")
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(200, 0)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(text_label)
	var empty: Array[String] = []
	choices = UiKit.choice_list(empty)
	choices.chosen.connect(_on_chosen)
	col.add_child(choices)
	hint_label = UiKit.label("loc_dlg_hint")
	hint_label.theme_type_variation = &"DimLabel"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(hint_label)

## Starts dialogue_id on the given state. `portrait` is the npc def's portrait id (optional;
## derived from the speaker key when empty). Returns the events of the first node.
func begin(dialogue_id: StringName, state: GameState, rng: Rng, defs: Defs, portrait: StringName = &"") -> Array[Dictionary]:
	portrait_id = portrait
	runner = DialogueRunner.new(dialogue_id, state, rng, defs)
	var evts: Array[Dictionary] = runner.start()
	_broadcast(evts)
	_show_node()
	return evts

## Picks a visible choice by its runner index. Returns its events.
func choose(index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _closed or runner == null: return out
	out = runner.choose(index)
	_broadcast(out)
	_show_node()
	return out

## Picks the n-th choice on screen (1-based, as the number keys do). Closes when there is none
## and the node has no choices (the Continue line).
func choose_number(n: int) -> void:
	if not is_revealed(): return
	if shown.is_empty():
		if n == 1: close()
		return
	if n >= 1 and n <= shown.size(): choose(int(shown[n - 1].index))

func is_revealed() -> bool:
	return text_label.visible_characters < 0 or text_label.visible_characters >= text_label.text.length()

func reveal_all() -> void:
	text_label.visible_characters = -1
	choices.visible = true
	choices.focus_first()

func close() -> void:
	if _closed: return
	_closed = true
	closed.emit()
	queue_free()

func is_closed() -> bool:
	return _closed

func _broadcast(evts: Array[Dictionary]) -> void:
	if evts.is_empty(): return
	Bus.emit_events(evts)
	events.emit(evts)

func _show_node() -> void:
	if _closed: return
	if runner.is_done():
		close()
		return
	var cur: Dictionary = runner.current()
	var speaker: String = str(cur.get("speaker", ""))
	speaker_label.text = TranslationServer.translate(speaker) if speaker != "" else ""
	var pid: StringName = portrait_id
	if pid == &"" and speaker.begins_with("npc_"): pid = StringName("portrait_" + speaker.trim_prefix("npc_"))
	portrait.visible = pid != &"" and Assets.has_tex(pid)
	if portrait.visible: portrait.texture = Assets.tex(pid)
	text_label.text = TranslationServer.translate(str(cur.get("text_key", "")))
	text_label.visible_characters = 0
	_reveal = 0.0
	shown.clear()
	var keys: Array[String] = []
	for c: Dictionary in cur.get("choices", []):
		shown.append(c)
		keys.append(str(c.get("text_key", "")))
	if keys.is_empty(): keys.append("loc_dlg_continue")
	choices.set_items(keys)
	for i in choices.buttons.size():
		choices.buttons[i].text = "%d. %s" % [i + 1, choices.buttons[i].text]
	choices.visible = false

func _process(delta: float) -> void:
	if _closed or is_revealed():
		if not _closed and not choices.visible: reveal_all()
		return
	_reveal += delta * CHARS_PER_SEC
	text_label.visible_characters = mini(int(_reveal), text_label.text.length())

func _on_chosen(i: int) -> void:
	choose_number(i + 1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_revealed():
			reveal_all()
			accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey) or not event.pressed or event.echo: return
	var k: Key = (event as InputEventKey).keycode
	if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
		if not is_revealed():
			reveal_all()
			get_viewport().set_input_as_handled()
	elif k >= KEY_1 and k <= KEY_9:
		choose_number(int(k - KEY_1) + 1)
		get_viewport().set_input_as_handled()
	elif k == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
