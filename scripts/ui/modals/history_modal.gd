extends "res://scripts/ui/modals/modal.gd"

const Chart = preload("res://scripts/ui/survey_chart.gd")

func open(controller) -> void:
	var body = controller._open_modal(GameLocale.text("调查轨迹"),1250,940,self)
	body.add_child(ui._heading(GameLocale.text("每轮结束时的总分（含地貌排名奖励）"),23,P.DARK))
	var chart = Chart.new()
	chart.name = "ScoreHistory"
	chart.show_players(ui.game.players)
	body.add_child(chart)
	body.add_child(ui._heading(GameLocale.text("最佳一步与终局版图"),23,P.DARK))
	var grid = GridContainer.new()
	grid.columns = mini(2,ui.game.players.size())
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for i in range(ui.game.players.size()):
		grid.add_child(_summary(ui.game.players[i],i))
	body.add_child(ui._button(GameLocale.text("返回计分"),ui.show_results))

func _summary(player: Dictionary, index: int) -> PanelContainer:
	var best = Chart.best_move(player.get("history",[]))
	var row = ui._hbox(12)
	var thumbnail = Chart.FinalBoard.new()
	thumbnail.name = "FinalBoard"
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.custom_minimum_size = Vector2(142,130)
	thumbnail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumbnail.cells = player.board
	thumbnail.best = best
	row.add_child(thumbnail)
	var info = ui._vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var name_label = ui._heading(GameLocale.player_name(player.name),21,P.PLAYERS[index].darkened(.32))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = GameLocale.player_name(player.name)
	info.add_child(name_label)
	if best.is_empty():
		info.add_child(ui._wrap(GameLocale.text("没有可回顾的完整回合"),18,P.MUTED))
	else:
		info.add_child(ui._heading(tr("第 %d 回合 · %+d 分") % [best.turn,best.delta],21,P.DARK))
		info.add_child(ui._wrap(tr("地块 #%d · (%d, %d) · %d°") % [best.tile,best.cell[0],best.cell[1],int(best.rotation)*60],17,P.INK))
		var animal = GameLocale.text(T.ANIMAL_NAMES[best.animal])
		var placement = tr("放归%s") % animal
		if best.animal_cell != null:
			placement = tr("%s · (%d, %d)") % [animal,best.animal_cell[0],best.animal_cell[1]]
		info.add_child(ui._wrap(placement,17,P.INK))
	var card = ui._chip(ui._margin(row,6),"CardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return card
