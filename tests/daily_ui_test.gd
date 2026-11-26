extends SceneTree

var failures = 0
func expect(ok: bool,msg: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",msg)

func _initialize() -> void:
	run.call_deferred()

func button(root_node: Node,text: String):
	for node in root_node.find_children("*","Button",true,false):
		if node.text == text: return node
	return null

func run() -> void:
	var old = {}
	for path in ["user://autosave.json","user://daily-ui-test.json"]:
		if FileAccess.file_exists(path): old[path] = FileAccess.get_file_as_bytes(path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	var daily = button(ui,"每日挑战")
	expect(daily != null,"Main menu offers daily survey")
	expect(button(ui,"调查记录") != null,"Main menu offers statistics")
	if daily != null:
		ui.records = load("res://scripts/core/field_records.gd").new("user://daily-ui-test.json")
		ui._show_daily("2026-11-25")
		button(ui.modal,"开始挑战").pressed.emit()
		var first = ui.game.snapshot()
		ui._show_daily("2026-11-25")
		button(ui.modal,"开始挑战").pressed.emit()
		var second = ui.game.snapshot()
		expect(first.config.survey_id != second.config.survey_id,"Each attempt has a unique record ID")
		first.config.erase("survey_id")
		second.config.erase("survey_id")
		expect(first == second,"Date reproduces full market, card draw, deck, RNG and starter")
		expect(first.config.daily == "2026-11-25" and first.config.count == 1,"Daily date survives setup")
		for i in range(20):
			ui.game.draft(0,0)
			ui.game.place_tile(ui.game.frontier()[0],0)
			ui.game.discard_animal()
			ui._commit()
		expect(ui.records.read().completed == 1,"Completing the daily writes one record")
		var local_best = ui.records.read().daily.get("2026-11-25",-1)
		expect(local_best == ui.reports[0].total,"Daily best reflects the scored board")
		ui.show_menu()
		ui._continue_game()
		expect(ui.records.read().completed == 1,"Resuming a finished game retains one record")
		ui.show_menu()
		button(ui,"调查记录").pressed.emit()
		expect(ui.modal.find_child("CardMeans",true,false) != null,"Statistics show per-card observations")
	for path in ["user://autosave.json","user://daily-ui-test.json"]:
		if old.has(path):
			var f = FileAccess.open(path,FileAccess.WRITE)
			f.store_buffer(old[path])
			f.close()
		else: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ui.queue_free()
	await process_frame
	print("DAILY UI: ",failures," failures")
	quit(1 if failures else 0)
