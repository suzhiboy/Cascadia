extends SceneTree

const TARGET = Vector2i(0,-1)

var ui
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func draft_turn() -> void:
	ui._market_pick(0,false)
	ui._draft()
	ui._rotate(1)

func run() -> void:
	var save_path = "user://autosave.json"
	var had_save = FileAccess.file_exists(save_path)
	var save_bytes = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.settings.animations = true
	ui._apply_comfort()
	ui.start_game({"count":1},ui.Practice.SEED)
	await process_frame
	draft_turn()
	var snapshot = ui.game.snapshot()
	ui.board._set_hover(TARGET)
	var badge = ui.board.find_child("ScorePreview",true,false)
	check(badge is Label and badge.visible and badge.text == "+1","Tile ghost forecasts the aligned habitat gain")
	if badge is Label:
		var before_pan = badge.position
		ui.board.pan_by(Vector2(30,0))
		await process_frame
		check(is_equal_approx(badge.position.x-before_pan.x,30),"Preview follows the ghost when the camera pans")
		ui.board._set_hover(ui.board.NO_CELL)
		check(not badge.visible,"Leaving the legal ghost hides its forecast")
		ui.board._set_hover(TARGET)
		check(ui.board.tooltip_text.contains("试摆预估"),"Returning to the same ghost restores the tooltip")
	check(ui.game.snapshot() == snapshot,"Ghost forecast leaves the pending hand and RNG untouched")
	ui._board_click(TARGET)
	ui.board._set_hover(TARGET)
	if badge is Label:
		check(badge.visible and badge.text == "+4","Animal ghost forecasts the habitat, wildlife and keystone points")
	ui._board_click(TARGET)
	ui._commit()
	var effects = ui.turn_effects
	var total = ui.screen.find_child("TurnTotal",true,false)
	check(total is Label and total.visible and total.text == "+0","Turn total starts at zero next to the progress trail")
	var shown = func(): return effects.score_labels.filter(func(label): return label.visible)
	check(shown.call().size() == 1,"The first score popup appears immediately")
	var popup = effects.score_labels[0]
	var plate = popup.get_theme_stylebox("normal")
	check(popup.get_theme_font_size("font_size") in [28,29,30] and plate is StyleBoxFlat and plate.bg_color == ui.P.ANIMALS.goby and plate.corner_radius_top_left > 0,"Wildlife popup has a large species-coloured plate")
	check(ui.board.get("turn_highlight") == ["0,0","0,-1"] or ui.board.get("turn_highlight") == ["0,-1","0,0"],"Growth outlines the cells of the new largest component")
	check(ui._toast_label.text.contains("泥滩连片 1 → 2"),"Growth states the habitat and both sizes")
	check(ui._toast_label.size.y < 112.0,"The first growth toast fits two lines without covering the island")
	if effects.score_tween:
		effects.score_tween.pause()
		effects.score_tween.custom_step(.079)
		check(shown.call().size() == 1,"Second popup waits for the stagger")
		effects.score_tween.custom_step(.003)
		check(shown.call().size() == 2,"Second popup appears at the 0.08 second interval")
		effects.score_tween.custom_step(.43)
		if total is Label: check(total.text == "+4","Turn total rolls to the committed delta")
		effects.score_tween.custom_step(.71)
		check(shown.call().is_empty(),"The popup sequence clears after about 1.2 seconds")
	await create_timer(1.05).timeout
	check(ui.board.get("turn_highlight") == [],"Growth outline clears after about a second")

	ui.settings.animations = false
	ui._apply_comfort()
	ui.start_game({"count":1},ui.Practice.SEED)
	await process_frame
	draft_turn()
	ui._board_click(TARGET)
	ui._board_click(TARGET)
	ui._commit()
	total = ui.screen.find_child("TurnTotal",true,false)
	check(total is Label and total.visible and total.text == "+4","Reduced motion displays the final total immediately")
	check(not ui.turn_effects.score_labels.any(func(label): return label.visible),"Reduced motion has no floating score tween")
	check(ui.board.get("turn_highlight") != [] and ui.board.get("turn_highlight_pulse") == 1.0,"Reduced motion shows a steady habitat outline")

	ui.start_game({"count":2},ui.Practice.SEED)
	var scores = ui.S.game_scores(ui.game)
	ui.game.players[0].nature = maxi(0,scores[1].total-scores[0].total-1)
	ui.game.players[1].nature = scores[0].total+ui.game.players[0].nature-scores[1].total+1
	ui._build_game_screen()
	ui.refresh()
	draft_turn()
	ui._board_click(TARGET)
	if ui.game.legal_animal_cells().is_empty(): ui._action(ui._request_action("discard_animal"))
	else: ui._board_click(ui.game.legal_animal_cells()[0])
	ui._commit()
	check(ui._toast_label.text.contains("旅行者 1 升至第 1"),"Overtaking another traveller is reported through the existing toast")
	check(ui._toast_label.text.contains("旅行者 2 降至第 2"),"Falling behind is reported in the same toast")
	check(ui._toast_label.position.y > ui.board.get_global_rect().position.y,"Ranking toast stays below the turn caption")
	check(ui.board_panel.turn_total.text.begins_with("上回合 +"),"Hotseat identifies the outgoing player's gain")
	check(ui.board.get("turn_highlight") == [],"Hotseat feedback leaves the incoming island free of the outgoing outline")
	if had_save:
		var file = FileAccess.open(save_path,FileAccess.WRITE)
		file.store_buffer(save_bytes)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	ui.music.stop()
	ui.music.stream = null
	ui.queue_free()
	await process_frame
	print("TURN FEEDBACK: ",failures," failures")
	quit(0 if failures == 0 else 1)
