extends Node

var scene
var failures = 0
var saved = ""
var had_save = false
var capture_dir = ""

func _ready() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func settle() -> void:
	for _i in range(5): await get_tree().process_frame

func button_named(node: Node, text: String):
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found = button_named(child,text)
		if found != null: return found
	return null

func press(text: String) -> void:
	var button = button_named(scene,text)
	verify(button != null, "Button exists: "+text)
	if button != null:
		verify(not button.disabled, "Button enabled: "+text)
		button.pressed.emit()
	await settle()

func capture(label: String) -> void:
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	var img = get_tree().root.get_texture().get_image()
	img.save_png(capture_dir+"/"+label+".png")
	print("CAPTURE ",label," ",img.get_size())

func layout() -> void:
	var outer = scene.screen.get_child(1)
	var content = outer.get_child(0)
	for control in [content,content.get_child(0),content.get_child(2)]:
		var rect = control.get_global_rect()
		verify(rect.end.x <= 1920.5 and rect.end.y <= 1080.5,"Layout stays inside design viewport: "+str(rect))

func click_practice_hex() -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = scene.board.screen_position(scene.Practice.TARGET)
	scene.board._gui_input(event)
	await settle()

func practice() -> void:
	await press("首回合练习")
	layout()
	await capture("practice-select")
	scene._market_pick(0,false)
	await settle()
	await press("确认选取")
	await capture("practice-rotate")
	await press("E ↷")
	await click_practice_hex()
	await capture("practice-animal")
	await click_practice_hex()
	layout()
	await press("完成回合")
	await press("查看练习得分")
	await capture("practice-score")
	verify(scene.game.players[0].turns == 1,"Practice finishes exactly one turn")
	await press("返回主菜单")
	verify(FileAccess.file_exists("user://autosave.json") == had_save,"Practice preserves save availability")
	if had_save:
		verify(FileAccess.get_file_as_string("user://autosave.json") == saved,"Practice preserves real save bytes")

func turn(index: int) -> void:
	scene._market_pick(index%4,false)
	await settle()
	await press("确认选取")
	await press("E ↷")
	if index == 0: await capture("pending-"+str(scene.game.players.size()))
	var p = scene.game.frontier()[0]
	scene.board.cell_clicked.emit(p)
	await settle()
	var legal = scene.game.legal_animal_cells()
	if legal.is_empty():
		await press("放归动物")
	else:
		scene.board.cell_clicked.emit(legal[0])
		await settle()
	layout()
	await press("完成回合")

func run() -> void:
	had_save = FileAccess.file_exists("user://autosave.json")
	if had_save: saved = FileAccess.get_file_as_string("user://autosave.json")
	capture_dir = OS.get_executable_path().get_base_dir()+"/screenshots" if OS.has_feature("template") else ProjectSettings.globalize_path("res://build/screenshots")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	scene = get_parent()
	await settle()
	await capture("menu")
	await practice()
	await press("开始新的旅程")
	await capture("setup")
	await press("登岛调查")
	layout()
	await capture("solo-start")
	await press("规则")
	await capture("help")
	await press("关闭")
	await press("设置")
	await capture("settings")
	await press("关闭")
	for i in range(20):
		await turn(i)
		if i == 0:
			var before = scene.game.snapshot()
			scene.show_menu()
			await settle()
			await press("继续上次旅程")
			verify(before == scene.game.snapshot(),"Resume keeps full state")
		if i == 9: await capture("solo-midgame")
	verify(scene.game.finished and scene.game.players[0].turns == 20,"Solo reaches scoring")
	await capture("solo-results")
	scene._highlight_score(0,"marsh",false)
	await settle()
	verify(not scene.highlight.is_empty(),"Habitat score highlights cells")
	await capture("solo-highlight")
	# Exercise long boards through the same navigation controls.
	var long_cells = {}
	for i in range(23):
		long_cells[str(i)+",0"] = {"q":i,"r":0,"tile":16,"rotation":0,"animal":""}
	scene.board.cells = long_cells
	await press("居中版图")
	for i in range(23):
		verify(Rect2(Vector2.ZERO,scene.board.size).has_point(scene.board.screen_position(Vector2i(i,0))),"Long board remains reachable")
	await capture("long-board")
	scene.start_game({"count":4,"names":["第一位名字很长的旅行者甲","第二位名字很长的旅行者乙","第三位名字很长的旅行者丙","第四位名字很长的旅行者丁"],"cards":{"limpet":"D","crab":"C","tern":"D","otter":"D","goby":"B"}})
	await settle()
	layout()
	await capture("four-start")
	verify(scene.board.pan.length()<200,"New game camera centered")
	for i in range(80):
		verify(scene.game.active == i%4,"Hotseat changes to next player")
		await turn(i)
		if i == 3:
			scene._view(2)
			await settle()
			verify(not scene.board.interactive,"Other board is read-only")
			await capture("four-switch")
			await press("返回当前玩家")
	verify(scene.game.finished,"Four players reach scoring")
	await capture("four-results")
	for p in scene.game.players: verify(p.turns == 20 and p.board.size() == 23,"Four-player final components")
	if had_save:
		var file = FileAccess.open("user://autosave.json",FileAccess.WRITE)
		file.store_string(saved)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autosave.json"))
	print("VISUAL PLAYTEST: ",failures," failures; practice + solo 20 + hotseat 80 turns")
	get_tree().quit(0 if failures == 0 else 1)
