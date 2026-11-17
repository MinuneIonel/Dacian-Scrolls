## Debug scene for screenshots of the gore fx: opens the combat view on a real encounter with the
## debug party, does not start the turn loop, and plays made-up deaths for every enemy (view only,
## no Battle is changed). tools/shots.sh res://src/modes/combat/fx/fx_preview.tscn out.png 70 \
##   1280x720 --args='{"gore":2,"encounter_id":"bancul_patrol","gib":false}'
extends Node

func _ready() -> void:
	var a: Dictionary = Router.args if Router.args is Dictionary else {}
	Settings.gore = clampi(int(a.get("gore", 1)), 0, 2)
	Router.args = {"encounter_id": str(a.get("encounter_id", "bancul_patrol")), "debug_party": true}
	var view: Node2D = (load("res://src/modes/combat/combat.tscn") as PackedScene).instantiate()
	view.auto_start = false
	view.audio = false
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	var gib: bool = bool(a.get("gib", false))
	var ev: Array[Dictionary] = []
	for u in view.battle.units():
		if str(u.get("side", "")) != "enemy": continue
		ev.append({"type": "damaged", "target": int(u.uid), "amount": int(u.max_hp), "crit": true, "shield_absorbed": 0})
		ev.append({"type": "died", "target": int(u.uid), "gib": gib, "corpse": false})
	ev.reverse()   # the giant (listed first) dies last, so the shot catches it mid-pop
	var paired: Array[Dictionary] = []
	for i in range(0, ev.size(), 2): paired.append_array([ev[i + 1], ev[i]])
	view.player.play(paired)
