extends SceneTree

func _initialize() -> void:
	var game := GameState.new()
	game.start({"count":1},13)
	var before = game.snapshot()
	var path := "user://legacy-fixture.json"
	var ok = before.version == 3
	for version in [1,2]:
		var legacy = before.duplicate(true)
		legacy.version = version
		var bytes = JSON.stringify(legacy)
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(bytes)
		file.close()
		var rejected = not game.load_game(path)
		ok = rejected and game.snapshot() == before and game.last_notice == "存档不兼容" and ok
		ok = FileAccess.get_file_as_string(path) == bytes and ok
	DirAccess.remove_absolute(path)
	print("SAVE COMPATIBILITY: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
