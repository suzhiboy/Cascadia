extends SceneTree

var failures = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var had_save = FileAccess.file_exists("user://autosave.json")
	var saved = FileAccess.get_file_as_string("user://autosave.json") if had_save else ""
	if not ResourceLoader.exists("res://scenes/main.tscn"):
		printerr("FAIL: main scene missing")
		quit(1)
		return
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.get_node_or_null("Screen") != null, "Menu exists")
	var ts = TextServerManager.get_primary_interface()
	var coords = ts.font_get_variation_coordinates(scene.theme.default_font.get_rids()[0])
	print("FONT AXES: ",coords)
	check(coords.get(ts.name_to_tag("wght"),100) >= 400,"Readable Chinese font weight")
	scene.start_game({"count":1,"names":["测试旅行者"],"cards":{}})
	await process_frame
	check(scene.board != null, "Board exists")
	check(scene.game.players.size() == 1, "Game initialized")
	await process_frame
	var outer = scene.screen.get_child(1)
	var bottom = outer.get_child(0).get_child(2)
	print("LAYOUT: bottom=",bottom.get_global_rect().end.y," design height=1080")
	check(bottom.get_global_rect().end.y <= 1080, "Action bar must fit inside viewport")
	scene._market_pick(0,false)
	scene._draft()
	await process_frame
	await process_frame
	outer = scene.screen.get_child(1)
	bottom = outer.get_child(0).get_child(2)
	print("PENDING LAYOUT: ",bottom.get_global_rect())
	check(bottom.get_global_rect().end.y <= 1080, "Pending action bar fits")
	var before = scene.game.snapshot()
	scene.show_menu()
	scene._rotate(1)
	check(scene.game.snapshot() == before and scene.board == null,"Menu Q/E does not change or resume game")
	scene._render_game()
	scene.board.pan = Vector2(999,999)
	scene.start_game({"count":4,"names":["第一位名字很长的旅行者甲","第二位名字很长的旅行者乙","第三位名字很长的旅行者丙","第四位名字很长的旅行者丁"],"cards":{}})
	await process_frame
	await process_frame
	outer = scene.screen.get_child(1)
	var header = outer.get_child(0).get_child(0)
	print("FOUR PLAYER HEADER: ",header.get_global_rect())
	check(header.get_global_rect().end.x <= 1920, "Four player names fit")
	check(scene.board.pan.length() < 200,"New game resets camera")
	scene._view(2)
	await process_frame
	scene.board.pan = Vector2(999,999)
	scene._market_pick(0,false)
	check(scene.view_player == scene.game.active,"Market selection returns to the active player immediately")
	await create_timer(.43).timeout
	check(scene.board.pan.length()<200,"Market selection fits the active camera after easing")
	scene.reports = scene.S.game_scores(scene.game)
	scene.show_results()
	await process_frame
	await process_frame
	var result_panel = scene.modal.get_child(1)
	print("RESULTS: ",result_panel.get_global_rect())
	check(result_panel.get_global_rect().end.y <= 1080,"Scoring modal fits screen")
	check(result_panel.get_global_rect().end.x <= 1920,"Long names fit scoring modal")
	scene.highlight = ["99,99"]
	scene.show_menu()
	scene._continue_game()
	check(scene.highlight.is_empty(),"Resume clears previous score highlights")
	if had_save:
		var file = FileAccess.open("user://autosave.json",FileAccess.WRITE)
		file.store_string(saved)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autosave.json"))
	scene.queue_free()
	await process_frame
	print("UI SMOKE: ",failures," failures")
	quit(0 if failures == 0 else 1)
