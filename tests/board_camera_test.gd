extends SceneTree

const H = preload("res://scripts/core/hex.gd")

var failures := 0
var ui

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func settle() -> void:
	for _i in range(4): await process_frame

func draft() -> void:
	ui._market_pick(0,false)
	ui._draft()

func place_north() -> void:
	var frontier = ui.game.frontier()
	frontier.sort_custom(func(a,b): return a.y < b.y)
	ui._board_click(frontier[0])
	ui._action(ui._request_action("discard_animal"))

func framed(frontier: Array) -> bool:
	var area = Rect2(Vector2.ZERO,ui.board.size).grow(-79.9)
	var extent = Vector2(sqrt(3.0)*.5,1.0)*ui.board.radius*ui.board.zoom
	var positions = frontier.duplicate()
	for key in ui.board.cells:
		positions.append(H.coord(key))
	for cell in positions:
		var center = ui.board.screen_position(cell)
		if not area.encloses(Rect2(center-extent,extent*2)):
			return false
	return true

func mouse_button(button: MouseButton, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = ui.board.size*.5
	ui.board._gui_input(event)

func run() -> void:
	var had_save = FileAccess.file_exists("user://autosave.json")
	var previous = FileAccess.get_file_as_bytes("user://autosave.json") if had_save else PackedByteArray()
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.settings.animations = false
	ui._apply_comfort()
	ui.start_game({"count":1},42)
	await settle()
	check(framed(ui.game.frontier()),"Opening camera includes cells and the next frontier")
	ui.board.pan += Vector2(0,900)
	draft()
	await settle()
	check(framed(ui.board.frontier),"Showing an out-of-frame frontier fits during the turn")
	for i in range(20):
		if i > 0:
			draft()
			await settle()
		check(not ui.board.frontier.is_empty() and framed(ui.board.frontier),"Turn %d shows every placement hex" % (i+1))
		place_north()
		ui._commit()
		await settle()
		check(framed(ui.game.frontier() if not ui.game.finished else []),"Turn %d ends with the full board and frontier in view" % (i+1))
	check(ui.game.finished and ui.board.cells.size() == 23,"Camera scenario plays all 20 turns")

	ui.settings.animations = true
	ui._apply_comfort()
	ui.start_game({"count":2},42)
	await settle()
	var opening = ui.board.zoom
	await create_timer(.43).timeout
	check(not is_equal_approx(opening,ui.board.zoom) and framed(ui.game.frontier()),"Opening fit eases to the framed view")
	draft()
	mouse_button(MOUSE_BUTTON_WHEEL_UP,true)
	mouse_button(MOUSE_BUTTON_MIDDLE,true)
	var drag = InputEventMouseMotion.new()
	drag.position = ui.board.size*.5
	drag.relative = Vector2(0,900)
	ui.board._gui_input(drag)
	mouse_button(MOUSE_BUTTON_MIDDLE,false)
	var manual = [ui.board.pan,ui.board.zoom]
	place_north()
	await create_timer(.43).timeout
	check([ui.board.pan,ui.board.zoom] == manual,"Manual zoom and drag survive placement in the same turn")
	ui._view(1)
	await create_timer(.43).timeout
	check(framed([]),"Switching to another island frames its cells")
	ui._view(0)
	await settle()
	check([ui.board.pan,ui.board.zoom] == manual,"Returning during the same turn restores its manual camera")
	ui._commit()
	await settle()
	ui.settings.animations = false
	ui._apply_comfort()
	check(framed(ui.game.frontier()),"Animation setting snaps an active camera fit to its target")
	ui._view(0)
	await settle()
	check(framed([]),"A new turn restores automatic fit for the previous seat")

	if had_save:
		var file = FileAccess.open("user://autosave.json",FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autosave.json"))
	ui.queue_free()
	await process_frame
	print("BOARD CAMERA: ",failures," failures")
	quit(0 if failures == 0 else 1)
