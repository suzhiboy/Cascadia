extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var P = load("res://scripts/network/lan_protocol.gd")
	var announcement = P.make_announcement({"room_id":"abc","port":35721,"count":2,"joined":1,"started":false})
	check(announcement.protocol == 1 and announcement.game == "cascadia", "announcement metadata")
	var parsed = P.parse_announcement(JSON.stringify(announcement).to_utf8_buffer())
	check(parsed.room_id == "abc" and int(parsed.port) == 35721, "announcement roundtrip")
	var command = P.make_command(1,"draft",{"tile_index":0,"animal_index":0})
	check(P.validate_command(command).is_empty(), "valid command")
	command.action = "hack"
	check(not P.validate_command(command).is_empty(), "unknown action rejected")
	print("NETWORK PROTOCOL: %d failures" % failures)
	quit(0 if failures == 0 else 1)
