extends SceneTree

const Diagram = preload("res://scripts/ui/rule_diagram.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		for animal in TileDefinition.ANIMALS:
			for card in ["A", "B", "C", "D"]:
				scene.show_card(animal, card)
				await process_frame
				await process_frame
				check_diagram(scene.modal, "%s %s @ %s" % [animal, card, resolution])
		scene.show_help()
		await process_frame
		await process_frame
		check_diagram(scene.modal, "help @ %s" % resolution)
		var diagram = scene.modal.find_child("RuleDiagram",true,false)
		if diagram != null:
			var first: Dictionary = diagram.example(false)
			var click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = diagram._layout(first,diagram._example_area(0)).centers["0,0"]
			var points: int = diagram._points(first)
			diagram._gui_input(click)
			check(diagram._points(diagram.example(false)) < points,"Removing a resident updates the example score")
			diagram._gui_input(click)
			check(diagram._points(diagram.example(false)) == points,"Clicking the same tile restores the resident")
	scene.queue_free()
	await process_frame
	print("RULE DIAGRAMS: 42 layouts and 40 score examples, %d failures" % failures)
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("FAIL: ",label)
		failures += 1

func check_diagram(modal: Control, label: String) -> void:
	var scroll: ScrollContainer = modal.find_children("*", "ScrollContainer", true, false)[0]
	for item in scroll.find_children("*", "Control", true, false):
		if item.get_script() == Diagram:
			var visible_rect := scroll.get_global_rect()
			if scroll.get_v_scroll_bar().visible:
				visible_rect.size.x -= scroll.get_v_scroll_bar().size.x
			if scroll.get_h_scroll_bar().visible:
				visible_rect.size.y -= scroll.get_h_scroll_bar().size.y
			if visible_rect.encloses(item.get_global_rect()):
				if not item.has_method("_example_area"):
					check(false,"Diagram fits tiles to the available frame: "+label)
					return
				var compact = Diagram.new()
				compact.animal = item.animal
				compact.card = item.card
				compact.compact = true
				compact.size = Vector2(146,90)
				var thumb: Rect2 = compact._example_area(0)
				check(thumb.end.y <= compact.size.y-23 and thumb.grow(.1).encloses(compact._layout(compact.example(false),thumb).bounds),"Thumbnail leaves room for its score: "+label)
				check(item._points(item.example(false)) > item._points(item.example(true)),"Thumbnail illustrates the stronger scoring pattern: "+label)
				for side in range(2):
					var area: Rect2 = item._example_area(side)
					var fitted: Rect2 = item._layout(item.example(side == 1),area).bounds
					var coverage = fitted.size/area.size
					check(area.grow(.1).encloses(fitted) and maxf(coverage.x,coverage.y) > .95,"Tiles fill one dimension without clipping: "+label)
				compact.free()
				return
			printerr("Clipped %s: %s within %s" % [label, item.get_global_rect(), visible_rect])
			failures += 1
			return
	printerr("Missing diagram: ", label)
	failures += 1
