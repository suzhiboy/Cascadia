extends SceneTree

func _initialize() -> void:
	var game := GameState.new()
	game.start({"count": 1}, 13)
	var before = game.snapshot()
	var legacy = before.duplicate(true)
	legacy.version = 1
	var path := "user://legacy-fixture.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var rejected := not game.load_game(path)
	var unchanged: bool = before == game.snapshot()
	var message: bool = game.last_notice == "存档不兼容"
	DirAccess.remove_absolute(path)
	var ok: bool = rejected and unchanged and message and before.version == 2
	print("SAVE COMPATIBILITY: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
