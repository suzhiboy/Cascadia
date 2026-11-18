extends SceneTree
var failures = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/improvements-"+name+".png")
func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.settings.large_text = true
	ui.settings.animations = false
	ui._apply_comfort()
	ui.show_lan_lobby()
	ui.lan_session.host_lobby({"count":4,"port":37721})
	check(not ui.lan_session.host_start_game().is_empty(),"Unready lobby cannot start")
	await capture("lobby")
	check(ui.modal.get_child(1).get_global_rect().end.y <= 1080,"Large text lobby fits")
	ui.lan_session.shutdown()
	ui.lan_discovery.stop()
	ui.game = ui.G.new()
	ui.game.start({"count":2},42)
	ui._render_game()
	ui.game.draft(0,0)
	ui.game.place_tile(ui.game.frontier()[0],0)
	var before = ui.game.snapshot()
	var preview = load("res://scripts/ui/score_preview.gd").describe(ui.game)
	check(preview.contains("试摆预估"),"Preview is labelled")
	check(before == ui.game.snapshot(),"Preview preserves state and RNG")
	ui._render_game()
	await capture("preview")
	ui.show_card("bear","A")
	await process_frame
	var diagram = find_diagram(ui.modal)
	check(diagram != null,"Interactive diagram exists")
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	# Remove third bear from the comparison: three bears (0) become two bears (4).
	diagram.queue_redraw()
	await process_frame
	await process_frame
	if not diagram.hit_regions.is_empty():
		var hit = diagram.hit_regions[-1]
		event.position = hit.center
		diagram._gui_input(event)
		check(diagram.removed[1].size() == 1,"Click removes bear")
		var example = diagram.example(true)
		example[hit.key].animal = ""
		check(ui.S.wildlife(example,"bear","A").points == 4,"Removing third bear restores four points")
		diagram._gui_input(event)
		check(diagram.removed[1].is_empty(),"Click restores bear")
	ui.view_player = 1
	var old_modal = ui.modal
	ui._on_lan_state_changed(before,3)
	check(ui.view_player == 1,"Network snapshot preserves viewed player")
	check(ui.modal == old_modal,"Network snapshot preserves open card")
	await capture("rules")
	ui.show_settings()
	await capture("settings")
	check(ui.modal.get_child(1).get_global_rect().end.y <= 1080,"Settings fit")
	ui.queue_free()
	await process_frame
	print("IMPROVEMENTS: ",failures," failures")
	quit(0 if failures == 0 else 1)
func find_diagram(node: Node):
	if node.get_script() == load("res://scripts/ui/rule_diagram.gd"): return node
	for child in node.get_children():
		var found = find_diagram(child)
		if found != null: return found
	return null
