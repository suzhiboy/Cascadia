extends SceneTree
var failures = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.game = ui.G.new()
	ui.game.start({"count":2},42)
	ui._render_game()
	ui.game.players[0].nature = 2
	ui.game.refresh([0],true)
	var snapshot = ui.game.snapshot()
	ui._render_game()
	check(is_instance_valid(ui._feedback_toast),"Refresh feedback appears")
	var toast = ui._feedback_toast
	ui._render_game()
	check(ui._feedback_toast == toast,"Redraw does not duplicate feedback")
	await create_timer(0.35).timeout
	for token in ui._market_tokens: check(is_equal_approx(token.modulate.a,1.0),"Tokens settle to full opacity")
	check(snapshot == ui.game.snapshot(),"Animation preserves state and RNG")
	ui.game.draft(0,0)
	ui.game.place_tile(ui.game.frontier()[0],0)
	ui.game.discard_animal()
	ui.game.commit_turn()
	ui._render_game()
	check(ui._feedback_toast.text.contains("回合完成"),"Turn feedback appears")
	ui.show_results()
	var panel = ui.modal.get_child(1)
	await create_timer(0.6).timeout
	check(is_equal_approx(panel.modulate.a,1.0),"Score panel settles")
	if DisplayServer.get_name() != "headless":
		await process_frame
		get_root().get_texture().get_image().save_png("res://build/feedback-score.png")
	ui._close_modal()
	# Destroy animated controls mid-tween: must not call freed instances.
	ui.show_results()
	ui._close_modal()
	await create_timer(0.6).timeout
	check(not is_instance_valid(ui._feedback_toast),"Turn toast cleans up")
	print("FEEDBACK TEST: ",failures," failures")
	quit(0 if failures == 0 else 1)
