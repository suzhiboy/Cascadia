extends SceneTree

var failures = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var path = "user://autosave.json"
	var saved = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.show_setup()
	var seat = ui.modal.find_child("Seat1",true,false)
	check(seat != null,"Setup offers difficulty per seat")
	if seat:
		check(seat.item_count == 3 and seat.selected == 0,"Seat defaults to human and offers both computer levels")
	ui._close_modal()
	ui.settings.fast_ai = true
	ui.start_game({"count":2,"seats":["ai_standard","human"]},113)
	check(not ui.board.interactive,"Human cannot place components for the computer")
	ui._market_pick(0,false)
	check(ui.selection_tile == -1,"Market cannot select for computer")
	ui.show_settings()
	var before = ui.game.snapshot()
	await create_timer(.25).timeout
	check(ui.game.snapshot() == before,"Settings pauses playback")
	ui._close_modal()
	ui._view(1)
	await create_timer(.65).timeout
	check(ui.game.active == 1 and ui.game.players[0].turns == 1,"Computer finishes its turn without stealing another board")
	check(ui.view_player == 1 and ui.board.interactive,"Next human gets control")
	ui.start_game({"count":2,"seats":["ai_easy","human"]},114)
	ui.game.apply_action("draft",{"tile_index":1,"animal_index":1})
	var target = ui.game.frontier()[0]
	ui.game.place_tile(target,3)
	ui.game.save_game()
	ui.show_menu()
	ui._continue_game()
	await create_timer(.65).timeout
	check(ui.game.active == 1 and ui.game.players[0].turns == 1,"Resumed partial easy turn completes once")
	if saved.size() > 0:
		var file = FileAccess.open(path,FileAccess.WRITE)
		file.store_buffer(saved)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ui.queue_free()
	await process_frame
	print("AI UI: ",failures," failures")
	quit(1 if failures else 0)
