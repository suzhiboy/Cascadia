class_name Scorer
extends RefCounted

const H = preload("res://scripts/core/hex.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const B = preload("res://scripts/core/score_breakdown.gd")

static func _lookup(values: Array, count: int) -> int:
	return values[mini(count,values.size()-1)]

static func _animal_keys(board: Dictionary, animal: String) -> Array:
	var keys = board.keys().filter(func(k): return board[k].animal == animal)
	keys.sort()
	return keys

static func _groups(keys: Array) -> Array:
	var remaining = {}
	for k in keys:
		remaining[k] = true
	var result = []
	while not remaining.is_empty():
		var todo = [remaining.keys()[0]]
		var group = []
		remaining.erase(todo[0])
		while not todo.is_empty():
			var k = todo.pop_back()
			group.append(k)
			for p in H.neighbors(H.coord(k)):
				var nk = H.key(p)
				if remaining.has(nk):
					remaining.erase(nk)
					todo.append(nk)
		result.append(group)
	return result

static func wildlife(board: Dictionary, animal: String, card: String) -> Dictionary:
	var result = B.empty()
	var keys = _animal_keys(board,animal)
	var groups = _groups(keys)
	if animal == "bear":
		var pairs = []
		var sizes = {}
		for group in groups:
			var n = group.size()
			sizes[n] = true
			if card == "A" and n == 2:
				pairs.append_array(group)
			elif card == "B" and n == 3:
				B.add(result,group,10)
			elif card == "C" and n <= 3:
				B.add(result,group,[0,2,5,8][n])
			elif card == "D" and n >= 2 and n <= 4:
				B.add(result,group,[0,0,5,8,13][n])
		if card == "A":
			B.add(result,pairs,_lookup([0,4,11,19,27],pairs.size()/2))
		if card == "C" and sizes.has(1) and sizes.has(2) and sizes.has(3):
			B.add(result,keys,3,"三种熊群奖励")
	elif animal == "elk":
		if card == "C":
			for group in groups:
				B.add(result,group,_lookup([0,2,4,7,10,14,18,23,28],group.size()))
		else:
			var patterns = []
			if card == "A":
				for n in range(1,5):
					var shape = []
					for x in range(n):
						shape.append(Vector2i(x,0))
					patterns.append({"shape":shape,"points":[0,2,5,9,13][n]})
			elif card == "B":
				patterns = [{"shape":[Vector2i.ZERO],"points":2},{"shape":[Vector2i.ZERO,Vector2i(1,0)],"points":5},{"shape":[Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1)],"points":9},{"shape":[Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)],"points":13}]
			else:
				for n in range(1,7):
					patterns.append({"shape":H.DIRS.slice(0,n),"points":[0,2,5,8,12,16,21][n]})
			var candidates = []
			var seen = {}
			for pattern in patterns:
				for rotation in range(6):
					var shape = pattern.shape.map(func(p):return H.rotate(p,rotation))
					for k in keys:
						var anchor = H.coord(k)-shape[0]
						var cells = shape.map(func(p):return H.key(anchor+p))
						if cells.all(func(c):return c in keys):
							var mask = _mask(cells,keys)
							if not seen.has(mask):
								seen[mask] = true
								candidates.append({"mask":mask,"cells":cells,"points":pattern.points})
			result = _pack(keys,candidates)
	elif animal == "salmon":
		for group in groups:
			var valid = true
			for k in group:
				var degree = 0
				for p in H.neighbors(H.coord(k)):
					if H.key(p) in group:
						degree += 1
				if degree > 2:
					valid = false
			if not valid:
				continue
			var n = group.size()
			if card == "A":
				B.add(result,group,_lookup([0,2,5,8,12,16,20,25],n))
			elif card == "B":
				B.add(result,group,_lookup([0,2,4,9,11,17],n))
			elif card == "C":
				B.add(result,group,_lookup([0,0,0,10,12,15],n))
			elif n >= 3:
				var adjacent = _adjacent_animals(board,group)
				B.add(result,group+adjacent,n+adjacent.size())
	elif animal == "hawk":
		var lines = _sightlines(board,keys)
		if card in ["A","B"]:
			var eligible = []
			for k in keys:
				var isolated = true
				for p in H.neighbors(H.coord(k)):
					if H.key(p) in keys:
						isolated = false
				var visible = lines.any(func(line):return k in line.cells)
				if isolated and (card == "A" or visible):
					eligible.append(k)
			B.add(result,eligible,_lookup([0,2,5,8,11,14,18,22,26] if card == "A" else [0,0,5,9,12,16,20,24,28],eligible.size()))
		elif card == "C":
			for line in lines:
				B.add(result,line.cells,3)
		else:
			var candidates = []
			for line in lines:
				var types = {}
				for k in line.between:
					if board.has(k) and board[k].animal != "":
						types[board[k].animal] = true
				candidates.append({"mask":_mask(line.cells,keys),"cells":line.cells,"points":_lookup([0,4,7,9],types.size())})
			result = _pack(keys,candidates)
	elif animal == "fox":
		if card == "D":
			var candidates = []
			for i in range(keys.size()):
				for j in range(i+1,keys.size()):
					if H.coord(keys[j])-H.coord(keys[i]) in H.DIRS:
						var pair = [keys[i],keys[j]]
						var counts = _neighbor_counts(board,pair)
						counts.erase("fox")
						var n = counts.values().filter(func(v):return v>=2).size()
						candidates.append({"mask":_mask(pair,keys),"cells":pair,"points":_lookup([0,5,7,9,11],n)})
			result = _pack(keys,candidates)
		else:
			for k in keys:
				var counts = _neighbor_counts(board,[k])
				if card == "A":
					B.add(result,[k],counts.size())
				else:
					counts.erase("fox")
					if card == "B":
						var n = counts.values().filter(func(v):return v>=2).size()
						B.add(result,[k],_lookup([0,3,5,7],n))
					else:
						B.add(result,[k],0 if counts.is_empty() else counts.values().max())
	return result

