class_name LanSession
extends Node

const G = preload("res://scripts/core/game_state.gd")

signal lobby_changed(data: Dictionary)
signal state_changed(snapshot: Dictionary, revision: int)
signal action_result(request_id: int, accepted: bool, message: String)
signal connection_changed(status: String, details: Dictionary)
signal session_closed(reason: String)

var game: GameState
var peer: ENetMultiplayerPeer
var host := false
var started := false
var revision := 0
var _request_id := 0
var _local_seat := -1
var _room_id := ""
var _lobby := {}
var _seat_by_peer := {}
var _tokens := {}
var _last_request := {}
var _reconnect_elapsed := -1.0
var _reconnect_wait := 0.0
var _seat_deadlines := {}

func _ready() -> void:
	set_process(true)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_lobby(settings: Dictionary) -> Error:
	shutdown()
	peer = ENetMultiplayerPeer.new()
	var port = int(settings.get("port", LanProtocol.DEFAULT_GAME_PORT))
	var error = peer.create_server(port, 4)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	host = true
	_room_id = "%x" % (Time.get_ticks_usec() ^ randi())
	var local_address = "127.0.0.1"
	for candidate in IP.get_local_addresses():
		if str(candidate).count(".") == 3 and not str(candidate).begins_with("127."):
			local_address = str(candidate)
			break
	_lobby = {"room_id":_room_id,"address":local_address,"joined":1,"count":clampi(int(settings.get("count", 2)),2,4),"cards":settings.get("cards", {}).duplicate(true),"port":port,"host_name":str(settings.get("host_name", "房主")),"started":false,"slots":[]}
	for i in range(int(_lobby.count)):
		_lobby.slots.append({"seat":i,"name":"","connected":false,"ready":false})
	_local_seat = 0
	_lobby.slots[0].name = _lobby.host_name
	_lobby.slots[0].connected = true
	_lobby.slots[0].ready = true
	_seat_by_peer[1] = 0
	lobby_changed.emit(_lobby.duplicate(true))
	return OK

func join_lobby(address: String, port: int, player_name: String, seat: int = -1, reconnect_token: String = "") -> Error:
	shutdown()
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	host = false
	_local_seat = seat
	_lobby = {"address":address,"port":port,"name":player_name,"seat":seat,"token":reconnect_token}
	return OK

func set_local_name(name: String) -> void:
	if host:
		_lobby.slots[_local_seat].name = name.strip_edges()
		lobby_changed.emit(_lobby.duplicate(true))
	else:
		_lobby.name = name.strip_edges()
		_lobby_update.rpc_id(1, {"name":_lobby.name})

func choose_seat(seat: int) -> void:
	_local_seat = seat
	if host:
		return
	_lobby_update.rpc_id(1, {"seat":seat})

func set_ready(ready: bool) -> void:
	if host:
		_lobby.slots[_local_seat].ready = ready
		lobby_changed.emit(_lobby.duplicate(true))
	else:
		_lobby_update.rpc_id(1, {"ready":ready})

func host_set_count(count: int) -> void:
	if not host or started:
		return
	_lobby.count = clampi(count,2,4)
	while _lobby.slots.size() < _lobby.count:
		_lobby.slots.append({"seat":_lobby.slots.size(),"name":"","connected":false,"ready":false})
	_lobby.slots.resize(_lobby.count)
	lobby_changed.emit(_lobby.duplicate(true))

func host_set_cards(cards: Dictionary) -> void:
	if host and not started:
		_lobby.cards = cards.duplicate(true)
		lobby_changed.emit(_lobby.duplicate(true))

func host_start_game() -> String:
	if not host or started:
		return "只有未开始的房主可以开局。"
	for slot in _lobby.slots:
		if not slot.connected or not slot.ready or str(slot.name).strip_edges().is_empty():
			return "请等待所有玩家连接并准备。"
	game = G.new()
	game.start({"count":_lobby.count,"names":_lobby.slots.map(func(s): return s.name),"cards":_lobby.cards})
	started = true
	_lobby.started = true
	revision = 1
	_sync_state()
	return ""

func request(action: String, args: Dictionary = {}) -> int:
	_request_id += 1
	var command = LanProtocol.make_command(_request_id, action, args)
	if host:
		_apply_command(1, command)
	else:
		_submit_command.rpc_id(1, command)
	return _request_id

func shutdown() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	peer = null
	host = false
	started = false
	_lobby = {}
	_seat_by_peer.clear()
	_tokens.clear()
	_reconnect_elapsed = -1.0
	_seat_deadlines.clear()

