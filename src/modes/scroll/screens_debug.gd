## Debug scene for screenshots of the WP-24 screens. Not used by the game.
## tools/shots.sh res://src/modes/scroll/screens_debug.tscn out.png 20 640x360 \
##   --args='{"show":"party","debug_pages":5}'
## show: scroll | party | shop | caption | ending. Extra keys go to the scroll (tab, page).
extends Node

func _ready() -> void:
	var a: Dictionary = Router.args.duplicate()
	Router.switch_scenes = false
	Router.autosave_enabled = false
	Game.new_game(int(a.get("seed", 1)), StringName(str(a.get("hero", "knight"))))
	var s: GameState = Game.state
	var fx: Array = []
	var pages: Array[Dictionary] = Content.all(&"page").duplicate()
	pages.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.order) < int(y.order))
	var want: int = int(a.get("debug_pages", 5))
	var order: Array[int] = [0, 2, 4, 5, 7, 1, 3, 6, 8, 9, 10, 11]
	for i in mini(want, order.size()): fx.append(["page", str(pages[order[i]].id)])
	if a.get("debug_party", true):
		fx.append(["recruit", "vezina"])
		fx.append_array([["give_item", "bread", 3], ["give_item", "healing_herbs", 2], ["give_item", "power_cell", 1],
			["give_item", "scale_mail", 1], ["give_item", "draco_pennant", 1], ["give_item", "strigoi_taxes", 1],
			["give_item", "gravity_coil", 1], ["gold", 96], ["quest", "dead_dont_pay_taxes", 30],
			["quest", "delivery_in_188_hours", 100], ["set_flag", "ozo_freed", true]])
	Rules.run(fx, s, Game.rng, Content.defs)
	if not s.party.is_empty():
		s.party[0].gear["weapon"] = &"iron_falx"
		s.party[0].hp = maxi(1, s.party[0].max_hp - 9)
		s.party[0].charge = 2
	s.day = 9
	var show: String = str(a.get("show", "scroll"))
	if show == "scroll":
		var sc: Node = load("res://src/modes/scroll/scroll.tscn").instantiate()
		add_child(sc)
		return
	var map: Node2D = MapBuilder.build(&"sarmizegetusa", Content.defs)
	add_child(map)
	var u := UnitSprite.new(&"knight")
	u.place(s.location_cell)
	map.get_node("Sorted").add_child(u)
	var cam := Camera2D.new()
	cam.position = Iso.cell_to_world(s.location_cell) + Vector2(0, -60)
	add_child(cam)
	match show:
		"party": PartyScreen.show_over(self)
		"shop": ShopScreen.show_over(self, StringName(str(a.get("shop", "trader_shop"))))
		"ending": EndingCard.show_over(self)
		"caption":
			Hud.caption.queue_line(str(a.get("line", "fanfi_page_found_1")))
			Hud.caption.queue_line("fanfi_level_up_1")
