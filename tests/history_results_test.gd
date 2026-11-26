extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	var game = GameState.new()
	game.start({"count":4,"names":["潮线记录甲","潮线记录乙","潮线记录丙","潮线记录丁"]},34)
	var rank_changed = false
	while not game.finished:
		game.draft(0,0)
		game.place_tile(game.frontier()[0],game.players[game.active].turns%6)
		var legal = game.legal_animal_cells()
		if legal.is_empty(): game.discard_animal()
		else: game.place_animal(legal[0])
		game.commit_turn()
		if game.active == 0 or game.finished:
			var scores = Scorer.game_scores(game)
			for i in range(4):
				var entry = game.players[i].history.back()
				check(entry.round_total == scores[i].total,"All points reflect the same round boundary")
				rank_changed = rank_changed or entry.total != entry.round_total
	check(rank_changed,"Fixture includes a majority bonus changed by another player's turn")
	ui.game = game
	ui.reports = Scorer.game_scores(game)
	ui._render_game()
	ui.show_results()
	var review = ui.modal.get("review")
	check(review is Button and review.visible,"Finished results offer the history view")
	if review is Button:
		review.pressed.emit()
		await process_frame
		await process_frame
		var chart = ui.modal.find_child("ScoreHistory",true,false)
		check(chart != null and chart.players.size() == 4,"Button opens four score series")
		var boards = ui.modal.find_children("FinalBoard","Control",true,false)
		check(boards.size() == 4,"Final thumbnail per player")
		for i in range(boards.size()):
			var thumbnail = boards[i]
			check(thumbnail.cells.size() == 23,"Thumbnail includes every placed tile")
			check(thumbnail.best.delta == game.players[i].history.map(func(m):return m.delta).max(),"Summary highlights that player's highest gain")
			check(thumbnail.best.cell.size() == 2 and thumbnail.best.has("animal_cell"),"Best tile and animal location retained")
		check(Rect2(Vector2.ZERO,Vector2(1920,1080)).encloses(ui.modal.get_child(1).get_global_rect()),"Four-player charts and summaries fit")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
			root.get_texture().get_image().save_png("res://build/history-four.png")
	ui.queue_free()
	await process_frame
	print("HISTORY RESULTS: ",failures," failures")
	quit(0 if failures == 0 else 1)
