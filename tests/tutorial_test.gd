extends SceneTree

var failures = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found = find_button(child,title)
		if found != null: return found
	return null

func press(node: Node, title: String) -> bool:
	var button = find_button(node,title)
	check(button != null and not button.disabled,"Enabled button: "+title)
	if button == null or button.disabled: return false
	button.pressed.emit()
	return true

func run() -> void:
	var had_save = FileAccess.file_exists("user://autosave.json")
	var old_save = FileAccess.get_file_as_bytes("user://autosave.json") if had_save else PackedByteArray()
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var saved_game = scene.G.new()
	saved_game.start({"count":2,"names":["存档甲","存档乙"]},8)
	check(saved_game.save_game() == OK,"Create separate real save")
	var baseline = FileAccess.get_file_as_bytes("user://autosave.json")
	if press(scene,"首回合练习"):
		await play_lesson(scene,baseline)
	if had_save:
		var file = FileAccess.open("user://autosave.json",FileAccess.WRITE)
		file.store_buffer(old_save)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autosave.json"))
	scene.queue_free()
	await process_frame
	print("TUTORIAL: ",failures," failures")
	quit(0 if failures == 0 else 1)

func layout(scene: Node) -> void:
	await process_frame
	await process_frame
	var footer = scene.screen.get_child(1).get_child(0).get_child(2)
	check(footer.get_global_rect().end.y <= 1080.5,"Tutorial actions fit")

func play_lesson(scene: Node, baseline: PackedByteArray) -> void:
	await layout(scene)
	check(scene.game.players.size() == 1 and scene.game.players[0].turns == 0,"Practice starts on first turn")
	check(scene.board.zoom >= 0.9,"Practice opens with readable tiles")
	scene._market_pick(2,false)
	check(scene.selection_tile == -1,"Other market groups cannot advance practice")
	scene._market_pick(0,false)
	if not press(scene,"确认选取"): return
	check(scene.board.frontier == [Vector2i(1,0)],"Only the matching practice hex is highlighted")
	scene.board.cell_clicked.emit(Vector2i(1,0))
	check(scene.game.pending.tile_pos == null,"Rotate before placing")
	scene.board.cell_clicked.emit(Vector2i(0,-1))
	check(scene.game.pending.tile_pos == null,"Other legal hex does not advance the tutorial")
	var original_rotation = int(scene.game.pending.rotation)
	press(scene,"E ↷")
	check(int(scene.game.pending.rotation) == (original_rotation+1)%6,"Rotate using the real placement control")
	scene.board.cell_clicked.emit(Vector2i(1,0))
	check(scene.game.pending.tile_pos != null,"Tile step advances")
	check(scene.board.legal_animals == [Vector2i(1,0)],"Practice tile is the only highlighted animal target")
	check(find_button(scene,"放归动物").disabled,"Practice cannot bypass placement by releasing the animal")
	scene.board.cell_clicked.emit(Vector2i(1,0))
	check(scene.game.ready_to_commit(),"Animal step advances")
	press(scene,"撤回摆放")
	check(scene.game.pending.tile_pos == null and scene.board.frontier == [Vector2i(1,0)],"Undo rewinds the guide")
	scene.board.cell_clicked.emit(Vector2i(1,0))
	scene.board.cell_clicked.emit(Vector2i(1,0))
	scene.settings.large_text = true
	scene.settings.animations = false
	scene._apply_comfort()
	scene._render_game()
	await layout(scene)
	press(scene,"完成回合")
	check(scene.game.players[0].turns == 1,"Confirm commits exactly one turn")
	var score = scene.S.game_scores(scene.game)[0]
	check(score.habitats.wetland.points == scene._practice_start_score.habitats.wetland.points+1,"Connected wetland adds one point")
	check(score.wildlife.salmon.points == 2,"One salmon scores two points on card A")
	await layout(scene)
	check(find_button(scene,"确认选取").disabled and not scene.board.interactive,"Review cannot start a second turn")
	if press(scene,"查看练习得分"):
		await process_frame
		check(scene.modal.get_child(1).get_global_rect().end.y <= 1080,"Review modal fits")
		press(scene,"返回主菜单")
	check(FileAccess.get_file_as_bytes("user://autosave.json") == baseline,"Completing practice does not overwrite real save")
	if press(scene,"首回合练习"):
		press(scene,"退出练习")
		check(scene.board == null,"Exit practice returns to menu")
		check(FileAccess.get_file_as_bytes("user://autosave.json") == baseline,"Exiting practice does not overwrite real save")
	if press(scene,"继续上次旅程"):
		check(scene.game.players.size() == 2 and scene.game.players[0].name == "存档甲","Real save resumes unchanged")
