## tr() plus formatting that never errors: when the translation is missing (e.g. tests on fixture
## strings) or has fewer placeholders than args, the args are appended instead.
extends RefCounted

static func trf(key: String, args: Variant) -> String:
	var s: String = TranslationServer.translate(key)
	var arr: Array = args if args is Array else [args]
	var slots: int = s.count("%") - 2 * s.count("%%")
	if slots != arr.size():
		return s + " " + " ".join(arr.map(func(a: Variant) -> String: return str(a)))
	return s % arr
