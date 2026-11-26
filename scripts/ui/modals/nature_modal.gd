extends "res://scripts/ui/modals/modal.gd"

func open(controller) -> void:
	var body = controller._open_modal(GameLocale.text("自然标记"),770,480,self)
	var intro = ui._hbox(14)
	intro.add_child(Ornament.make("shell",Vector2(40,44),P.MOSS,P.CREAM))
	intro.add_child(ui._wrap(GameLocale.text("每枚自然标记可帮助你选择更合适的伙伴。未使用的标记在终局各值 1 分。"),23))
	body.add_child(intro)
	body.add_child(ui._button(GameLocale.text("自由搭配 · 任选一块地与一枚动物"),func():
		ui._close_modal()
		ui._reset_selection()
		ui.independent=true
		ui.status=GameLocale.text("分别点击一个地块与一枚动物。跨组选取消耗 1 枚自然标记。")
		ui._render_game(),true))
	body.add_child(ui._button(GameLocale.text("更换动物 · 选择任意数量"),func():
		ui._close_modal()
		ui._reset_selection()
		ui.refreshing=true
		ui.status=GameLocale.text("点击市集中想更换的动物，再点击「确认更换动物」。")
		ui._render_game()))
	body.add_child(ui._wrap(GameLocale.text("更换会揭示新动物，确认后无法撤回。可在同一回合多次使用自然标记。"),18,P.MUTED))
