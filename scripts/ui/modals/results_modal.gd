extends "res://scripts/ui/modals/modal.gd"

const S = preload("res://scripts/core/scorer.gd")

var banner: Label
var explanation: Label
var replay: Button
var columns: Array[Dictionary] = []
var animal_labels := {}
var previous_scores: Array = []
var source: Array = []

func open(controller) -> void:
	var body = controller._open_modal("",1150,950,self)
	set_meta("live_scores",true)
	banner = ui._wrap("",27,P.GOLD_DEEP)
	banner.add_theme_font_override("font",P.font(680))
	body.add_child(banner)
	explanation = ui._wrap("",18,P.MUTED)
	body.add_child(explanation)
	var grid = GridContainer.new()
	grid.columns = ui.game.players.size()+1
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",5)
	grid.add_child(ui._heading("计分项目",20,P.MUTED,600))
	for i in range(ui.game.players.size()):
		var label = ui._heading("",21,P.INK,640)
		label.clip_text = true
		label.custom_minimum_size.x = 145
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stripe = P.chip(Color.TRANSPARENT,P.PLAYERS[i%P.PLAYERS.size()].darkened(.15),0,0,2)
		stripe.set_border_width_all(0)
		stripe.border_width_bottom = 4
		label.add_theme_stylebox_override("normal",stripe)
		grid.add_child(label)
		columns.append({"name":label,"wildlife":{},"habitats":{}})
	for animal in T.ANIMALS:
		animal_labels[animal] = ui._label("",20)
		grid.add_child(animal_labels[animal])
		for i in range(columns.size()):
			columns[i].wildlife[animal] = _score_button(grid,i,animal,true)
	for habitat in T.HABITATS:
		grid.add_child(ui._label(T.HABITAT_NAMES[habitat],20))
		for i in range(columns.size()):
			columns[i].habitats[habitat] = _score_button(grid,i,habitat,false)
	grid.add_child(ui._label("剩余自然标记",20))
	for column in columns:
		column.nature = ui._label("",22)
		column.nature.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(column.nature)
	grid.add_child(ui._heading("总分",26,P.DARK))
	for column in columns:
		column.total = ui._heading("",35,P.DARK,720)
		column.total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(column.total)
	body.add_child(grid)
	ui._spacer(body)
	var row = ui._hbox()
	row.add_child(ui._styled(ui._button("回看生态版图",ui._close_modal),"QuietButton"))
	ui._spacer(row)
	replay = ui._button("再来一局",ui.show_setup,true)
	row.add_child(replay)
	body.add_child(row)
	update(ui._view_state())
	Feedback.reveal(get_child(1))

func _score_button(grid: GridContainer, index: int, category: String, wildlife: bool) -> Button:
	var button = ui._button("",ui._highlight_score.bind(index,category,wildlife))
	button.custom_minimum_size.y = 39
	button.theme_type_variation = "ScoreButton"
	grid.add_child(button)
	return button

func update(state: Dictionary) -> void:
	var game = state.game
	var inputs = [game.players,game.config.cards,game.finished]
	if source == inputs: return
	source = inputs.duplicate(true)
	var reports = S.game_scores(game)
	ui.reports = reports
	var winners = S.winners(game,reports)
	var names = winners.map(func(i):return game.players[i].name)
	var live = not game.finished
	View.apply(title_label,&"text","实时得分 · Tab 返回" if live else "旅程的收获")
	var heading = " · ".join(names)+("  并列获胜" if names.size()>1 else "  获胜")
	if reports.size() == 1: heading = "你的生态世界 · %d 分" % reports[0].total
	View.apply(banner,&"text","当前已落定版图 · 分数预估" if live else heading)
	View.apply(explanation,&"text","不含本回合未确认的摆放；生境奖励按当前排名估算。Tab / Esc 返回。" if live else "点击动物或生境得分，查看版图上的计分依据。")
	View.apply(replay,&"visible",not live)
	for animal in T.ANIMALS:
		View.apply(animal_labels[animal],&"text",T.ANIMAL_NAMES[animal]+" "+game.config.cards[animal])
	for i in range(columns.size()):
		var column = columns[i]
		var report = reports[i]
		View.apply(column.name,&"text",game.players[i].name)
		View.apply(column.name,&"tooltip_text",column.name.text)
		for animal in T.ANIMALS: View.apply(column.wildlife[animal],&"text",str(report.wildlife[animal].points))
		for habitat in T.HABITATS:
			var part = report.habitats[habitat]
			View.apply(column.habitats[habitat],&"text","%d + %d" % [part.points,part.bonus])
		View.apply(column.nature,&"text",str(report.nature))
		var color = P.GOLD_DEEP if i in winners else P.DARK
		if column.total.get_theme_color("font_color") != color:
			column.total.add_theme_color_override("font_color",color)
		if previous_scores.is_empty() or previous_scores[i].total != report.total:
			Feedback.count_score(column.total,int(report.total))
	previous_scores = reports
