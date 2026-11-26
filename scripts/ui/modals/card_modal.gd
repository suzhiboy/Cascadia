extends "res://scripts/ui/modals/modal.gd"

var category: String
var score: Button

func open(controller, animal: String, card: String) -> void:
	category = animal
	var body = controller._open_modal(GameLocale.text(T.ANIMAL_NAMES[animal])+" · "+card+"  "+Cards.title(animal,card),940,800,self)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var content = ui._vbox(14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(ui._wrap(Cards.description(animal,card),23))
	var diagram = preload("res://scripts/ui/rule_diagram.gd").new()
	diagram.animal = animal
	diagram.card = card
	content.add_child(ui._chip(diagram,"CardPanel"))
	content.add_child(ui._button(GameLocale.text("重置图例"),diagram.reset_example))
	content.add_child(ui._wrap(GameLocale.text("点击动物可以移走它，点原处放回。图里的分数只算这张卡。"),18,P.MUTED))
	score = ui._button("",func():ui._highlight_score(ui.view_player,category,true),true)
	body.add_child(score)
	if ui.game != null: update(ui._view_state())
	else: score.hide()

func update(state: Dictionary) -> void:
	View.apply(score,&"visible",state.game.finished)
	if score.visible:
		View.apply(score,&"text",GameLocale.text("查看本项得分 · %d 分") % state.reports[state.view].wildlife[category].points)
