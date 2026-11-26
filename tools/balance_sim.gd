extends SceneTree

const Game = preload("res://scripts/core/game_state.gd")
const Tiles = preload("res://scripts/core/tile_definition.gd")
const Score = preload("res://scripts/core/scorer.gd")
const AI = preload("res://scripts/ai/greedy_ai.gd")
const CARDS = ["A","B","C","D"]
const FIRST_SEED = 917337
const SAMPLE_SIZE = 2000
const GREEDY_SAMPLE_SIZE = 1024
const RATING_SAMPLE_SIZE = 512

func _initialize() -> void:
	if "--solo-rating" in OS.get_cmdline_user_args():
		_simulate_rating()
		return
	var greedy = "--greedy" in OS.get_cmdline_user_args()
	var first_seed = FIRST_SEED
	var samples = GREEDY_SAMPLE_SIZE if greedy else SAMPLE_SIZE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): first_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--games="): samples = int(arg.trim_prefix("--games="))
	if samples < 4 or samples%4 != 0:
		printerr("Game count must be a positive multiple of four")
		quit(1)
		return
	var values = {}
	var deals = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = first_seed
	var policy = RandomNumberGenerator.new()
	var peak = 0
	for animal in Tiles.ANIMALS: values[animal] = {"A":[],"B":[],"C":[],"D":[]}
	for i in range(samples):
		var cards = {}
		for animal in Tiles.ANIMALS:
			if i%4 == 0:
				var letters = CARDS.duplicate()
				for j in range(3,0,-1):
					var k = rng.randi_range(0,j)
					var temp = letters[k]
					letters[k] = letters[j]
					letters[j] = temp
				deals[animal] = letters
			cards[animal] = deals[animal][i%4]
		var game = Game.new()
		game.start({"count":1,"cards":cards},first_seed+i)
		policy.seed = (first_seed+i)*17
		while not game.finished:
			if greedy:
				var start = Time.get_ticks_usec()
				var plan = AI.plan(game,"ai_standard")
				peak = maxi(peak,Time.get_ticks_usec()-start)
				if not _apply_plan(game,plan):
					quit(1)
					return
			elif not _play_turn(game,policy):
				printerr("Illegal random turn with seed ",first_seed+i)
				quit(1)
				return
		for animal in Tiles.ANIMALS:
			for letter in ([cards[animal]] if greedy else CARDS):
				values[animal][letter].append(Score.wildlife(game.players[0].board,animal,letter).points)
	var balanced = true
	print("species,card,n,mean,p10,p90")
	for animal in Tiles.ANIMALS:
		var means = []
		for letter in CARDS:
			var scores = values[animal][letter]
			scores.sort()
			var mean_value = float(scores.reduce(func(a,b): return a+b,0))/scores.size()
			means.append(mean_value)
			print("%s,%s,%d,%.4f,%d,%d" % [animal,letter,scores.size(),mean_value,scores[ceili(scores.size()*.1)-1],scores[ceili(scores.size()*.9)-1]])
		var ratio = means.max()/means.min() if means.min() > 0 else INF
		print("ratio %s %.4f" % [animal,ratio])
		if greedy and ratio > 1.25: balanced = false
	print("games=%d max_decision_ms=%.3f passed=%s" % [samples,peak/1000.0,balanced])
	quit(0 if balanced else 1)

func _apply_plan(game, plan: Dictionary) -> bool:
	var actions = AI.actions(game,plan)
	if actions.is_empty(): return false
	for step in actions:
		var error = game.apply_action(step.action,step.args)
		if not error.is_empty():
			printerr(error)
			return false
	return true

func _simulate_rating() -> void:
	var cards = {}
	for animal in Tiles.ANIMALS: cards[animal] = "random"
	var totals: Array[int] = []
	var frequency = {}
	for seed_value in range(FIRST_SEED,FIRST_SEED+RATING_SAMPLE_SIZE):
		var game = Game.new()
		game.start({"count":1,"cards":cards},seed_value)
		while not game.finished:
			if not _apply_plan(game,AI.plan(game,"ai_standard")):
				printerr("No greedy move with seed ",seed_value)
				quit(1)
				return
		assert(game.players[0].turns == 20)
		var score = int(Score.game_scores(game)[0].total)
		totals.append(score)
		frequency[score] = frequency.get(score,0)+1
	totals.sort()
	print("Greedy solo: %d games, seeds %d–%d, range %d–%d" % [totals.size(),FIRST_SEED,FIRST_SEED+totals.size()-1,totals.front(),totals.back()])
	for percentile in [25,50,75,90]:
		print("P%d %d" % [percentile,totals[ceili(totals.size()*percentile/100.0)-1]])
	print("score,games")
	for score in range(totals.front(),totals.back()+1):
		if frequency.has(score): print("%d,%d" % [score,frequency[score]])
	quit()

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
