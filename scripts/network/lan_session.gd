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
var _join_info := {}
var _connect_age := 0.0

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
	_publish_lobby()
	return OK

func join_lobby(address: String, port: int, player_name: String, seat: int = -1, reconnect_token: String = "") -> Error:
	shutdown()
	if not address.is_valid_ip_address() or address.contains(":") or port < 1 or port > 65535:
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	host = false
	_local_seat = seat
	_join_info = {"address":address,"port":port,"name":player_name,"seat":seat,"token":reconnect_token}
	_connect_age = 0.0
	_lobby = {}
	return OK

func set_local_name(name: String) -> void:
	if host:
		_lobby.slots[_local_seat].name = name.strip_edges()
		_publish_lobby()
	else:
		_join_info.name = name.strip_edges()
		_lobby_update.rpc_id(1, {"name":_join_info.name})

func choose_seat(seat: int) -> void:
	_local_seat = seat
	if host:
		return
	_lobby_update.rpc_id(1, {"seat":seat})

func set_ready(ready: bool) -> void:
	if host:
		_lobby.slots[_local_seat].ready = ready
		_publish_lobby()
	else:
		_lobby_update.rpc_id(1, {"ready":ready})

func host_set_count(count: int) -> void:
	if not host or started:
		return
	_lobby.count = clampi(count,2,4)
	while _lobby.slots.size() < _lobby.count:
		_lobby.slots.append({"seat":_lobby.slots.size(),"name":"","connected":false,"ready":false})
	_lobby.slots.resize(_lobby.count)
	_publish_lobby()

func host_set_cards(cards: Dictionary) -> void:
	if host and not started:
		_lobby.cards = cards.duplicate(true)
		for i in range(1,_lobby.slots.size()): _lobby.slots[i].ready = false
		_publish_lobby()

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
	_last_request.clear()
	_join_info.clear()
	game = null
	_request_id = 0
	_reconnect_elapsed = -1.0
	_seat_deadlines.clear()

func _process(delta: float) -> void:
	if not host and not _join_info.is_empty() and _reconnect_elapsed < 0 and _join_info.get("token","").is_empty():
		_connect_age += delta
		if _connect_age > 12:
			_on_connection_failed()
			return
	if _reconnect_elapsed >= 0.0:
		_reconnect_elapsed += delta
		connection_changed.emit("reconnecting",{"seconds":int(_reconnect_elapsed)})
		_reconnect_wait -= delta
		if _reconnect_elapsed >= LanProtocol.RECONNECT_TIMEOUT_SEC:
			_reconnect_elapsed = -1.0
			session_closed.emit("重连超时，联机房间已结束。")
			shutdown()
		elif _reconnect_wait <= 0.0 and not host:
			_reconnect_wait = 2.0
			if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
				peer = ENetMultiplayerPeer.new()
				if peer.create_client(str(_join_info.get("address", "")), int(_join_info.get("port", LanProtocol.DEFAULT_GAME_PORT))) == OK:
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
func can_control_player(index: int) -> bool: return started and _reconnect_elapsed < 0 and index == _local_seat and game != null and game.active == index

@rpc("any_peer", "reliable")
func _submit_command(command: Dictionary) -> void:
	if host:
		_apply_command(multiplayer.get_remote_sender_id(), command)

@rpc("any_peer", "reliable")
func _lobby_update(update: Dictionary) -> void:
	if not host or started:
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
					_lobby.slots[wanted].name = slot.name
					_lobby.slots[wanted].connected = true
					_lobby.slots[wanted].ready = false
					slot.connected = false
					slot.ready = false
					_seat_by_peer[sender] = wanted
					for token in _tokens:
						if _tokens[token] == slot.seat:
							_tokens[token] = wanted
							_welcome.rpc_id(sender,wanted,token)
			else:
				slot[key] = str(update[key]).strip_edges().left(12) if key == "name" else bool(update[key])
	_publish_lobby()

func _apply_command(sender: int, command: Dictionary) -> void:
	var error = LanProtocol.validate_command(command)
	var request_id = int(command.get("request_id", 0))
	if error.is_empty() and (not started or not _seat_by_peer.has(sender) or int(_seat_by_peer[sender]) != game.active):
		error = "还没轮到这位玩家。"
	if error.is_empty() and request_id <= int(_last_request.get(sender,0)):
		error = "操作已处理，请勿重复发送。"
	if error.is_empty():
		_last_request[sender] = request_id
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
	started = true
	revision = incoming_revision
	state_changed.emit(snapshot, revision)