func _process(delta: float) -> void:
	if _reconnect_elapsed >= 0.0:
		_reconnect_elapsed += delta
		_reconnect_wait -= delta
		if _reconnect_elapsed >= LanProtocol.RECONNECT_TIMEOUT_SEC:
			_reconnect_elapsed = -1.0
			session_closed.emit("重连超时，联机房间已结束。")
			shutdown()
		elif _reconnect_wait <= 0.0 and not host:
			_reconnect_wait = 2.0
			if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
				peer = ENetMultiplayerPeer.new()
				if peer.create_client(str(_lobby.get("address", "127.0.0.1")), int(_lobby.get("port", LanProtocol.DEFAULT_GAME_PORT))) == OK:
					multiplayer.multiplayer_peer = peer
	for seat in _seat_deadlines.keys():
		if Time.get_ticks_msec() >= int(_seat_deadlines[seat]):
			_seat_deadlines.erase(seat)
			if started:
				session_closed.emit("玩家重连超时，房间已结束。")
				shutdown()
				return

func is_host() -> bool: return host
func local_seat() -> int: return _local_seat
func can_control_player(index: int) -> bool: return started and index == _local_seat and game != null and game.active == index

@rpc("any_peer", "reliable")
func _submit_command(command: Dictionary) -> void:
	if host:
		_apply_command(multiplayer.get_remote_sender_id(), command)

@rpc("any_peer", "reliable")
func _lobby_update(update: Dictionary) -> void:
	if not host:
		return
	var sender = multiplayer.get_remote_sender_id()
	if not _seat_by_peer.has(sender):
		return
	var slot = _lobby.slots[int(_seat_by_peer[sender])]
	for key in ["name","seat","ready"]:
		if update.has(key):
			if key == "seat":
				var wanted = clampi(int(update[key]),0,_lobby.slots.size()-1)
				if not _lobby.slots[wanted].connected:
					slot.seat = wanted
			else:
				slot[key] = update[key]
	lobby_changed.emit(_lobby.duplicate(true))

func _apply_command(sender: int, command: Dictionary) -> void:
	var error = LanProtocol.validate_command(command)
	var request_id = int(command.get("request_id", 0))
	if error.is_empty() and (not started or not _seat_by_peer.has(sender) or int(_seat_by_peer[sender]) != game.active):
		error = "还没轮到这位玩家。"
	if error.is_empty():
		error = game.apply_action(str(command.action), command.args)
	if not error.is_empty():
		if sender == 1: action_result.emit(request_id, false, error)
		else: _receive_action_result.rpc_id(sender, request_id, false, error)
		return
	if sender == 1: action_result.emit(request_id, true, "")
	else: _receive_action_result.rpc_id(sender, request_id, true, "")
	revision += 1
	_sync_state()

func _sync_state() -> void:
	if game == null:
		return
	var snapshot = game.snapshot()
	state_changed.emit(snapshot, revision)
	if host:
		_broadcast_state.rpc(snapshot, revision)

@rpc("authority", "reliable")
func _broadcast_state(snapshot: Dictionary, incoming_revision: int) -> void:
	if host:
		return
	if game == null: game = G.new()
	game.restore(snapshot)
	revision = incoming_revision
	state_changed.emit(snapshot, revision)

@rpc("authority", "reliable")
func _receive_action_result(request_id: int, accepted: bool, message: String) -> void:
	action_result.emit(request_id, accepted, message)

func _on_peer_connected(id: int) -> void:
	if host:
		var seat = -1
		for slot in _lobby.slots:
			if not slot.connected:
				seat = int(slot.seat)
				break
		if seat < 0:
				peer.disconnect_peer(id)
				return
		_seat_by_peer[id] = seat
		_lobby.slots[seat].connected = true
		_lobby.joined = _lobby.slots.filter(func(s): return s.connected).size()
		_seat_deadlines.erase(seat)
		lobby_changed.emit(_lobby.duplicate(true))

func _on_peer_disconnected(id: int) -> void:
	if host and _seat_by_peer.has(id):
		var seat = int(_seat_by_peer[id])
		_lobby.slots[seat].connected = false
		_seat_deadlines[seat] = Time.get_ticks_msec() + int(LanProtocol.RECONNECT_TIMEOUT_SEC * 1000.0)
		lobby_changed.emit(_lobby.duplicate(true))
		if started and game.active == seat:
			connection_changed.emit("paused", {"seat":seat})

func _on_connected() -> void:
	connection_changed.emit("connected", {})
	if not host:
		_lobby_update.rpc_id(1, {"name":str(_lobby.get("name", "旅行者")),"seat":int(_lobby.get("seat", 1)),"ready":true})
func _on_connection_failed() -> void:
	if not host and not _lobby.is_empty():
		_reconnect_elapsed = 0.0
		connection_changed.emit("reconnecting", {"seconds":0})
	else:
		session_closed.emit("无法连接到房间。")

func _on_server_disconnected() -> void:
	if not host and not _lobby.is_empty() and started:
		_reconnect_elapsed = 0.0
		connection_changed.emit("reconnecting", {"seconds":0})
	else:
		session_closed.emit("房主已断开，房间结束。")
