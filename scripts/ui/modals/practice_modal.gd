extends "res://scripts/ui/modals/modal.gd"

func open(controller) -> void:
	var score = controller.S.game_scores(controller.game)[0]
	var body = controller._open_modal(GameLocale.text("首回合练习完成"),800,520,self)
	body.add_child(ui._heading(GameLocale.text("这个回合为版图增加了 %d 分") % (score.total-ui._practice_start_score.total),27,P.GOLD_DEEP))
	body.add_child(ui._wrap(GameLocale.text("泥滩  ·  最大相连区域从 %d 格变为 %d 格，每格 1 分。") % [
		ui._practice_start_score.habitats.mudflat.points,score.habitats.mudflat.points],22))
	body.add_child(ui._wrap(GameLocale.text("弹涂鱼 A  ·  在这片泥滩记录到一只弹涂鱼，得 %d 分。") % score.wildlife.goby.points,22))
	body.add_child(ui._wrap(GameLocale.text("练习到此结束，不写入正式存档。正式对局有 20 回合，你可以自由选择组件和落点。"),19,P.MUTED))
	ui._spacer(body)
	body.add_child(ui._button(GameLocale.text("返回主菜单"),ui.show_menu,true))
	Feedback.reveal(get_child(1))
