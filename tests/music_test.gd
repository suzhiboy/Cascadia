extends SceneTree
var failures = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	check(ui.music.playing and ui.music.stream.get_length()>1,"Music starts with valid audio")
	var music = ui.music
	var stream = music.stream
	ui.show_setup()
	ui.show_menu()
	check(ui.music == music and music.stream == stream and music.playing,"Navigation keeps same playback")
	ui.settings.volume = 0.0
	ui.settings.music_volume = 0.42
	ui._apply_audio()
	check(is_zero_approx(db_to_linear(ui.sound.volume_db)),"SFX muted")
	check(is_equal_approx(db_to_linear(music.volume_db),0.42),"Music independent")
	ui.settings.large_text = true
	ui.show_settings()
	await process_frame
	await process_frame
	var slider = ui.modal.find_child("MusicVolume",true,false)
	check(slider != null,"Music slider exists")
	slider.value = 0
	check(is_zero_approx(db_to_linear(music.volume_db)),"Music slider mutes")
	slider.value = 0.42
	ui.settings.music_volume = 0.9
	ui._load_settings()
	check(is_equal_approx(ui.settings.music_volume,0.42),"Music volume persists")
	check(ui.modal.get_child(1).get_global_rect().end.y <= 1080,"Large text settings fit")
	for expected_index in range(1,music.TRACKS.size()) + [0]:
		music.seek(music.stream.get_length()-0.05)
		await create_timer(0.4).timeout
		check(not music.playing and not music.gap_timer.is_stopped(),"Track ends in silent interval")
		var old_index = music.track_index
		ui.show_menu()
		await create_timer(9.0).timeout
		check(not music.playing and music.track_index == old_index,"Still silent before ten seconds, menu does not skip interval")
		await create_timer(1.2).timeout
		check(music.playing and music.track_index == expected_index,"Next track starts after ten seconds, including wraparound")
		check(music.stream.get_length()>1,"Next track has valid audio")
		if expected_index == 1: check(music.stream.resource_name == "雨幕鸦语","New track title")
		if expected_index == 2: check(music.stream.resource_name == "Crow Calls over Rain（混音）","Third track title")
	print("MUSIC: ",failures," failures; duration=",music.stream.get_length())
	ui.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
