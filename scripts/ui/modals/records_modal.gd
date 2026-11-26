extends "res://scripts/ui/modals/modal.gd"

func open_daily(controller, date: String) -> void:
	var body = controller._open_modal("每日挑战",800,690,self)
	var seed_value = int(date.replace("-",""))
	var cards = {}
	for animal in T.ANIMALS: cards[animal] = "random"
	var config = {"count":1,"daily":date,"cards":cards}
	var sample = GameState.new()
	sample.start(config,seed_value)
	body.add_child(ui._heading(date,38,P.DARK,680))
	body.add_child(ui._wrap("同一天使用相同的计分卡、起始海湾和抽取顺序。完成 20 回合后，保留本机当天的最高分。",22))
	var choices = []
	for species in T.ANIMALS:
		choices.append(T.ANIMAL_NAMES[species]+" "+sample.config.cards[species])
	body.add_child(ui._wrap(" · ".join(choices),21,P.MUTED))
	body.add_child(ui._label("种子 %d" % seed_value,18,P.MUTED))
	var days = ui.records.read().daily
	body.add_child(ui._heading("本日最高 %d 分" % days[date] if days.has(date) else "本日尚无成绩",24,P.GOLD_DEEP))
	ui._spacer(body)
	body.add_child(ui._button("开始挑战",func():ui.start_game(config,seed_value),true))

func open_stats(controller) -> void:
	var body = controller._open_modal("调查记录",940,900,self)
	var data = ui.records.read()
	body.add_child(ui._heading("累计完成 %d 局" % int(data.completed),28,P.DARK))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var content = ui._vbox(16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(ui._heading("按人数统计的本机最佳",23,P.GOLD_DEEP))
	var best = []
	for count in range(1,5):
		var value = data.best.get(str(count),null)
		best.append("%d 人 · %s" % [count,"—" if value == null else str(int(value))])
	content.add_child(ui._label("     ".join(best),22))
	content.add_child(ui._heading("计分卡平均分",23,P.GOLD_DEEP))
	var grid = GridContainer.new()
	grid.name = "CardMeans"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",32)
	grid.add_theme_constant_override("v_separation",6)
	content.add_child(grid)
	for heading in ["物种","A","B","C","D"]: grid.add_child(ui._heading(heading,20,P.MUTED))
	for species in T.ANIMALS:
		grid.add_child(ui._label(T.ANIMAL_NAMES[species],21))
		for card in ["A","B","C","D"]:
			var value = data.cards.get(species+card)
			var mean = "—" if value == null else "%.1f" % (float(value.sum)/float(value.count))
			grid.add_child(ui._label(mean,21))
	content.add_child(ui._heading("每日挑战 · 本机最高分",23,P.GOLD_DEEP))
	if data.daily.is_empty():
		content.add_child(ui._label("尚无挑战记录",20,P.MUTED))
	var days = data.daily.keys()
	days.sort()
	days.reverse()
	for date in days:
		content.add_child(ui._label("%s    %d 分" % [date,int(data.daily[date])],20))
