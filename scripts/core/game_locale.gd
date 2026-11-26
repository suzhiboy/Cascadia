class_name GameLocale
extends RefCounted

static func text(message: String) -> String:
	return String(TranslationServer.translate(message))

static func player_name(value: String) -> String:
	# Default names in saves and LAN snapshots use one stable representation.
	for prefix in ["旅行者 ","电脑 "]:
		if value.begins_with(prefix):
			var seat = value.trim_prefix(prefix)
			if seat in ["1","2","3","4"]:
				return text(prefix+"%d") % int(seat)
	if value == "练习旅行者":
		return text(value)
	return value
