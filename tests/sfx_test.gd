extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var source = load("res://scripts/ui/sound.gd").new()
	if not source.has_method("play") or source is AudioStreamPlayer:
		printerr("FAIL: dedicated sound dispatcher missing")
		source.free()
		quit(1)
		return
	root.add_child(source)
	var unique := {}
	for kind in ["tile_place","token_place","rotate","refresh","turn_end","game_end","ui_click","error"]:
		source.play(kind)
		var player: AudioStreamPlayer = source.get_node("Player")
		if not player.playing or player.stream == null:
			printerr("FAIL: no sound for ", kind)
			quit(1)
			return
		unique[player.stream.resource_path] = true
	print("SFX: %d distinct clips" % unique.size())
	quit(0 if unique.size() == 8 else 1)
