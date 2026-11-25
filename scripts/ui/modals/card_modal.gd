extends "res://scripts/ui/modals/modal.gd"

var category: String
var score: Button

func open(controller, animal: String, card: String) -> void:
	category = animal
	var body = controller._open_modal(T.ANIMAL_NAMES[animal]+" · "+card+"  "+Cards.title(animal,card),820,710,self)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var content = ui._vbox(14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(ui._wrap(Cards.description(animal,card),23))
	var diagram = load("res://scripts/ui/rule_diagram.gd").new()
	diagram.animal = animal
	diagram.card = card
	content.add_child(ui._chip(diagram,"CardPanel"))
	content.add_child(ui._button("重置图例",diagram.reset_example))
	content.add_child(ui._wrap("点击圆片移除，再点空格恢复，观察分数变化。共边才算相邻；图例只计算本张动物卡，不影响对局。",18,P.MUTED))
	score = ui._button("",func():ui._highlight_score(ui.view_player,category,true),true)
	body.add_child(score)
	if ui.game != null: update(ui._view_state())
	else: score.hide()

func update(state: Dictionary) -> void:
	View.apply(score,&"visible",state.game.finished)
	if score.visible:
		View.apply(score,&"text","查看本项得分 · %d 分" % state.reports[state.view].wildlife[category].points)
