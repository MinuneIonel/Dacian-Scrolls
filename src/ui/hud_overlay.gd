## Global overlay autoload (Hud): toasts and Fanfi's narrator captions above every mode.
## Listens to Bus.events_emitted: asks Narrator for Fanfi's line, queues it on the caption, and
## opens the EndingCard when the 12th page is found. Views only broadcast events.
extends CanvasLayer

const TOAST_LAYER: int = 91
const PAGES_TO_WIN: int = 12

var root: Control
var toasts: ToastLayer
var caption: NarratorCaption
var ending: EndingCard
var _foreign_toasts: int = 0
## Fanfi's line picker draws from its own Rng, never Game.rng: presentation must not shift
## game outcomes (a battle or a roll would differ depending on how many lines were shown).
var narrator_rng: Rng = Rng.new(randi())

func _ready() -> void:
	layer = 90
	name = "Hud"
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	caption = NarratorCaption.new()
	root.add_child(caption)
	toasts = UiKit.toast_layer() as ToastLayer
	toasts.layer = TOAST_LAYER
	add_child(toasts)
	Bus.events_emitted.connect(_on_events)
	get_tree().node_added.connect(_on_node_added)

func _on_events(events: Array[Dictionary]) -> void:
	var evs: Array[Dictionary] = events
	if Game.state == null or Game.state.party.is_empty():
		# Title screen: no party, so only explicit narrator lines make sense.
		evs = []
		for e in events:
			if str(e.get("type", "")) == "narrator": evs.append(e)
	if not evs.is_empty() and Content.defs != null:
		for line in Narrator.lines_for(evs, Game.state, narrator_rng, Content.defs):
			caption.queue_line(line)
	for e in events:
		if str(e.get("type", "")) == "page_found" and Game.state != null \
				and Game.state.pages.size() >= PAGES_TO_WIN:
			show_ending()
			break

## Opens the recap card (once at a time).
func show_ending() -> EndingCard:
	if ending != null and is_instance_valid(ending): return ending
	ending = EndingCard.show_over(self)
	return ending

# A mode that still adds its own UiKit.toast_layer() (the menu) would show every toast twice;
# while one exists, ours stays hidden.
func _on_node_added(node: Node) -> void:
	if node is ToastLayer and node != toasts:
		_foreign_toasts += 1
		node.tree_exiting.connect(_on_foreign_toasts_gone, CONNECT_ONE_SHOT)
		toasts.visible = false

func _on_foreign_toasts_gone() -> void:
	_foreign_toasts = maxi(0, _foreign_toasts - 1)
	toasts.visible = _foreign_toasts == 0
