class_name GameState
extends RefCounted

const SAVE_VERSION := 2
const H = preload("res://scripts/core/hex.gd")
const Tiles = preload("res://scripts/core/tile_definition.gd")
const Config = preload("res://scripts/core/game_config.gd")

var config: Dictionary = {}
var players: Array = []
var deck: Array = []
var bag: Array = []
var market_tiles: Array = []
var market_animals: Array = []
var removed_tiles: Array = []
var removed_animals: Array = []
var held: Array = []
var pending: Dictionary = {}
var active = 0
var optional_used = false
var finished = false
var rng = RandomNumberGenerator.new()
var last_notice = ""

func start(raw: Dictionary, seed_value: int = -1) -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	config = Config.normalize(raw,rng)
	players.clear()
	deck = range(16,101)
	_shuffle(deck)
	deck.resize(43 if config.count == 1 else config.count*20+3)
	bag.clear()
	for animal in Tiles.ANIMALS:
		for _i in range(20):
			bag.append(animal)
	var starters = [0,1,2,3,4]
	_shuffle(starters)
	for i in range(config.count):
		var board = {}
		for j in range(3):
			var p = [Vector2i(0,0),Vector2i(-1,1),Vector2i(0,1)][j]
			var id = starters[i]*3+j+1
			board[H.key(p)] = {"q":p.x,"r":p.y,"tile":id,"rotation":Tiles.get_tile(id).rotation,"animal":""}
		players.append({"name":config.names[i],"board":board,"nature":0,"turns":0})
	market_tiles.clear()
	market_animals.clear()
	removed_tiles.clear()
	removed_animals.clear()
	held.clear()
	pending.clear()
	active = 0
	optional_used = false
	finished = false
	for _i in range(4):
		market_tiles.append(deck.pop_back())
		market_animals.append(_draw())
	_resolve_four()

