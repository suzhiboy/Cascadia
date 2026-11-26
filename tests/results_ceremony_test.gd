extends SceneTree

const Records = preload("res://scripts/core/field_records.gd")
const DATE = "2026-11-26"

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func survey(id: String, total: int) -> GameState:
	var game := GameState.new()
	game.start({"count":1,"survey_id":id,"daily":DATE},23)
	var cells = game.players[0].board.values()
	cells[0].animal = "crab"
	cells[1].animal = "limpet"
	game.players[0].nature = total-int(Scorer.game_scores(game)[0].total)
	game.finished = true
	return game

func run() -> void:
	var path := "user://ceremony-%d.json" % OS.get_process_id()
	var legacy = FileAccess.open(path,FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"completed":2,"best":{"1":80},"daily":{DATE:200},"cards":{},"recorded":{"legacy":true}}))
	legacy.close()
	var records = Records.new(path)
	var first = survey("first",60)
	check(records.record(first,Scorer.game_scores(first)) == OK,"Legacy field records accept a new result")
	var game = survey("second",150)
	var reports = Scorer.game_scores(game)
	check(records.record(game,reports) == OK,"The score that beats the legacy best is recorded")
	check(records.record(game,reports) == OK and records.read().completed == 4,"Recording the same survey keeps its original comparison")
	check(records.read().version == Records.VERSION,"Legacy records are saved with the comparison format version")
	check(records.read().daily[DATE] == 200,"An older, higher daily result survives migration")

	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.records = records
	ui.settings.animations = true
	ui._apply_comfort()
	ui.game = game
	ui.reports = reports
	ui._render_game()
	ui.show_results()
	var modal = ui.modal
	var crab = modal.find_child("CrabScore0",true,false)
	var limpet = modal.find_child("LimpetScore0",true,false)
	var total = modal.find_child("TotalScore0",true,false)
	var banner = modal.find_child("ResultBanner",true,false)
	var tween = modal.get("reveal")
	check(crab is Button and limpet is Button and total is Label and banner is Control and tween is Tween,"Finished scores have a timed category reveal")
	if tween is Tween and crab is Button and limpet is Button and total is Label and banner is Control:
		tween.pause()
		check(crab.text == "0" and limpet.text == "0" and total.text == "0","All counts start at zero")
		check(is_zero_approx(banner.modulate.a),"The result banner waits for the total")
		check(is_equal_approx(modal.get_child(0).color.a,1.0),"Board and sidebar totals cannot spoil the reveal through the scrim")
		tween.custom_step(.06)
		check(int(crab.text) > 0 and limpet.text == "0" and total.text == "0","First category rolls before the second and the total")
		tween.custom_step(.37)
		check(int(crab.text) == reports[0].wildlife.crab.points and int(limpet.text) == reports[0].wildlife.limpet.points and total.text == "0","Species settle while the total is still hidden")
		ui.settings.animations = false
		ui._apply_comfort()
		check(total.text == "150" and is_equal_approx(banner.modulate.a,1.0),"Disabling animation settles an in-progress reveal")
		check(modal.get_child(0).color.a < 1.0,"The board is visible behind the finished results")
	var best = modal.find_child("ResultComparison",true,false)
	var rating = modal.find_child("SoloRating",true,false)
	var record = modal.find_child("NewRecord",true,false)
	check(best is Label and "个人最佳 150 分（原 80）" in best.text and "上一局 60 分（+90）" in best.text,"Final scores compare the updated best and the preceding survey")
	check(best is Label and "本日最高 200 分" in best.text,"Daily results show the best attempt for the survey date")
	check(record is Label and record.visible and record.text == "新纪录","A strict personal best earns the record mark")
	check(rating is Control and rating.visible and rating.get("value") == 4,"A score above all four thresholds earns the top drawn badge")
	if rating is Control:
		var thresholds = [91,95,100,105]
		for i in range(thresholds.size()):
			check(modal.get_script().rating_for(thresholds[i]-1) == i and modal.get_script().rating_for(thresholds[i]) == i+1,"The measured cutoff starts the next rating at %d" % thresholds[i])
	ui._close_modal()
	ui.show_results()
	check(ui.modal.find_child("NewRecord",true,false) is Label and ui.modal.find_child("NewRecord",true,false).visible,"Reopening the same survey retains its record mark")

	var tied = survey("tied",150)
	check(records.record(tied,Scorer.game_scores(tied)) == OK,"A later tied result is saved")
	ui.game = tied
	ui.reports = Scorer.game_scores(tied)
	ui._render_game()
	ui.show_results()
	record = ui.modal.find_child("NewRecord",true,false)
	check(record is Label and not record.visible,"Matching a personal best does not announce a new record")

	var multi := GameState.new()
	multi.start({"count":4},23)
	multi.players[1].nature = 30
	multi.finished = true
	ui.game = multi
	ui.reports = Scorer.game_scores(multi)
	ui._render_game()
	ui.show_results()
	modal = ui.modal
	total = modal.find_child("TotalScore1",true,false)
	banner = modal.find_child("ResultBanner",true,false)
	check(total is Label and int(total.text) == Scorer.game_scores(multi)[1].total,"Reduced motion opens four-seat results with final scores")
	var winner = modal.find_child("ResultTitle",true,false)
	check(winner is Label and "旅行者 2" in winner.text and banner is Control and is_equal_approx(banner.modulate.a,1.0),"The visible winner banner names the winning traveller")
	await process_frame
	check(Rect2(Vector2.ZERO,Vector2(1920,1080)).encloses(modal.get_child(1).get_global_rect()),"Four-player results fit the design viewport")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ui.music.stop()
	ui.music.stream = null
	ui.queue_free()
	await process_frame
	print("RESULTS CEREMONY: ",failures," failures")
	quit(int(failures > 0))
