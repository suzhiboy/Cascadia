extends SceneTree

const Config = preload("res://scripts/core/game_config.gd")
var failures = 0
var slowest_usec = 0
var cross_pairs = 0
var scorer

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	var g = GameState.new()
	g.start({"count":3,"seats":["ai_easy","ai_standard","invalid"]},97)
	check(g.config.get("seats",[]) == ["ai_easy","ai_standard","human"],"Local setup normalizes each seat")
	var path = "res://scripts/ai/greedy_ai.gd"
	check(ResourceLoader.exists(path),"Computer player supplies legal turn plans")
	if ResourceLoader.exists(path):
		scorer = load(path)
		var first_snapshot = g.snapshot()
		var first = scorer.plan(g,"ai_easy")
		check(first == scorer.plan(g,"ai_easy") and first_snapshot == g.snapshot(),"Planning is deterministic and preserves state and RNG")
		for count in [1,2,3,4]:
			var played = GameState.new()
			played.start({"count":count,"cards":{"otter":"D","crab":"C","goby":"D","tern":"D","limpet":"B"}},76)
			if count == 2:
				played.start({"count":count,"cards":{"otter":"A","crab":"C","goby":"C","tern":"C","limpet":"D"}},76)
			var turns = 0
			while not played.finished and turns < count*20:
				if not play(played,"ai_standard" if turns%2 else "ai_easy"): break
				turns += 1
			check(played.finished and turns == count*20,"All %d seats can play to completion" % count)
		print("AI max decision ",slowest_usec/1000.0," ms; cross-pairs ",cross_pairs)
		check(slowest_usec < 50000,"Each measured full decision completes in under 50 ms")
	print("AI: ",failures," failures")
	quit(1 if failures else 0)

func play(game: GameState, level: String) -> bool:
	var seat = game.active
	var marker_count = game.players[seat].nature
	var t = Time.get_ticks_usec()
	var plan = scorer.plan(game,level)
	slowest_usec = maxi(slowest_usec,Time.get_ticks_usec()-t)
	var actions = scorer.actions(game,plan)
	check(actions.size() == 4,"Full plan contains four legal game actions")
	if plan.is_empty(): return false
	if plan.tile_index != plan.animal_index: cross_pairs += 1
	for entry in actions:
		var error = game.apply_action(entry.action,entry.args)
		check(error.is_empty(),"Computer action %s legal: %s" % [entry.action,error])
		if not error.is_empty(): return false
		if entry.action == "place_tile":
			var resumed = GameState.new()
			resumed.restore(game.snapshot())
			var continuation = scorer.actions(resumed,scorer.plan(resumed,level))
			check(continuation.size() == 2 and continuation.back().action == "commit_turn","Placed tile resumes at animal and commit")
	check(Scorer.game_scores(game)[seat].total == plan.points+marker_count,"Cached card gains agree with the committed full score")
	return true
