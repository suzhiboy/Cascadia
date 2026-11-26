extends "res://scripts/ui/modals/modal.gd"

const S = preload("res://scripts/core/scorer.gd")
const SOLO_THRESHOLDS = [90,94,97,100]
const SOLO_RATINGS = ["完成初访","潮滩观察员","岸线记录员","群岛调查员","潮间带领航员"]
const RATING_INKS = [P.SEA_DEEP,P.SEA_MID,P.MOSS,P.DARK,P.GOLD_DEEP]
const CATEGORY_TIME = .11
const TOTAL_TIME = .4

var hero: PanelContainer
var banner: Label
var comparison: Label
var record_mark: Label
var rating_badge: Control
var explanation: Label
var review: Button
var replay: Button
var names: Array[Label] = []
var score_rows: Array[Dictionary] = []
var animal_labels := {}
var source: Array = []
var reveal: Tween
var winners: Array = []

func open(controller) -> void:
	var body = controller._open_modal("",1150,950,self)
	set_meta("live_scores",true)
	_build_banner(body)
	explanation = ui._wrap("",18,P.MUTED)
	body.add_child(explanation)
	var grid = GridContainer.new()
	grid.columns = ui.game.players.size()+1
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",5)
	grid.add_child(ui._heading(GameLocale.text("计分项目"),20,P.MUTED,600))
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
		names.append(label)
	for animal in T.ANIMALS:
		animal_labels[animal] = ui._label("",20)
		grid.add_child(animal_labels[animal])
		_add_category(grid,animal,true)
	for habitat in T.HABITATS:
		grid.add_child(ui._label(GameLocale.text(T.HABITAT_NAMES[habitat]),20))
		_add_category(grid,habitat,false)
	grid.add_child(ui._label(GameLocale.text("剩余自然标记"),20))
	_add_summary_row(grid,"nature",22,P.INK)
	grid.add_child(ui._heading(GameLocale.text("总分"),26,P.DARK))
	_add_summary_row(grid,"total",35,P.DARK)
	body.add_child(grid)
	ui._spacer(body)
	var row = ui._hbox()
	row.add_child(ui._styled(ui._button(GameLocale.text("回看生态版图"),ui._close_modal),"QuietButton"))
	review = ui._button(GameLocale.text("调查轨迹"),func():preload("res://scripts/ui/modals/history_modal.gd").new().open(ui))
	row.add_child(review)
	ui._spacer(row)
	replay = ui._button(GameLocale.text("再来一局"),ui.show_setup,true)
	row.add_child(replay)
	body.add_child(row)
	update(ui._view_state())
	if not ui.game.finished and _can_animate(): Feedback.reveal(get_child(1))

func _build_banner(body: VBoxContainer) -> void:
	hero = PanelContainer.new()
	hero.name = "ResultBanner"
	hero.add_theme_stylebox_override("panel",P.box(P.DARK,14,P.GOLD))
	body.add_child(hero)
	var row = ui._hbox(15)
	hero.add_child(row)
	rating_badge = Ornament.make("rating",Vector2(64,64),P.DARK,P.GOLD_LIGHT)
	rating_badge.name = "SoloRating"
	row.add_child(rating_badge)
	var text = ui._vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	banner = ui._wrap("",27,P.GOLD_LIGHT)
	banner.name = "ResultTitle"
	banner.add_theme_font_override("font",P.font(680))
	text.add_child(banner)
	comparison = ui._wrap("",18,P.CREAM)
	comparison.name = "ResultComparison"
	text.add_child(comparison)
	record_mark = ui._heading(GameLocale.text("新纪录"),23,P.GOLD_LIGHT,720)
	record_mark.name = "NewRecord"
	record_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	record_mark.add_theme_stylebox_override("normal",Ornament.badge(P.SEA_DEEP,P.GOLD))
	row.add_child(record_mark)

func _add_category(grid: GridContainer, category: String, wildlife: bool) -> void:
	var cells = []
	for i in range(names.size()):
		var button = ui._button("",ui._highlight_score.bind(i,category,wildlife))
		button.name = category.capitalize()+"Score"+str(i)
		button.custom_minimum_size.y = 39
		button.theme_type_variation = "ScoreButton"
		grid.add_child(button)
		cells.append(button)
	score_rows.append({"cells":cells,"group":"wildlife" if wildlife else "habitats","key":category})

func _add_summary_row(grid: GridContainer, field: String, font_size: int, color: Color) -> void:
	var cells = []
	for i in range(names.size()):
		var label = ui._heading("",font_size,color,720)
		label.name = field.capitalize()+"Score"+str(i)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(label)
		cells.append(label)
	score_rows.append({"cells":cells,"group":"","key":field})

func _can_animate() -> bool:
	return Feedback.enabled and is_instance_valid(ui.board) and ui.board.animations

static func rating_for(total: int) -> int:
	var rank = 0
	for threshold in SOLO_THRESHOLDS:
		if total >= threshold: rank += 1
	return rank

