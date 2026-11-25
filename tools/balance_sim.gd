extends SceneTree

const Game = preload("res://scripts/core/game_state.gd")
const Tiles = preload("res://scripts/core/tile_definition.gd")
const Score = preload("res://scripts/core/scorer.gd")
const CARDS = ["A","B","C","D"]
const FIRST_SEED = 917337
const SAMPLE_SIZE = 2000

func _initialize() -> void:
	var sums = {}
	var squares = {}
	var policy = RandomNumberGenerator.new()
	for animal in Tiles.ANIMALS:
		sums[animal] = [0,0,0,0]
		squares[animal] = [0,0,0,0]
	for i in range(SAMPLE_SIZE):
		var game = Game.new()
		game.start({"count":1},FIRST_SEED+i)
		policy.seed = (FIRST_SEED+i)*17
		while not game.finished:
			if not _play_turn(game,policy):
				printerr("Illegal action with seed ",FIRST_SEED+i)
				quit(1)
				return
		assert(game.players[0].turns == 20)
		for animal in Tiles.ANIMALS:
			for j in range(CARDS.size()):
				var value = Score.wildlife(game.players[0].board,animal,CARDS[j]).points
				sums[animal][j] += value
				squares[animal][j] += value*value
	var balanced = true
	print("species,card,n,mean,population_variance")
	for animal in Tiles.ANIMALS:
		var means = []
		for j in range(CARDS.size()):
			var mean_value = float(sums[animal][j])/SAMPLE_SIZE
			means.append(mean_value)
			var variance = float(squares[animal][j])/SAMPLE_SIZE-mean_value*mean_value
			print("%s,%s,%d,%.4f,%.4f" % [animal,CARDS[j],SAMPLE_SIZE,mean_value,variance])
		if means.min() <= 0 or means.max() > means.min()*1.30:
			balanced = false
			printerr("Mean spread exceeds 30% for ",animal)
	print("Seeds %d–%d. %d completed solo games. Pairwise mean limit passed: %s" % [FIRST_SEED,FIRST_SEED+SAMPLE_SIZE-1,SAMPLE_SIZE,balanced])
	quit(0 if balanced else 1)

func _play_turn(game, policy: RandomNumberGenerator) -> bool:
	var slot = policy.randi_range(0,3)
	if not game.draft(slot,slot).is_empty():
		return false
	var frontier = game.frontier()
	var target = frontier[policy.randi_range(0,frontier.size()-1)]
	if not game.place_tile(target,policy.randi_range(0,5)).is_empty():
		return false
	var legal = game.legal_animal_cells()
	if legal.is_empty():
		game.discard_animal()
	elif not game.place_animal(legal[policy.randi_range(0,legal.size()-1)]).is_empty():
		return false
	return game.commit_turn().is_empty()
