extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var P = load("res://scripts/network/lan_protocol.gd")
	var announcement = P.make_announcement({"room_id":"abc","port":35721,"count":2,"joined":1,"started":false})
	check(announcement.protocol == P.PROTOCOL_VERSION and announcement.game == "tidetrace" and P.PROTOCOL_VERSION == 4, "announcement metadata")
	var parsed = P.parse_announcement(JSON.stringify(announcement).to_utf8_buffer())
	check(parsed.room_id == "abc" and int(parsed.port) == 35721, "announcement roundtrip")
	var command = P.make_command(1,"draft",{"tile_index":0,"animal_index":0})
	check(P.validate_command(command).is_empty(), "valid command")
	command.protocol = 3
	check(not P.validate_command(command).is_empty(),"Old scoring rules cannot send commands")
	announcement.protocol = 3
	check(P.parse_announcement(JSON.stringify(announcement).to_utf8_buffer()).is_empty(),"Old rooms are hidden")
	command.protocol = 4
	command.action = "hack"
	check(not P.validate_command(command).is_empty(), "unknown action rejected")
	print("NETWORK PROTOCOL: %d failures" % failures)
	quit(0 if failures == 0 else 1)