func update(state: Dictionary) -> void:
	var game = state.game
	var inputs = [game.players,game.config.cards,game.finished]
	if source == inputs: return
	source = inputs.duplicate(true)
	var reports = S.game_scores(game)
	ui.reports = reports
	var live = not game.finished
	winners = S.winners(game,reports) if not live else []
	View.apply(title_label,&"text",GameLocale.text("实时得分 · Tab 返回") if live else GameLocale.text("旅程的收获"))
	_update_banner(state,reports)
	View.apply(explanation,&"text",GameLocale.text("不含本回合未确认的摆放；生境奖励按当前排名估算。Tab / Esc 返回。") if live else GameLocale.text("点击动物或生境得分，查看版图上的计分依据。"))
	View.apply(replay,&"visible",not live)
	View.apply(review,&"visible",not live)
	for animal in T.ANIMALS:
		View.apply(animal_labels[animal],&"text",GameLocale.text(T.ANIMAL_NAMES[animal])+" "+game.config.cards[animal])
	for i in range(names.size()):
		View.apply(names[i],&"text",GameLocale.player_name(game.players[i].name))
		View.apply(names[i],&"tooltip_text",names[i].text)
	for row in score_rows:
		row.values = reports.map(func(report):
			if row.group.is_empty(): return Vector2i(report[row.key],0)
			var part = report[row.group][row.key]
			return Vector2i(part.points,part.get("bonus",0)))
	if live or not _can_animate():
		finish_reveal()
		return
	if reveal: reveal.kill()
	hero.modulate.a = 0.0
	shade.color.a = 1.0
	reveal = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for row in score_rows:
		_paint_row(0.0,row)
		for cell in row.cells: cell.modulate.a = .35
		var duration = TOTAL_TIME if row.key == "total" else CATEGORY_TIME
		reveal.tween_method(_paint_row.bind(row),0.0,1.0,duration)
	reveal.tween_callback(_mark_winners)
	reveal.tween_property(hero,"modulate:a",1.0,.18)
	reveal.parallel().tween_property(shade,"color:a",SHADE.a,.18)

func _update_banner(state: Dictionary, reports: Array) -> void:
	var game = state.game
	var solo = game.finished and reports.size() == 1
	rating_badge.visible = solo
	comparison.hide()
	record_mark.hide()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if solo else HORIZONTAL_ALIGNMENT_CENTER
	if not game.finished:
		banner.text = GameLocale.text("当前已落定版图 · 分数预估")
		return
	var total = int(reports[winners.front()].total)
	if solo:
		var rank = rating_for(total)
		rating_badge.value = rank
		rating_badge.color = RATING_INKS[rank]
		rating_badge.queue_redraw()
		var title = GameLocale.text(SOLO_RATINGS[rank])
		var date = str(game.config.get("daily",""))
		banner.text = title if date.is_empty() else GameLocale.text("%s · 每日挑战 %s") % [title,date]
	else:
		var winners_text = " · ".join(winners.map(func(i):return GameLocale.player_name(game.players[i].name)))
		var heading = "%s 并列获胜" if winners.size() > 1 else "%s 获胜"
		banner.text = GameLocale.text(heading) % winners_text
	if state.lan or state.practice: return
	var context = ui.records.result_context(game)
	var details = []
	var new_record = context.best_before != null and total > context.best_before
	if new_record and context.best == total:
		var format = "个人最佳 %d 分（原 %d）" if solo else "本机最佳 %d 分（原 %d）"
		details.append(GameLocale.text(format) % [total,int(context.best_before)])
	elif context.best != null:
		var format = "个人最佳 %d 分" if solo else "本机最佳 %d 分"
		details.append(GameLocale.text(format) % int(context.best))
	if context.previous != null:
		var format = "上一局 %d 分（%+d）" if solo else "上局最高 %d 分（%+d）"
		details.append(GameLocale.text(format) % [int(context.previous),total-int(context.previous)])
	if context.daily != null:
		details.append(GameLocale.text("本日最高 %d 分") % int(context.daily))
	comparison.text = "     ·     ".join(details)
	comparison.visible = not details.is_empty()
	comparison.horizontal_alignment = banner.horizontal_alignment
	record_mark.visible = new_record

func _paint_row(fraction: float, row: Dictionary) -> void:
	for i in range(row.cells.size()):
		var cell = row.cells[i]
		var value: Vector2i = row.values[i]
		var points = roundi(value.x*fraction)
		var text = "%d + %d" % [points,roundi(value.y*fraction)] if row.group == "habitats" else str(points)
		View.apply(cell,&"text",text)
		cell.modulate.a = 1.0
		if cell is Button: View.apply(cell,&"disabled",fraction < 1.0)

func _mark_winners() -> void:
	var totals = score_rows.back().cells
	for i in range(totals.size()):
		totals[i].add_theme_color_override("font_color",P.GOLD_DEEP if i in winners else P.DARK)

func finish_reveal() -> void:
	if reveal: reveal.kill()
	reveal = null
	for row in score_rows:
		_paint_row(1.0,row)
	hero.modulate.a = 1.0
	shade.color = SHADE
	_mark_winners()
