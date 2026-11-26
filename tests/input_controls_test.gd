extends SceneTree

var ui
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",message)

func settle() -> void:
	for _i in range(4): await process_frame

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func pad(button: JoyButton) -> void:
	var event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func mouse(point: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event = InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT and pressed else 0
	root.push_input(event,true)

func move(point: Vector2, relative: Vector2, held: bool = false) -> void:
	if DisplayServer.get_name() != "headless": root.warp_mouse(point)
	var event = InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event,true)

func run() -> void:
	var initial_pointer = root.get_mouse_position()
	var had_save = FileAccess.file_exists("user://autosave.json")
	var previous = FileAccess.get_file_as_bytes("user://autosave.json") if had_save else PackedByteArray()
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	var first = root.gui_get_focus_owner()
	check(first != null and not first.focus_neighbor_bottom.is_empty(),"Menu provides an initial focus and directional neighbors")
	pad(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() != first,"D-pad navigates the menu")
	pad(JOY_BUTTON_DPAD_UP)
	pad(JOY_BUTTON_A)
	await settle()
	var modal_focus = root.gui_get_focus_owner()
	check(is_instance_valid(ui.modal) and modal_focus != null and ui.modal.is_ancestor_of(modal_focus),"A opens the focused menu option and gives the modal focus")
	pad(JOY_BUTTON_B)
	check(not is_instance_valid(ui.modal),"B closes the modal")
	ui.settings.animations = false
	ui._apply_comfort()
	ui.start_game({"count":1},23)
	await settle()
	if Input.get_connected_joypads().is_empty():
		check(ui.board_panel.keyboard_hints.visible,"Mouse and keyboard hints show with no controller")
		Input.joy_connection_changed.emit(0,true)
		check(ui.board_panel.gamepad_hints.visible and not ui.board_panel.keyboard_hints.visible,"Connecting a controller swaps the hints")
		Input.joy_connection_changed.emit(0,false)
		check(ui.board_panel.keyboard_hints.visible and not ui.board_panel.gamepad_hints.visible,"Disconnecting the last controller restores the hints")
	var original_pan = ui.board.pan
	var original_zoom = ui.board.zoom
	key(KEY_W)
	check(ui.board.pan.y > original_pan.y,"W pans the camera")
	key(KEY_LEFT)
	check(ui.board.pan.x > original_pan.x,"Left arrow pans with empty hands")
	key(KEY_PLUS)
	check(ui.board.zoom > original_zoom,"Plus zooms in")
	key(KEY_MINUS)
	key(KEY_HOME)
	check(ui.board.pan.is_equal_approx(original_pan) and is_equal_approx(ui.board.zoom,original_zoom),"Home frames the board")
	var sea = ui.board.global_position+Vector2(20,20)
	mouse(sea,MOUSE_BUTTON_LEFT,true)
	move(sea+Vector2(6,0),Vector2(6,0),true)
	check(ui.board.pan == original_pan,"Six pixels still count as a click")
	mouse(sea+Vector2(6,0),MOUSE_BUTTON_LEFT,false)
	mouse(sea,MOUSE_BUTTON_LEFT,true)
	move(sea+Vector2(18,0),Vector2(18,0),true)
	mouse(sea+Vector2(18,0),MOUSE_BUTTON_LEFT,false)
	check(ui.board.pan.x > original_pan.x,"Dragging on water pans the camera")
	key(KEY_F)

	key(KEY_1)
	check(ui.selection_tile == 0 and ui.selection_animal == 0,"Number key selects the market pair")
	key(KEY_ENTER)
	check(not ui.game.pending.is_empty(),"Enter drafts the selected pair")
	if not ui.game.pending.is_empty():
		var center = ui.board.global_position+ui.board.size*.5
		mouse(center,MOUSE_BUTTON_RIGHT,true)
		check(ui.game.pending.rotation == 1,"Right click rotates the held tile")
		var zoom = ui.board.zoom
		mouse(center,MOUSE_BUTTON_WHEEL_DOWN,true,true)
		check(ui.game.pending.rotation == 0 and ui.board.zoom == zoom,"Shift-wheel rotates without zooming")
		pad(JOY_BUTTON_RIGHT_SHOULDER)
		pad(JOY_BUTTON_LEFT_SHOULDER)
		check(ui.game.pending.rotation == 0,"Both shoulders rotate the held tile")
		pad(JOY_BUTTON_DPAD_UP)
		check(ui.board.hovered in ui.board.frontier,"D-pad selects a legal placement hex")
		var upper = ui.board.hovered
		pad(JOY_BUTTON_DPAD_DOWN)
		check(ui.board.hovered in ui.board.frontier and ui.board.hovered != upper,"D-pad moves to a different legal hex")
		pad(JOY_BUTTON_A)
		check(ui.game.pending.tile_pos != null,"A places at the board cursor")
		key(KEY_ESCAPE)
		check(ui.game.pending.tile_pos == null and not is_instance_valid(ui.modal),"Esc clears placement without opening a modal")
		key(KEY_RIGHT)
		check(ui.board.hovered in ui.board.frontier,"Keyboard arrows select legal hexes while holding a piece")
		pad(JOY_BUTTON_A)
		pad(JOY_BUTTON_B)
		check(ui.game.pending.tile_pos == null,"B uses the same undo as Esc")
		ui._board_click(ui.Practice.TARGET)
		if ui.game.legal_animal_cells().is_empty(): ui._action(ui._request_action("discard_animal"))
		else: pad(JOY_BUTTON_A)
		check(ui.game.ready_to_commit(),"Hand is ready after tile and animal actions")
		pad(JOY_BUTTON_START)
		check(ui.game.players[0].turns == 1,"Start commits the turn")

	ui.start_game({"count":1},23)
	await settle()
	var origin = ui.market_panel.rows[0].tile.get_global_rect().get_center()
	var target = ui.board.global_position+ui.board.screen_position(ui.Practice.TARGET)
	var before = ui.game.snapshot()
	move(origin,Vector2.ZERO)
	mouse(origin,MOUSE_BUTTON_LEFT,true)
	move(origin+Vector2(22,0),Vector2(22,0),true)
	move(sea,sea-origin-Vector2(22,0),true)
	check(root.gui_is_dragging() and not ui.board._can_drop_data(sea-ui.board.global_position,root.gui_get_drag_data()),"Market button starts native drag and water rejects the drop")
	mouse(sea,MOUSE_BUTTON_LEFT,false)
	check(ui.game.snapshot() == before,"Invalid market drop leaves the match unchanged")
	move(origin,origin-sea)
	mouse(origin,MOUSE_BUTTON_LEFT,true)
	move(origin+Vector2(22,0),Vector2(22,0),true)
	move(target,target-origin-Vector2(22,0),true)
	await settle()
	var data = root.gui_get_drag_data()
	var local_target = target-ui.board.global_position
	if DisplayServer.get_name() == "headless":
		check(ui.board._can_drop_data(local_target,data),"Board accepts the live market drag at a legal hex")
	check(ui.board.hovered == ui.Practice.TARGET and ui.board._ghost.visible,"Market drag previews in the existing board ghost")
	# Headless mouse injection leaves the system cursor stationary during native drops.
	if DisplayServer.get_name() == "headless": ui.board._drop_data(local_target,data)
	mouse(target,MOUSE_BUTTON_LEFT,false)
	check(ui.game.pending.get("tile_pos") == [0,-1] and ui.game.pending.get("tile_index") == 0,"Valid market drop drafts and places at the target")

	TranslationServer.set_locale("en")
	ui.start_game({"count":1},23)
	await settle()
	var body = ui.screen.get_child(1).get_child(0).get_child(1)
	check(body.get_global_rect().end.x <= 1920.5,"English controls fit beside both side panels")
	if DisplayServer.get_name() != "headless": root.warp_mouse(initial_pointer)
	if had_save:
		var file = FileAccess.open("user://autosave.json",FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autosave.json"))
	ui.queue_free()
	await process_frame
	print("INPUT CONTROLS: ",failures," failures")
	quit(0 if failures == 0 else 1)
