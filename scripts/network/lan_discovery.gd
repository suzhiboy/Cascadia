class_name LanDiscovery
extends Node

signal room_found(room: Dictionary)

var udp := PacketPeerUDP.new()
var scanning := false
var announcing := false
var announcement := {}
var seen := {}
var _elapsed := 0.0

func start_scan() -> Error:
	stop()
	var error = udp.bind(LanProtocol.DISCOVERY_PORT)
	if error != OK:
		return error
	udp.set_broadcast_enabled(true)
	scanning = true
	return OK

func start_announce(info: Dictionary) -> Error:
	stop()
	announcement = LanProtocol.make_announcement(info)
	var error = udp.bind(0)
	if error != OK:
		return error
	udp.set_broadcast_enabled(true)
	announcing = true
	_broadcast()
	return OK

func stop() -> void:
	scanning = false
	announcing = false
	seen.clear()
	udp.close()

func _process(delta: float) -> void:
	if not scanning and not announcing:
		return
	_elapsed += delta
	if announcing and _elapsed >= 1.0:
		_elapsed = 0.0
		_broadcast()
	if scanning:
		while udp.get_available_packet_count() > 0:
			var room = LanProtocol.parse_announcement(udp.get_packet())
			if not room.is_empty():
				room["last_seen"] = Time.get_ticks_msec()
				seen[str(room.get("room_id", room.get("address", "")))] = room
				room_found.emit(room)

func _broadcast() -> void:
	var bytes = JSON.stringify(announcement).to_utf8_buffer()
	udp.set_dest_address("255.255.255.255", LanProtocol.DISCOVERY_PORT)
	udp.put_packet(bytes)
