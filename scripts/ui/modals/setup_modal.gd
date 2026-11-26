extends "res://scripts/ui/modals/modal.gd"

func open(controller) -> void:
	var body = controller._open_modal("一起出发",930,840,self)
	body.add_child(ui._wrap("选择同行人数与本局计分卡。初次游玩推荐使用全部 A 卡。",22,P.MUTED))
	var count = OptionButton.new()
	for text in ["单人 · 独行之旅","2 人 · 同机轮流","3 人 · 同机轮流","4 人 · 同机轮流"]:
		count.add_item(text)
	count.custom_minimum_size.y = 55
	body.add_child(count)
	var names = []
	var seats = []
	var name_grid = GridContainer.new()
	name_grid.columns = 2
	name_grid.add_theme_constant_override("h_separation",16)
	name_grid.add_theme_constant_override("v_separation",10)
	body.add_child(name_grid)
	for i in range(4):
		var row = ui._hbox(6)
		row.visible = i == 0
		name_grid.add_child(row)
		var seat = OptionButton.new()
		seat.name = "Seat%d" % (i+1)
		for title in ["真人","电脑 · 简单","电脑 · 标准"]: seat.add_item(title)
		seat.custom_minimum_size.x = 149
		seats.append(seat)
		var input = LineEdit.new()
		input.placeholder_text = "旅行者 %d" % (i+1)
		input.max_length = 12
		input.custom_minimum_size = Vector2(190,50)
		input.add_theme_stylebox_override("normal",ui._player_field(P.PLAYERS[i]))
		row.add_child(input)
		row.add_child(seat)
		names.append(input)
	count.item_selected.connect(func(index):
		for i in range(4):
			names[i].get_parent().visible = i <= index)
	body.add_child(ui._heading("本局野生动物计分卡",23))
	var choices = {}
	var cards_row = ui._hbox(14)
	for animal in T.ANIMALS:
		var column = ui._vbox(4)
		var frame = ui._chip(column,"CardPanel")
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var art = ui._art(animal)
		art.custom_minimum_size = Vector2(110,108)
		column.add_child(art)
		var label = ui._heading(T.ANIMAL_NAMES[animal],20,P.INK,620)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		var choice = OptionButton.new()
		for text in ["A","B","C","D","随机"]:
			choice.add_item(text)
		column.add_child(choice)
		choices[animal] = choice
		cards_row.add_child(frame)
	body.add_child(cards_row)
	var presets = ui._hbox()
	presets.add_child(ui._styled(ui._button("全部 A 卡",func():
		for choice in choices.values(): choice.select(0)),"QuietButton"))
	presets.add_child(ui._styled(ui._button("全部随机",func():
		for choice in choices.values(): choice.select(4)),"QuietButton"))
	body.add_child(presets)
	ui._spacer(body)
	body.add_child(ui._button("登岛调查",func():
		var config = {"count":count.selected+1,"names":[],"seats":[],"cards":{}}
		for i in range(count.selected+1):
			var kind = ["human","ai_easy","ai_standard"][seats[i].selected]
			config.seats.append(kind)
			var display = names[i].text.strip_edges()
			config.names.append("电脑 %d" % (i+1) if display.is_empty() and kind != "human" else display)
		for animal in T.ANIMALS: config.cards[animal] = ["A","B","C","D","random"][choices[animal].selected]
		ui.start_game(config),true))