func _shuffle(items: Array) -> void:
	for i in range(items.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var value = items[i]
		items[i] = items[j]
		items[j] = value

func _draw() -> String:
	assert(not bag.is_empty(), "Wildlife bag unexpectedly empty")
	var i = rng.randi_range(0,bag.size()-1)
	var animal = bag[i]
	bag.remove_at(i)
	return animal

func _release_held() -> void:
	bag.append_array(held)
	held.clear()

func _resolve_four() -> void:
	while market_animals.size() == 4 and market_animals.count(market_animals[0]) == 4:
		# Reserve replaced batches until the sequence ends. If that
		# leaves too few tokens, return earlier batches before withholding this one.
		if bag.size() < 4:
			_release_held()
		held.append_array(market_animals)
		market_animals.clear()
		for _i in range(4):
			market_animals.append(_draw())
		last_notice = "四枚同种动物过剩，已自动更换。"
	if triplicate().is_empty() or optional_used:
		_release_held()

func triplicate() -> Array:
	if not pending.is_empty() or optional_used or finished:
		return []
	for animal in Tiles.ANIMALS:
		if market_animals.count(animal) == 3:
			var indices = []
			for i in range(4):
				if market_animals[i] == animal:
					indices.append(i)
			return indices
	return []

func refresh(indices: Array, spend_nature: bool) -> String:
	if finished or not pending.is_empty():
		return "请在选取地块前使用。"
	if indices.is_empty():
		return "请选择至少一枚动物。"
	var unique = {}
	for i in indices:
		if int(i) < 0 or int(i) > 3 or unique.has(int(i)):
			return "无效的动物选择。"
		unique[int(i)] = true
	if spend_nature:
		if players[active].nature < 1:
			return "自然标记不足。"
		players[active].nature -= 1
		_release_held()
	else:
		var expected = triplicate()
		if expected.size() != 3 or unique.size() != 3:
			return "每回合仅可免费更换一次三枚同种动物。"
		for i in expected:
			if not unique.has(i):
				return "请选择三枚同种动物。"
		optional_used = true
	for i in unique:
		held.append(market_animals[i])
	for i in unique:
		market_animals[i] = _draw()
	_resolve_four()
	# A nature refresh is a completed replacement operation.
	if spend_nature:
		_release_held()
	return ""

func draft(tile_index: int, animal_index: int) -> String:
	if finished or not pending.is_empty():
		return "请先完成当前回合。"
	if tile_index < 0 or tile_index > 3 or animal_index < 0 or animal_index > 3:
		return "请选择市场中的地块与动物。"
	if tile_index != animal_index and players[active].nature < 1:
		return "跨组选取需要一枚自然标记。"
	_release_held()
	if tile_index != animal_index:
		players[active].nature -= 1
	pending = {"tile":market_tiles[tile_index],"animal":market_animals[animal_index],"tile_index":tile_index,"animal_index":animal_index,"tile_pos":null,"rotation":0,"animal_pos":null,"discarded":false}
	market_tiles[tile_index] = 0
	market_animals[animal_index] = ""
	return ""

func frontier() -> Array:
	var found = {}
	var board = players[active].board
	var keys = board.keys()
	keys.sort()
	for k in keys:
		for p in H.neighbors(H.coord(k)):
			if not board.has(H.key(p)):
				found[H.key(p)] = p
	return found.values()

func place_tile(p: Vector2i, rotation: int) -> String:
	if pending.is_empty():
		return "请先从市场选取。"
	if p not in frontier():
		return "地块须与已有地块共边，且不能重叠。"
	if pending.animal_pos != null and pending.animal_pos == pending.tile_pos:
		pending.animal_pos = [p.x,p.y]
	pending.tile_pos = [p.x,p.y]
	pending.rotation = posmod(rotation,6)
	return ""

func preview_board() -> Dictionary:
	var board = players[active].board.duplicate(true)
	if not pending.is_empty() and pending.tile_pos != null:
		var p = Vector2i(pending.tile_pos[0],pending.tile_pos[1])
		board[H.key(p)] = {"q":p.x,"r":p.y,"tile":pending.tile,"rotation":pending.rotation,"animal":""}
	if not pending.is_empty() and pending.animal_pos != null:
		var p = Vector2i(pending.animal_pos[0],pending.animal_pos[1])
		board[H.key(p)].animal = pending.animal
	return board

func legal_animal_cells() -> Array:
	if pending.is_empty():
		return []
	var board = preview_board()
	var legal = []
	for k in board:
		var cell = board[k]
		var current = pending.animal_pos != null and [int(cell.q),int(cell.r)] == pending.animal_pos
		if (cell.animal == "" or current) and pending.animal in Tiles.get_tile(int(cell.tile)).wildlife:
			legal.append(H.coord(k))
	return legal

func place_animal(p: Vector2i) -> String:
	if pending.is_empty():
		return "请先从市场选取。"
	if p not in legal_animal_cells():
		return "动物须放在有对应图标、且尚未入住的地块。"
	pending.animal_pos = [p.x,p.y]
	pending.discarded = false
	return ""

func discard_animal() -> String:
	if pending.is_empty():
		return "请先选取动物。"
	pending.animal_pos = null
	pending.discarded = true
	return ""

func clear_preview() -> void:
	if not pending.is_empty():
		pending.tile_pos = null
		pending.animal_pos = null
		pending.discarded = false

func ready_to_commit() -> bool:
	return not pending.is_empty() and pending.tile_pos != null and (pending.animal_pos != null or pending.discarded)

func commit_turn() -> String:
	if not ready_to_commit():
		return "请摆放地块，并安置动物或选择放归。"
	players[active].board = preview_board()
	if pending.discarded:
		bag.append(pending.animal)
	elif Tiles.keystone(int(players[active].board[H.key(Vector2i(pending.animal_pos[0],pending.animal_pos[1]))].tile)):
		players[active].nature += 1
	players[active].turns += 1
	pending.clear()
	var total = 0
	for player in players:
		total += int(player.turns)
	finished = total == config.count*20
	if finished:
		_release_held()
		return ""
	if config.count == 1:
		market_tiles.erase(0)
		market_animals.erase("")
		removed_tiles.append(market_tiles.pop_back())
		removed_animals.append(market_animals.pop_back())
		for _i in range(2):
			market_tiles.push_front(deck.pop_back())
			market_animals.push_front(_draw())
	else:
		for i in range(4):
			if market_tiles[i] == 0:
				market_tiles[i] = deck.pop_back()
			if market_animals[i] == "":
				market_animals[i] = _draw()
	active = (active+1)%config.count
	optional_used = false
	_resolve_four()
	return ""

func rotate_pending(amount: int) -> String:
	if pending.is_empty():
		return "请先从市场选取。"
	pending.rotation = posmod(int(pending.rotation) + amount, 6)
	return ""

func apply_action(action: String, args: Dictionary) -> String:
	match action:
		"draft":
			return draft(int(args.get("tile_index", -1)), int(args.get("animal_index", -1)))
		"refresh":
			return refresh(Array(args.get("indices", [])), bool(args.get("spend_nature", false)))
		"place_tile":
			var p = Vector2i(int(args.get("q", 0)), int(args.get("r", 0)))
			return place_tile(p, int(args.get("rotation", 0)))
		"place_animal":
			return place_animal(Vector2i(int(args.get("q", 0)), int(args.get("r", 0))))
		"discard_animal":
			return discard_animal()
		"clear_preview":
			clear_preview()
			return ""
		"rotate_pending":
			return rotate_pending(int(args.get("amount", 0)))
		"commit_turn":
			return commit_turn()
		_:
			return "未知的联机操作。"

func snapshot() -> Dictionary:
	return {"version":SAVE_VERSION,"config":config.duplicate(true),"players":players.duplicate(true),"deck":deck.duplicate(),"bag":bag.duplicate(),"market_tiles":market_tiles.duplicate(),"market_animals":market_animals.duplicate(),"removed_tiles":removed_tiles.duplicate(),"removed_animals":removed_animals.duplicate(),"held":held.duplicate(),"pending":pending.duplicate(true),"active":active,"optional_used":optional_used,"finished":finished,"rng_state":str(rng.state)}

func restore(data: Dictionary) -> void:
	for field in ["config","players","deck","bag","market_tiles","market_animals","removed_tiles","removed_animals","held","pending","active","optional_used","finished"]:
		set(field,data[field].duplicate(true) if data[field] is Array or data[field] is Dictionary else data[field])
	active = int(active)
	config.count = int(config.count)
	for player in players:
		player.nature = int(player.nature)
		player.turns = int(player.turns)
		for cell in player.board.values():
			for field in ["q","r","tile","rotation"]:
				cell[field] = int(cell[field])
	deck = deck.map(func(n):return int(n))
	market_tiles = market_tiles.map(func(n):return int(n))
	removed_tiles = removed_tiles.map(func(n):return int(n))
	if not pending.is_empty():
		for field in ["tile","tile_index","animal_index","rotation"]:
			pending[field] = int(pending[field])
		for field in ["tile_pos","animal_pos"]:
			if pending[field] != null:
				pending[field] = pending[field].map(func(n):return int(n))
	rng.state = int(data.rng_state)

func save_game(path: String = "user://autosave.json") -> Error:
	return preload("res://scripts/core/json_file.gd").write(path, snapshot())

func load_game(path: String = "user://autosave.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return false
	if data.get("version", 0) != SAVE_VERSION:
		last_notice = "存档不兼容"
		return false
	for field in ["config","players","deck","bag","market_tiles","market_animals","removed_tiles","removed_animals","held","pending","active","optional_used","finished","rng_state"]:
		if not data.has(field):
			return false
	restore(data)
	return true
