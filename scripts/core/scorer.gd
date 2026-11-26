class_name Scorer
extends RefCounted

const H = preload("res://scripts/core/hex.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const B = preload("res://scripts/core/score_breakdown.gd")
const Cards = preload("res://scripts/core/scoring_card_definition.gd")

static func _terrain(board: Dictionary, key: String) -> Array:
	return T.get_tile(int(board[key].tile)).habitats

static func _edge(board: Dictionary, key: String, direction: int) -> String:
	var cell = board[key]
	return H.edge(T.get_tile(int(cell.tile)),int(cell.rotation),direction)

# Missing board positions are represented by an empty string, preserving compass order.
static func _ring(board: Dictionary, key: String) -> Array:
	var ring = []
	for p in H.neighbors(H.coord(key)):
		var neighbor = H.key(p)
		ring.append(neighbor if board.has(neighbor) else "")
	return ring

static func _run_edges(ring: Array, length: int, on_board: bool) -> Array:
	var edges = []
	for d in range(6):
		var run = []
		for i in range(length):
			var side = (d+i)%6
			if (ring[side] != "") != on_board: break
			run.append(side)
		if run.size() == length:
			for side in run:
				if side not in edges: edges.append(side)
	return edges

# Optional terrain restricts passage to edges of the same habitat on both tiles.
static func _components(board: Dictionary, keys: Array, terrain: String = "") -> Array:
	var remaining = {}
	for key in keys:
		remaining[key] = true
	var components = []
	while not remaining.is_empty():
		var todo = [remaining.keys()[0]]
		remaining.erase(todo[0])
		var component = []
		while not todo.is_empty():
			var key = todo.pop_back()
			component.append(key)
			var p = H.coord(key)
			for d in range(6):
				var neighbor = H.key(p + H.DIRS[d])
				if not remaining.has(neighbor):
					continue
				if terrain != "" and (_edge(board,key,d) != terrain or _edge(board,neighbor,(d+3)%6) != terrain):
					continue
				remaining.erase(neighbor)
				todo.append(neighbor)
		components.append(component)
	return components

static func _habitat_components(board: Dictionary, terrain: String) -> Array:
	var eligible = board.keys().filter(func(key): return terrain in _terrain(board,key))
	return _components(board,eligible,terrain)

static func _crab_fringe(board: Dictionary, colony: Array) -> Dictionary:
	var edges = {}
	for key in colony:
		var ring = _ring(board,key)
		for d in range(6):
			var neighbor = ring[d]
			if neighbor != "" and neighbor not in colony:
				_mark_edge(edges,neighbor,(d+3)%6)
	return edges

static func _crab_colonies(board: Dictionary, keys: Array, card: String, result: Dictionary) -> void:
	for colony in _components(board,keys):
		var resources = {}
		var fringe = _crab_fringe(board,colony)
		for neighbor in fringe:
			if card == "C" and board[neighbor].animal == "":
				resources[neighbor] = true
			elif card == "D":
				for side in fringe[neighbor]:
					resources[_edge(board,neighbor,side)] = true
		var resource_points = 3 if card == "C" else 1
		B.add(result,colony,colony.size()+resource_points*mini(resources.size(),2*colony.size()),Cards.title("crab",card))

static func _limpet_samples(board: Dictionary, keys: Array, result: Dictionary) -> void:
	var samples = {}
	for key in keys:
		var terrain = _terrain(board,key).duplicate()
		terrain.sort()
		samples["+".join(terrain)] = true
	B.add(result,keys,keys.size()+samples.size(),Cards.title("limpet","D"))

static func _tern_landings(board: Dictionary, keys: Array, result: Dictionary) -> void:
	var destinations = {}
	for key in keys:
		var p = H.coord(key)
		for side in _tern_paths(board,key,_ring(board,key),true):
			destinations[H.key(p+2*H.DIRS[side])] = true
	B.add(result,keys,keys.size()+mini(destinations.size(),2*keys.size()),Cards.title("tern","D"))

static func _otter_patrol(board: Dictionary, keys: Array, result: Dictionary) -> void:
	var visited = {}
	for key in keys:
		B.add(result,[key],1,Cards.title("otter","D"))
		visited[key] = true
		for neighbor in _ring(board,key):
			if neighbor != "":
				visited[neighbor] = true
	for pool in _habitat_components(board,"pool"):
		if pool.any(func(key): return visited.has(key)):
			B.add(result,pool,mini(3,pool.size()),"巡护潮池")

static func _tern_sees_fish(board: Dictionary, neighbors: Array) -> bool:
	for neighbor in neighbors:
		if board[neighbor].animal == "goby":
			return true
		for other in _ring(board,neighbor):
			if other != "" and board[other].animal == "goby":
				return true
	return false

static func _open_edges(ring: Array) -> Array:
	return range(6).filter(func(d): return ring[d] == "")

static func _opposite_edges(board: Dictionary, ring: Array, crossing: bool) -> Array:
	var edges = []
	for d in range(3):
		if ring[d] == "" or ring[d+3] == "": continue
		if crossing:
			var a = _terrain(board,ring[d])
			var b = _terrain(board,ring[d+3])
			if not (("mudflat" in a and "pool" in b) or ("pool" in a and "mudflat" in b)): continue
		edges.append_array([d,d+3])
	return edges

static func _matching_edges(board: Dictionary, key: String, ring: Array) -> Array:
	return range(6).filter(func(d): return ring[d] != "" and _edge(board,key,d) == _edge(board,ring[d],(d+3)%6))

static func _tern_paths(board: Dictionary, key: String, ring: Array, landing: bool) -> Array:
	var p = H.coord(key)
	var edges = []
	for d in range(6):
		if ring[d] == "": continue
		var target = H.key(p+2*H.DIRS[d])
		if not board.has(target):
			if not landing: edges.append(d)
		elif landing:
			var terrains = _terrain(board,target)
			if "shingle" in terrains or "marsh" in terrains: edges.append(d)
	return edges

static func _mark_edge(marks: Dictionary, key: String, side: int) -> void:
	if not marks.has(key): marks[key] = []
	if side not in marks[key]: marks[key].append(side)

static func _patrol_edges(board: Dictionary, key: String, ring: Array, marks: Dictionary) -> void:
	for pool in _habitat_components(board,"pool"):
		if not pool.has(key) and not ring.any(func(other): return other in pool): continue
		for d in range(6):
			if ring[d] in pool and key not in pool:
				_mark_edge(marks,key,d)
		for member in pool:
			var neighbors = _ring(board,member)
			for d in range(6):
				if neighbors[d] in pool and _edge(board,member,d) == "pool" and _edge(board,neighbors[d],(d+3)%6) == "pool":
					_mark_edge(marks,member,d)

# Return every qualifying edge, including interchangeable edges for capped bonuses.
static func wildlife_edges(board: Dictionary, key: String, card: String) -> Dictionary:
	var animal = board.get(key,{}).get("animal","")
	if animal == "": return {}
	var ring = _ring(board,key)
	var marks = {}
	match animal + card:
		"crabB":
			for d in _open_edges(ring): _mark_edge(marks,key,d)
		"crabD":
			var keys = board.keys().filter(func(other): return board[other].animal == "crab")
			for colony in _components(board,keys):
				if key in colony:
					marks = _crab_fringe(board,colony)
					break
		"limpetB", "gobyD":
			for d in _opposite_edges(board,ring,animal == "goby"): _mark_edge(marks,key,d)
		"limpetC":
			for d in _matching_edges(board,key,ring):
				_mark_edge(marks,key,d)
				_mark_edge(marks,ring[d],(d+3)%6)
		"ternA", "otterB":
			var occupied = animal == "otter"
			for d in _run_edges(ring,3 if occupied else 2,occupied): _mark_edge(marks,key,d)
		"ternB", "ternD":
			var landing = card == "D"
			for d in _tern_paths(board,key,ring,landing):
				_mark_edge(marks,key,d)
				_mark_edge(marks,ring[d],d)
				if landing: _mark_edge(marks,H.key(H.coord(key)+2*H.DIRS[d]),(d+3)%6)
		"otterD":
			_patrol_edges(board,key,ring,marks)
	for edges in marks.values(): edges.sort()
	return marks

static func _local_points(board: Dictionary, key: String, animal: String, card: String) -> int:
	var home = _terrain(board,key)
	var ring = _ring(board,key)
	var neighbors = ring.filter(func(k): return k != "")
	match animal + card:
		"crabA":
			return 2 + int("mudflat" in home)
		"crabB":
			return 1 + ceili(_open_edges(ring).size()/2.0)
		"limpetA":
			var reefs = int("reef" in home)
			for neighbor in neighbors:
				reefs += int("reef" in _terrain(board,neighbor))
			return 1 + mini(reefs,2)
		"limpetB":
			return 1 + (_opposite_edges(board,ring,false).size() >> 1)
		"limpetC":
			return 1 if _matching_edges(board,key,ring).is_empty() else 3
		"ternA":
			return 1 if _run_edges(ring,2,false).is_empty() else 3
		"ternB":
			return 1 + mini(_tern_paths(board,key,ring,false).size(),2)
		"ternC":
			return 3 if _tern_sees_fish(board,neighbors) else 1
		"gobyA":
			return 3 if "mudflat" in home or "pool" in home else 1
		"gobyB":
			var transitions = 0
			for neighbor in neighbors:
				var other = _terrain(board,neighbor)
				if not home.any(func(h): return h in other):
					transitions += 1
			return 1 + mini(transitions,2)
		"gobyC":
			var habitats_seen = {}
			for cell in neighbors + [key]:
				for h in _terrain(board,cell):
					habitats_seen[h] = true
			return 3 if habitats_seen.has("pool") and habitats_seen.has("mudflat") else 1
		"gobyD":
			return 2 + _opposite_edges(board,ring,true).size()
		"otterA":
			var foods = {}
			for neighbor in neighbors:
				var resident = board[neighbor].animal
				if resident in ["crab","limpet","goby"]:
					foods[resident] = true
			return 1 + foods.size()
		"otterB":
			return 1 if _run_edges(ring,3,true).is_empty() else 3
		"otterC":
			for neighbor in neighbors:
				var terrain = _terrain(board,neighbor)
				if board[neighbor].animal == "" and ("shingle" in terrain or "reef" in terrain):
					return 5
			return 1
	return 0

static func wildlife(board: Dictionary, animal: String, card: String) -> Dictionary:
	var result = B.empty()
	var keys = board.keys().filter(func(k): return board[k].animal == animal)
	keys.sort()
	if keys.is_empty() or not Cards.DETAILS.has(animal) or not Cards.DETAILS[animal].has(card):
		return result
	match animal + card:
		"crabC", "crabD":
			_crab_colonies(board,keys,card,result)
		"limpetD":
			_limpet_samples(board,keys,result)
		"ternD":
			_tern_landings(board,keys,result)
		"otterD":
			_otter_patrol(board,keys,result)
		_:
			for key in keys:
				B.add(result,[key],_local_points(board,key,animal,card),Cards.title(animal,card))
	return result

static func habitats(board: Dictionary) -> Dictionary:
	var result = {}
	for habitat in T.HABITATS:
		var largest = []
		for component in _habitat_components(board,habitat):
			if component.size() > largest.size():
				largest = component
		result[habitat] = {"points":largest.size(),"cells":largest,"bonus":0}
	return result

static func majority(sizes: Array) -> Array:
	if sizes.size() == 1:
		return [2 if sizes[0] >= 7 else 0]
	var maximum = sizes.max()
	var first_count = sizes.count(maximum)
	var output = []
	var second = -1
	for n in sizes:
		if n < maximum:
			second = maxi(second,n)
	for n in sizes:
		if sizes.size() == 2:
			output.append((2 if first_count == 1 else 1) if n == maximum else 0)
		elif n == maximum:
			output.append(3 if first_count == 1 else (2 if first_count == 2 else 1))
		else:
			output.append(1 if first_count == 1 and n == second and sizes.count(second) == 1 else 0)
	return output

static func player_score(board: Dictionary, nature: int, cards: Dictionary) -> Dictionary:
	var report = {"wildlife":{},"habitats":habitats(board),"nature":nature,"total":nature}
	for animal in T.ANIMALS:
		report.wildlife[animal] = wildlife(board,animal,cards[animal])
		report.total += report.wildlife[animal].points
	for habitat in T.HABITATS:
		report.total += report.habitats[habitat].points
	return report

static func game_scores(game) -> Array:
	var reports = []
	for player in game.players:
		reports.append(player_score(player.board,player.nature,game.config.cards))
	for habitat in T.HABITATS:
		var bonuses = majority(reports.map(func(r):return r.habitats[habitat].points))
		for i in range(reports.size()):
			reports[i].habitats[habitat].bonus = bonuses[i]
			reports[i].total += bonuses[i]
	return reports

static func winners(game, reports: Array) -> Array:
	var top = reports.map(func(r):return r.total).max()
	var winners_list = []
	var cones = -1
	for i in range(reports.size()):
		if reports[i].total == top:
			cones = maxi(cones,int(game.players[i].nature))
	for i in range(reports.size()):
		if reports[i].total == top and game.players[i].nature == cones:
			winners_list.append(i)
	return winners_list
