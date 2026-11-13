## All loaded content definitions, by kind and id. Core code receives a Defs and never
## reads files itself. Build one with ContentLoader.load_root() or by hand in tests.
class_name Defs
extends RefCounted

const KINDS: Array[StringName] = [&"class", &"ability", &"item", &"enemy", &"encounter",
	&"map", &"dialogue", &"quest", &"page", &"npc", &"shop"]

var _by_kind: Dictionary = {}   # StringName kind -> Dictionary(StringName id -> Dictionary)
var _json: Dictionary = {}      # String name -> Variant, e.g. "world", "fanfi", "tiles"

func add(kind: StringName, def: Dictionary) -> void:
	if not _by_kind.has(kind): _by_kind[kind] = {}
	_by_kind[kind][StringName(def.get("id", ""))] = def

## The definition, or {} (and one logged error) when it does not exist.
func get_def(kind: StringName, id: StringName) -> Dictionary:
	var d: Dictionary = _by_kind.get(kind, {}).get(id, {})
	if d.is_empty(): push_error("Defs: unknown %s '%s'" % [kind, id])
	return d

func has(kind: StringName, id: StringName) -> bool:
	return _by_kind.get(kind, {}).has(id)

## Every definition of a kind, sorted by id.
func all(kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array = _by_kind.get(kind, {}).keys()
	ids.sort_custom(func(a, b): return str(a) < str(b))
	for id in ids: out.append(_by_kind[kind][id])
	return out

func set_json(name: String, value: Variant) -> void:
	_json[name] = value

## A singleton data file: "world", "fanfi" or "tiles". Returns {} when absent.
func json(name: String) -> Variant:
	return _json.get(name, {})
