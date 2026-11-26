extends "res://scripts/ui/modals/modal.gd"

func open(controller) -> void:
	var body = controller._open_modal(GameLocale.text("旅途设置"),800,900,self)
	set_meta("comfort",true)
	var language_row = ui._hbox(12)
	language_row.add_child(ui._heading(GameLocale.text("界面语言"),22,P.DARK,620))
	var languages = OptionButton.new()
	languages.name = "Language"
	languages.add_item("简体中文")
	languages.add_item("English")
	languages.select(1 if ui.settings.language == "en" else 0)
	languages.item_selected.connect(func(index): ui.set_language("en" if index == 1 else "zh_CN"))
	language_row.add_child(languages)
	body.add_child(language_row)
	body.add_child(ui._heading(GameLocale.text("音效音量"),22,P.DARK,620))
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = .05
	slider.value = ui.settings.volume
	slider.custom_minimum_size.y = 45
	slider.value_changed.connect(func(value):
		ui.settings.volume=value
		ui._apply_audio()
		ui._save_settings())
	body.add_child(slider)
	body.add_child(ui._heading(GameLocale.text("背景音乐音量"),22,P.DARK,620))
	var music_slider = HSlider.new()
	music_slider.name = "MusicVolume"
	music_slider.min_value = 0
	music_slider.max_value = 1
	music_slider.step = .01
	music_slider.value = ui.settings.music_volume
	music_slider.custom_minimum_size.y = 45
	music_slider.tooltip_text = GameLocale.text("只调节背景音乐；拖至最左侧静音。")
	music_slider.value_changed.connect(func(value):
		ui.settings.music_volume = value
		ui._apply_audio()
		ui._save_settings())
	body.add_child(music_slider)
	var toggle = CheckButton.new()
	toggle.text = GameLocale.text("全屏显示")
	toggle.button_pressed = ui.settings.fullscreen
	toggle.toggled.connect(func(value):
		ui.settings.fullscreen=value
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		ui._save_settings())
	body.add_child(toggle)
	for option in [["fast_ai",GameLocale.text("快进电脑回合")],["animations",GameLocale.text("轻量动画")],["large_text",GameLocale.text("较大文字")],["animal_names",GameLocale.text("鼠标悬停显示动物名称")],["habitat_labels",GameLocale.text("生境文字标识（辅助辨色）")]]:
		var setting_key = str(option[0])
		var check = CheckButton.new()
		check.text = option[1]
		check.button_pressed = ui.settings[setting_key]
		check.toggled.connect(func(value):
			ui.settings[setting_key] = value
			ui._apply_comfort()
			ui._save_settings())
		body.add_child(check)
	body.add_child(ui._wrap(GameLocale.text("文字大小在关闭设置后应用。离线模式自动存档，联机模式由房主同步。"),19,P.MUTED))
	ui._spacer(body)
	body.add_child(ui._button(GameLocale.text("返回旅程"),ui._close_modal,true))
