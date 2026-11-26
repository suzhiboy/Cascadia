extends SceneTree

var failures = 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	var settings_path = "user://settings.json"
	var old_settings = FileAccess.get_file_as_string(settings_path) if FileAccess.file_exists(settings_path) else ""
	check(ui.has_method("set_language"),"settings can switch language")
	if ui.has_method("set_language"):
		ui.show_settings()
		var picker = ui.modal.find_child("Language",true,false)
		check(picker is OptionButton,"Language selector exists in settings")
		picker.item_selected.emit(1)
		check(JSON.parse_string(FileAccess.get_file_as_string(settings_path)).language == "en","English preference persisted")
		check(TranslationServer.get_locale() == "en","English locale applied")
		check(TranslationServer.translate("潮痕群岛") == "Tidetrace Isles","English title in catalog")
		_check_english(ui.screen)
		ui._show_daily("2026-11-26")
		_check_english(ui.modal)
		ui._show_records()
		_check_english(ui.modal)
		ui.show_setup()
		_check_english(ui.modal)
		ui.show_help()
		_check_english(ui.modal)
		check(_contains(ui.modal,"Scoring glossary"),"English scoring glossary in the help page")
		for animal in TileDefinition.ANIMALS:
			for card in ["A","B","C","D"]:
				ui.show_card(animal,card)
				_check_english(ui.modal)
				check(not _has_han(ScoringCardDefinition.summary(animal,card)),"English sidebar summary for "+animal+card)
		ui.show_lan_lobby()
		_check_english(ui.modal)
		ui.show_card("goby","A")
		check(_contains(ui.modal,"mudskipper scores 1 point"),"English scoring description")
		ui._close_modal()
		ui._start_practice()
		ui.game.draft(0,0)
		var preview = load("res://scripts/ui/score_preview.gd").estimate(ui.game,ui.S.game_scores(ui.game))
		check(preview.details.begins_with("Preview"),"dynamic English preview")
		_check_english(ui.screen)
		ui.show_results()
		_check_english(ui.modal)
		ui._close_modal()
		var history = load("res://scripts/ui/modals/history_modal.gd").new()
		history.open(ui)
		_check_english(ui.modal)
		ui._close_modal()
		var snapshot = ui.game.snapshot()
		ui.set_language("zh_CN")
		check(TranslationServer.get_locale().begins_with("zh"),"Chinese locale restored")
		check(ui.game.snapshot() == snapshot,"switch preserves pending turn")
		ui.show_settings()
		check(_contains(ui.modal,"音效音量"),"Chinese settings labels restored")
	if old_settings.is_empty():
		if FileAccess.file_exists(settings_path): DirAccess.remove_absolute(settings_path)
	else:
		var file = FileAccess.open(settings_path,FileAccess.WRITE)
		file.store_string(old_settings)
		file.close()
	ui.music.stop()
	ui.music.stream = null
	ui.queue_free()
	await create_timer(0.5).timeout
	await process_frame
	print("LOCALIZATION: ",failures," failures")
	quit(0 if failures == 0 else 1)

func _contains(node: Node, phrase: String) -> bool:
	for child in node.get_children():
		if child is Label and phrase in child.text:
			return true
		if _contains(child,phrase):
			return true
	return false

func _check_english(node: Node) -> void:
	var visible_text = ""
	if node is Label or node is Button:
		visible_text = node.text
	visible_text += node.tooltip_text if node is Control else ""
	check(not _has_han(visible_text),"Untranslated English UI: " + visible_text)
	for child in node.get_children():
		_check_english(child)

func _has_han(value: String) -> bool:
	for i in value.length():
		var code = value.unicode_at(i)
		if code >= 0x3400 and code <= 0x9fff: return true
	return false
