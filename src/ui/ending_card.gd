## Recap card shown when the 12th scroll page is found. Built from Game.state: quest endings
## chosen, companions, days taken, times abducted, level reached. No score. Fanfi signs off.
## "Back to the title" goes to the menu; "Keep playing" just closes the card.
class_name EndingCard
extends Control

signal closed

const LAYER: int = 80
## Flags that record how a quest ended, with the recap line for each (first match per group).
const ENDING_FLAGS: Array = [
	["duras_convinced", "ending_duras_convinced"],
	["duras_fought", "ending_duras_fought"],
	["ozo_freed", "ending_ozo_freed"],
	["ozo_fought", "ending_ozo_fought"],
	["ozo_gone", "ending_ozo_gone"],
]
const FLAG_GROUPS: Dictionary = {"duras": ["duras_convinced", "duras_fought"],
	"ozo": ["ozo_freed", "ozo_fought", "ozo_gone"]}

var btn_menu: Button
var btn_keep: Button
var lines: Array[String] = []

static func show_over(parent: Node) -> EndingCard:
	var c := EndingCard.new()
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	parent.add_child(layer)
	layer.add_child(c)
	c.closed.connect(layer.queue_free)
	return c

## The recap as translated lines, in display order. Pure read of `state`.
static func recap_lines(state: GameState, defs: Defs) -> Array[String]:
	var out: Array[String] = []
	out.append(PartyScreen.fmt("ending_pages", [state.pages.size()]))
	out.append(PartyScreen.fmt("ending_days", [state.day]))
	var level: int = state.party[0].level if not state.party.is_empty() else 1
	out.append(PartyScreen.fmt("ending_level", [level]))
	var friends: Array[String] = []
	for i in range(1, state.party.size()):
		friends.append(TranslationServer.translate(state.party[i].name_key))
	if friends.is_empty(): out.append(TranslationServer.translate("ending_alone"))
	else: out.append(PartyScreen.fmt("ending_companions", [", ".join(friends)]))
	var ab: int = abductions(state)
	if ab == 0: out.append(TranslationServer.translate("ending_never_abducted"))
	elif ab == 1: out.append(TranslationServer.translate("ending_abducted_once"))
	else: out.append(PartyScreen.fmt("ending_abducted_many", [ab]))
	for e in QuestLog.entries(state, defs):
		if e.done:
			out.append(PartyScreen.fmt("ending_quest_done", [TranslationServer.translate(e.name_key)]))
	for g in FLAG_GROUPS:
		for f in FLAG_GROUPS[g]:
			if state.flags.get(f, false) == true:
				for pair in ENDING_FLAGS:
					if pair[0] == f: out.append(TranslationServer.translate(pair[1]))
				break
	if state.flags.get("strigoi_ally", false) == true or state.flags.get("strigoi_ally_taken", false) == true:
		out.append(TranslationServer.translate("ending_strigoi_ally"))
	return out

## Times abducted: flags["times_abducted"] when present, else one per flag named abducted_*.
static func abductions(state: GameState) -> int:
	var n: Variant = state.flags.get("times_abducted", null)
	if n is int or n is float: return int(n)
	var count: int = 0
	for k in state.flags:
		if str(k).begins_with("abducted_") and state.flags[k] != false: count += 1
	return count

func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p: PanelContainer = UiKit.panel()
	p.position = Vector2(120, 34)
	p.custom_minimum_size = Vector2(400, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 3)
	p.add_child(v)
	var title: Label = PartyScreen.ink_label("ending_title")
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub: Label = PartyScreen.ink_label("ending_subtitle")
	sub.theme_type_variation = &"DimLabel"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 370
	v.add_child(sub)
	v.add_child(_gap(4))
	lines = recap_lines(Game.state, Content.defs)
	for line in lines:
		var l: Label = PartyScreen.ink_label("")
		l.text = "- " + line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 370
		v.add_child(l)
	v.add_child(_gap(4))
	var q: Label = PartyScreen.ink_label("ending_question")
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_color_override(&"font_color", PartyScreen.INK_RED)
	v.add_child(q)
	var sign: Label = PartyScreen.ink_label("ending_fanfi_signoff")
	sign.add_theme_color_override(&"font_color", Color("344f86"))
	sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sign.custom_minimum_size.x = 370
	v.add_child(sign)
	v.add_child(_gap(4))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	btn_keep = UiKit.button("ending_keep_playing")
	btn_keep.pressed.connect(close)
	row.add_child(btn_keep)
	btn_menu = UiKit.button("ending_to_menu")
	btn_menu.pressed.connect(_to_menu)
	row.add_child(btn_menu)
	PartyScreen.focus_later(btn_keep)
	# Centre vertically once the panel knows its height.
	_center.call_deferred(p)

func _center(p: PanelContainer) -> void:
	p.reset_size()
	p.position.y = maxf(4.0, roundf((get_viewport_rect().size.y - p.size.y) / 2.0))

func close() -> void:
	closed.emit()

func _to_menu() -> void:
	close()
	Router.go(&"menu")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

static func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c