@rpc("authority", "reliable")
func _receive_action_result(request_id: int, accepted: bool, message: String) -> void:
	action_result.emit(request_id, accepted, message)

func _publish_lobby() -> void:
	_lobby.joined = _lobby.slots.filter(func(slot): return slot.connected).size()
	lobby_changed.emit(_lobby.duplicate(true))
	if host:
		for id in _seat_by_peer:
			if id != 1:
				_receive_lobby.rpc_id(id,_lobby)

@rpc("authority","reliable")
func _receive_lobby(data: Dictionary) -> void:
	_lobby = data.duplicate(true)
	lobby_changed.emit(_lobby)

func _on_peer_connected(_id: int) -> void:
	pass # A connection gets a seat only after the explicit join handshake.

@rpc("any_peer","reliable")
func _hello(version: int, info: Dictionary) -> void:
	if not host: return
	var id = multiplayer.get_remote_sender_id()
	if _seat_by_peer.has(id): return
	if version != LanProtocol.PROTOCOL_VERSION:
		_rejected.rpc_id(id,"版本不同，请两位玩家使用同一份最新游戏包。")
		return
	var seat = -1
	var token = str(info.get("token",""))
	if not token.is_empty() and _tokens.has(token):
		seat = int(_tokens[token])
		if _lobby.slots[seat].connected: seat = -1
	elif not started:
		var desired = int(info.get("seat",-1))
		if desired > 0 and desired < _lobby.count and not _lobby.slots[desired].connected:
			seat = desired
		else:
			for i in range(1,_lobby.count):
				if not _lobby.slots[i].connected:
					seat = i
					break
	if seat < 0:
		_rejected.rpc_id(id,"房间已开局，不能加入新玩家。" if started else "房间已满，请选择其他房间。")
		return
	if token.is_empty() or not _tokens.has(token):
		token = Crypto.new().generate_random_bytes(24).hex_encode()
		_tokens[token] = seat
	_seat_by_peer[id] = seat
	_seat_deadlines.erase(seat)
	_lobby.slots[seat].connected = true
	_lobby.slots[seat].ready = started
	if not started:
		_lobby.slots[seat].name = str(info.get("name","旅行者")).strip_edges().left(12)
		if _lobby.slots[seat].name.is_empty(): _lobby.slots[seat].name = "旅行者"
	_welcome.rpc_id(id,seat,token)
	_publish_lobby()
	if started: _broadcast_state.rpc_id(id,game.snapshot(),revision)

@rpc("authority","reliable")
func _welcome(seat: int, token: String) -> void:
	_local_seat = seat
	_join_info.token = token
	_reconnect_elapsed = -1.0
	_connect_age = 0.0
	connection_changed.emit("connected",{"seat":seat})

@rpc("authority","reliable")
func _rejected(reason: String) -> void:
	shutdown()
	session_closed.emit(reason)

func _on_peer_disconnected(id: int) -> void:
	if host and _seat_by_peer.has(id):
		var seat = int(_seat_by_peer[id])
		_seat_by_peer.erase(id)
		_lobby.slots[seat].connected = false
		_lobby.slots[seat].ready = false
		if started:
			_seat_deadlines[seat] = Time.get_ticks_msec() + int(LanProtocol.RECONNECT_TIMEOUT_SEC * 1000)
		_publish_lobby()
		if started and game.active == seat:
			connection_changed.emit("paused", {"seat":seat})

func _on_connected() -> void:
	if not host:
		_hello.rpc_id(1,LanProtocol.PROTOCOL_VERSION,_join_info)

func _on_connection_failed() -> void:
	if _reconnect_elapsed >= 0: return
	shutdown()
	session_closed.emit("连接失败。请检查房主热点 IPv4 地址、UDP 35721 防火墙放行及热点是否允许设备互访。")

func _on_server_disconnected() -> void:
	if not _join_info.get("token","").is_empty():
		if _reconnect_elapsed < 0: _reconnect_elapsed = 0.0
		_reconnect_wait = 2.0
		connection_changed.emit("reconnecting",{})
	else:
		_on_connection_failed()
