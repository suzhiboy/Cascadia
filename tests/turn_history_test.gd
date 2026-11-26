extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func finish_move(game: GameState) -> void:
	game.place_tile(game.frontier()[0],2)
	game.discard_animal()
	game.commit_turn()

func _initialize() -> void:
	var game := GameState.new()
	game.start({"count":2},34)
	game.players[0].nature = 4
	var baseline: Array = Scorer.game_scores(game)
	game.refresh([0],true)
	game.refresh([2],true)
	game.draft(0,1)
	var restored := GameState.new()
	restored.restore(JSON.parse_string(JSON.stringify(game.snapshot())))
	finish_move(restored)
	var first: Array = restored.players[0].get("history",[])
	check(first.size() == 1,"Full turn records one survey")
	if first.is_empty():
		quit(1)
		return
	var entry: Dictionary = first[0]
	var reports: Array = Scorer.game_scores(restored)
	check(entry.total == reports[0].total,"Acting player's total uses current majority bonuses")
	check(entry.delta == reports[0].total-baseline[0].total,"Two market refreshes and split draft count against the full-turn gain")
	check(entry.cell.size() == 2 and entry.rotation == 2 and entry.animal_cell == null,"Recorded move includes location, rotation and release")
	check(restored.players[1].history.is_empty(),"No invented opponent move")
	restored.draft(1,1)
	finish_move(restored)
	for i in range(2):
		check(restored.players[i].history[0].get("round_total") == Scorer.game_scores(restored)[i].total,"Round-end rank reflected for seat "+str(i))
	var peer := GameState.new()
	peer.restore(JSON.parse_string(JSON.stringify(restored.snapshot())))
	check(peer.snapshot() == restored.snapshot(),"JSON save and LAN snapshot round trip includes all history")
	var legacy = restored.snapshot()
	legacy.erase("turn_nature_spent")
	for player in legacy.players: player.erase("history")
	peer.restore(legacy)
	check(peer.players[0].get("history") == [],"Missing history resumes without fabricated turns")
	peer.draft(0,0)
	finish_move(peer)
	check(peer.players[0].history.size() == 1 and peer.players[0].history[0].turn == 2,"Old game resumes tracking from the correct turn number")
	check(peer.players[0].history[0].delta == null,"An old partial turn with unknown spending cannot claim a best move")
	print("TURN HISTORY: ",failures," failures")
	quit(0 if failures == 0 else 1)
