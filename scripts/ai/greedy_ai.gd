extends RefCounted

const Score = preload("res://scripts/core/scorer.gd")
const Tiles = preload("res://scripts/core/tile_definition.gd")
const H = preload("res://scripts/core/hex.gd")
const LAND_FINALISTS = 2
const EASY_CHOICES = 4

# The only random draw uses a private generator so hints, saves and retries cannot
# alter the deck or the plan. The returned values are ordinary GameState inputs.
static func plan(game: GameState, level: String) -> Dictionary:
	if game.finished: return {}
	var player = game.players[game.active]
	var pending = game.pending
	var board = player.board.duplicate(true)
	var frontier = game.frontier()
	var edges = _neighbor_edges(board,frontier)
	var rivals = []
	for i in range(game.players.size()):
		if i != game.active: rivals.append(Score.habitats(game.players[i].board))
	var ranked = []
	var tile_options = [int(pending.tile_index)] if not pending.is_empty() else range(game.market_tiles.size())
	for t in tile_options:
		var id = int(pending.tile) if not pending.is_empty() else int(game.market_tiles[t])
		var spots = _tile_spots(id,pending,frontier,edges)
		for spot in spots:
			var pos = Vector2i(spot.q,spot.r)
			var key = H.key(pos)
			board[key] = {"q":pos.x,"r":pos.y,"tile":id,"rotation":spot.rotation,"animal":""}
			var land_points = _land_points(board,rivals)
			var base = {}
			var wildlife = 0
			for species in Tiles.ANIMALS:
				base[species] = Score.wildlife(board,species,game.config.cards[species]).points
				wildlife += base[species]
			var gains = {}
			var animal_options = [int(pending.animal_index)] if not pending.is_empty() else range(game.market_animals.size())
			for a in animal_options:
				var cost = int(t != a and pending.is_empty())
				if cost > player.nature: continue
				var species = str(pending.animal) if not pending.is_empty() else str(game.market_animals[a])
				var fixed = not pending.is_empty() and (pending.animal_pos != null or pending.discarded)
				var targets = []
				if fixed:
					targets.append("" if pending.discarded else H.key(Vector2i(pending.animal_pos[0],pending.animal_pos[1])))
				else:
					for k in board:
						if board[k].animal == "" and species in Tiles.get_tile(board[k].tile).wildlife:
							targets.append(k)
					targets.append("") # Releasing the animal is always a legal option.
				for target in targets:
					var placement = [species,target]
					if target != "" and not gains.has(placement):
						board[target].animal = species
						var gain = Score.wildlife(board,species,game.config.cards[species]).points-base[species]
						if game.config.cards.otter == "A" and species in ["goby","limpet","crab"]:
							gain += Score.wildlife(board,"otter","A").points-base.otter
						gains[placement] = gain+int(Tiles.keystone(board[target].tile))
						board[target].animal = ""
					var points = land_points+wildlife+gains.get(placement,0)-cost
					ranked.append({"tile_index":t,"animal_index":a,"q":pos.x,"r":pos.y,"rotation":spot.rotation,"animal_key":target,"points":points,"cost":cost,"order":ranked.size()})
			board.erase(key)
	ranked.sort_custom(func(a,b):
		if a.points != b.points: return a.points > b.points
		if a.cost != b.cost: return a.cost < b.cost
		return a.order < b.order)
	if ranked.is_empty(): return {}
	var pick = 0
	if level == "ai_easy":
		var dice = RandomNumberGenerator.new()
		dice.seed = game.rng.state ^ (game.active*101+int(player.turns))
		pick = dice.randi_range(0,mini(EASY_CHOICES,ranked.size())-1)
	return ranked[pick]

# First pass visits every free edge position and every distinct orientation.
# Rank by matching seams, then by contact count. Re-score two distinct sites per
# market tile using the complete species cards, area sizes and majority bonuses.
static func _neighbor_edges(board: Dictionary, frontier: Array) -> Dictionary:
	var edges = {}
	for p in frontier:
		var ring = []
		for d in range(6):
			var neighbor = H.key(p+H.DIRS[d])
			if board.has(neighbor):
				var c = board[neighbor]
				ring.append(H.edge(Tiles.get_tile(c.tile),c.rotation,(d+3)%6))
			else: ring.append("")
		edges[p] = ring
	return edges

static func _tile_spots(id: int, pending: Dictionary, frontier: Array, edges: Dictionary) -> Array:
	if not pending.is_empty() and pending.tile_pos != null:
		return [{"q":pending.tile_pos[0],"r":pending.tile_pos[1],"rotation":int(pending.rotation)}]
	var tile = Tiles.get_tile(id)
	var rotations = 1 if tile.habitats.size() == 1 else 6
	var faces = []
	for rotation in range(rotations):
		var face = []
		for d in range(6): face.append(H.edge(tile,rotation,d))
		faces.append(face)
	var sites = []
	for pos in frontier:
		var ring = edges[pos]
		var contact = 6-ring.count("")
		var best = -1
		var rotation = 0
		for rot in range(rotations):
			var matched = 0
			for d in range(6):
				matched += int(faces[rot][d] == ring[d])
			if matched > best:
				best = matched
				rotation = rot
		sites.append({"q":pos.x,"r":pos.y,"rotation":rotation,"rank":best*8+contact,"order":sites.size()})
	sites.sort_custom(func(a,b):return a.rank > b.rank if a.rank != b.rank else a.order < b.order)
	return sites.slice(0,LAND_FINALISTS)

static func _land_points(board: Dictionary, rivals: Array) -> int:
	var land = Score.habitats(board)
	var total = 0
	for h in land:
		var sizes = [land[h].points]
		for rival in rivals: sizes.append(rival[h].points)
		total += int(land[h].points)+int(Score.majority(sizes)[0])
	return total

static func actions(game: GameState, choice: Dictionary) -> Array:
	if choice.is_empty(): return []
	var pending = game.pending
	var steps = []
	if pending.is_empty():
		steps.append({"action":"draft","args":{"tile_index":choice.tile_index,"animal_index":choice.animal_index}})
	if pending.is_empty() or pending.tile_pos == null:
		steps.append({"action":"place_tile","args":{"q":choice.q,"r":choice.r,"rotation":choice.rotation}})
	if pending.is_empty() or (pending.animal_pos == null and not pending.discarded):
		if choice.animal_key == "":
			steps.append({"action":"discard_animal","args":{}})
		else:
			var p = H.coord(choice.animal_key)
			steps.append({"action":"place_animal","args":{"q":p.x,"r":p.y}})
	steps.append({"action":"commit_turn","args":{}})
	return steps
