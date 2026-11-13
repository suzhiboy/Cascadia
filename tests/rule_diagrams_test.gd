extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.start_game({"count":1})
	for animal in ["bear","elk","salmon","hawk","fox"]:
		for card in ["A","B","C","D"]:
			scene.show_card(animal,card)
			await process_frame
			await process_frame
	scene.show_help()
	await process_frame
	print("RULE DIAGRAMS: 20 cards loaded")
	quit()
