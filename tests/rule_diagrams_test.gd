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
	scene.queue_free()
	await process_frame
	print("RULE DIAGRAMS: 40 layouts, %d failures" % failures)
	quit(1 if failures else 0)

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
				return
			printerr("Clipped %s: %s within %s" % [label, item.get_global_rect(), visible_rect])
			failures += 1
			return
	printerr("Missing diagram: ", label)
	failures += 1
