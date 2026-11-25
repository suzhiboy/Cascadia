extends SceneTree

var failures := 0
var removed := 0
var added := 0
var tracking := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ",message)
		failures += 1

func run() -> void:
	var had_save = FileAccess.file_exists("user://autosave.json")
	var previous = FileAccess.get_file_as_bytes("user://autosave.json") if had_save else PackedByteArray()
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.start_game({"count":2},42)
	await process_frame
	await process_frame
	var original_screen = ui.screen.get_instance_id()
	var original_board = ui.board.get_instance_id()
	node_removed.connect(func(_node): if tracking: removed += 1)
	node_added.connect(func(_node): if tracking: added += 1)
	tracking = true
	ui.board.pan = Vector2(43,17)
	ui.board.zoom = .85
	ui._market_pick(0,false)
	ui._draft()
	ui._rotate(1)
	ui._board_click(ui.game.frontier()[0])
	var legal = ui.game.legal_animal_cells()
	if legal.is_empty(): ui._action(ui._request_action("discard_animal"))
	else: ui._board_click(legal[0])
	check(ui.game.ready_to_commit(),"Placement is complete")
	ui._commit()
	await process_frame
	check(ui.game.players[0].turns == 1,"Full turn committed")
	ui._view(0)
	check(ui.board.pan == Vector2(43,17) and ui.board.zoom == .85,"Returning to a player restores their camera")
	await create_timer(1.1).timeout
	tracking = false
	print("TURN UI: added=",added," removed=",removed)
	check(removed == 0 and added == 0,"Ordinary turn and toast expiry retain every UI node")
	check(ui.screen.get_instance_id() == original_screen and ui.board.get_instance_id() == original_board,"Screen and board persist")
	ui.show_results()
	var modal_id = ui.modal.get_instance_id()
	ui._on_lan_state_changed(ui.game.snapshot(),5)
	check(ui.modal.get_instance_id() == modal_id,"Live score modal survives LAN snapshot")
	if had_save:
		var file = FileAccess.open("user://autosave.json",FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autosave.json"))
	ui.queue_free()
	await process_frame
	print("UI PERSISTENCE: ",failures," failures")
	quit(0 if failures == 0 else 1)
