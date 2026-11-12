## Turns a GameState into text and back. Never trusts its input.
class_name SaveCodec
extends RefCounted

static func encode(state: GameState) -> String:
	push_error("not implemented: SaveCodec.encode")  # WP-10
	return ""

## Returns {ok: bool, state: GameState or null, error_key: String}.
## error_key is a string-table key such as "save_corrupt" or "save_too_new".
static func decode(text: String) -> Dictionary:
	push_error("not implemented: SaveCodec.decode")  # WP-10
	return {"ok": false, "state": null, "error_key": "save_corrupt"}