static func _adjacent_animals(board: Dictionary, cells: Array) -> Array:
	var adjacent = {}
	for k in cells:
		for p in H.neighbors(H.coord(k)):
			var nk = H.key(p)
			if nk not in cells and board.has(nk) and board[nk].animal != "":
				adjacent[nk] = true
	return adjacent.keys()

static func _neighbor_counts(board: Dictionary, cells: Array) -> Dictionary:
	var counts = {}
	for k in _adjacent_animals(board,cells):
		var animal = board[k].animal
		counts[animal] = counts.get(animal,0)+1
	return counts

static func _sightlines(board: Dictionary, keys: Array) -> Array:
	var lines = []
	for i in range(keys.size()):
		for j in range(i+1,keys.size()):
			var a = H.coord(keys[i])
			var b = H.coord(keys[j])
			var delta = b-a
			for d in H.DIRS:
				var distance = maxi(absi(delta.x),absi(delta.y))
				if distance > 1 and d*distance == delta:
					var between = []
					var blocked = false
					for step in range(1,distance):
						var k = H.key(a+d*step)
						between.append(k)
						if board.has(k) and board[k].animal == "hawk":
							blocked = true
					if not blocked:
						lines.append({"cells":[keys[i],keys[j]],"between":between})
	return lines

static func _mask(cells: Array, keys: Array) -> int:
	var mask = 0
	for k in cells:
		mask |= 1 << keys.find(k)
	return mask

static func _pack(keys: Array, candidates: Array) -> Dictionary:
	var by_bit = []
	for _k in keys:
		by_bit.append([])
	for candidate in candidates:
		for i in range(keys.size()):
			if candidate.mask & (1 << i):
				by_bit[i].append(candidate)
	var memo = {0:0}
	var choices = {}
	var mask = (1 << keys.size())-1
	_pack_score(mask,by_bit,memo,choices)
	var result = B.empty()
	while mask != 0:
		var choice = choices[mask]
		if choice.has("cells"):
			B.add(result,choice.cells,choice.points)
		mask &= ~choice.mask
	return result

static func _pack_score(mask: int, by_bit: Array, memo: Dictionary, choices: Dictionary) -> int:
	if memo.has(mask):
		return memo[mask]
	var i = 0
	while not (mask & (1 << i)):
		i += 1
	var best = _pack_score(mask & ~(1 << i),by_bit,memo,choices)
	var choice = {"mask":1 << i}
	for candidate in by_bit[i]:
		if mask & candidate.mask == candidate.mask:
			var score = candidate.points+_pack_score(mask & ~candidate.mask,by_bit,memo,choices)
			if score > best:
				best = score
				choice = candidate
	memo[mask] = best
	choices[mask] = choice
	return best

static func habitats(board: Dictionary) -> Dictionary:
	var result = {}
	for habitat in T.HABITATS:
		var remaining = {}
		for k in board:
			if habitat in T.get_tile(int(board[k].tile)).habitats:
				remaining[k] = true
		var largest = []
		while not remaining.is_empty():
			var todo = [remaining.keys()[0]]
			var group = []
			remaining.erase(todo[0])
			while not todo.is_empty():
				var k = todo.pop_back()
				group.append(k)
				var cell = board[k]
				for d in range(6):
					var nk = H.key(H.coord(k)+H.DIRS[d])
					if not remaining.has(nk):
						continue
					var other = board[nk]
					if H.edge(T.get_tile(int(cell.tile)),int(cell.rotation),d) == habitat and H.edge(T.get_tile(int(other.tile)),int(other.rotation),(d+3)%6) == habitat:
						remaining.erase(nk)
						todo.append(nk)
			if group.size() > largest.size():
				largest = group
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
