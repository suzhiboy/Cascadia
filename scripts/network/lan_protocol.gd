class_name LanProtocol
extends RefCounted

const PROTOCOL_VERSION := 3
const DEFAULT_GAME_PORT := 35721
const DISCOVERY_PORT := 35722
const RECONNECT_TIMEOUT_SEC := 120.0

static func make_announcement(info: Dictionary) -> Dictionary:
	var out = info.duplicate(true)
	out["protocol"] = PROTOCOL_VERSION
	out["game"] = "tidetrace"
	return out

static func parse_announcement(packet: PackedByteArray) -> Dictionary:
	var value = JSON.parse_string(packet.get_string_from_utf8())
	if not value is Dictionary or int(value.get("protocol", 0)) != PROTOCOL_VERSION or value.get("game", "") != "tidetrace":
		return {}
	return value

static func make_command(request_id: int, action: String, args: Dictionary) -> Dictionary:
	return {"protocol":PROTOCOL_VERSION,"kind":"command","request_id":request_id,"action":action,"args":args.duplicate(true)}

static func validate_command(command: Dictionary) -> String:
	if int(command.get("protocol", 0)) != PROTOCOL_VERSION:
		return "联机协议版本不兼容。"
	if command.get("kind", "") != "command" or int(command.get("request_id", 0)) < 1:
		return "无效的联机命令。"
	if str(command.get("action", "")) not in ["draft","refresh","place_tile","place_animal","discard_animal","clear_preview","rotate_pending","commit_turn"]:
		return "未知的联机操作。"
	if not command.get("args", {}) is Dictionary:
		return "无效的联机参数。"
	return ""
