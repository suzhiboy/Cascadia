extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func run() -> void:
	var had_save = FileAccess.file_exists("user://autosave.json")
	var saved = FileAccess.get_file_as_bytes("user://autosave.json") if had_save else PackedByteArray()
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.start_game({"count":1},ui.Practice.SEED)
	await process_frame
	await process_frame
	var effects = ui.screen.find_child("TurnEffects",true,false)
	check(effects != null,"Persistent noninteractive feedback layer exists")
	ui._market_pick(0,false)
	ui._draft()
	if effects != null:
		check(effects.flying_tile.visible and effects.flying_token.visible,"Draft flies both selected pieces")
		check(effects.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Draft never intercepts input")
	ui._board_click(ui.Practice.TARGET)
	var snapshot = ui.game.snapshot()
	var heat = ui.board.get("placement_points")
	check(heat is Dictionary and not heat.is_empty(),"Legal placements show score increments")
	if heat is Dictionary:
		for p in ui.game.legal_animal_cells():
			var placed = ui.G.new()
			placed.restore(snapshot)
			placed.place_animal(p)
			placed.commit_turn()
			var released = ui.G.new()
			released.restore(snapshot)
			released.discard_animal()
			released.commit_turn()
			var delta = ui.S.game_scores(placed)[0].total-ui.S.game_scores(released)[0].total
			check(heat.get(p) == delta,"Heat matches committed score difference at "+str(p))
	check(snapshot == ui.game.snapshot(),"Heat leaves match state unchanged")
	ui._board_click(ui.Practice.TARGET)
	ui._commit()
	if effects != null:
		check(effects.score_labels.any(func(label):return label.visible),"Turn commit shows score changes at board cells")
		check(ui.market_panel.rows[3].old_tile.visible,"Solo departure shows previous bottom tile")
	ui.settings.animations = false
	ui._apply_comfort()
	ui._market_pick(0,false)
	ui._draft()
	if effects != null:
		check(not effects.flying_tile.visible and not effects.flying_token.visible,"Reduced motion disables piece flights immediately")
	if had_save:
		var file = FileAccess.open("user://autosave.json",FileAccess.WRITE)
		file.store_buffer(saved)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autosave.json"))
	ui.queue_free()
	await process_frame
	print("TURN VISUALS: ",failures," failures")
	quit(0 if failures == 0 else 1)
