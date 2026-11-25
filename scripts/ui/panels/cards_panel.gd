extends PanelContainer

const View = preload("res://scripts/ui/view_properties.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const Cards = preload("res://scripts/core/scoring_card_definition.gd")
const P = preload("res://scripts/ui/palette.gd")

var cards := {}
var results: Button
var hint: Label

func build(ui) -> void:
	name = "CardsPanel"
	custom_minimum_size.x = 330
	var content = ui._vbox(10)
	add_child(ui._margin(content,8))
	content.add_child(ui._heading("野生动物手记",27,P.DARK))
	content.add_child(ui._label("点击卡片，查看完整计分规则",16,P.MUTED))
	for animal in T.ANIMALS:
		var button = ui._styled(ui._button("",func():ui.show_card(animal,ui.game.config.cards[animal])),"CardButton")
		button.custom_minimum_size = Vector2(285,115)
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var row = ui._hbox(6)
		var margin = ui._margin(row,10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art = ui._art(animal)
		art.custom_minimum_size.x = 101
		row.add_child(art)
		var info = ui._vbox(2)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		var title = ui._hbox(8)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(ui._heading(T.ANIMAL_NAMES[animal],22,P.INK,650))
		var letter = ui._heading("",15,P.CREAM,700)
		var chip = ui._chip(letter)
		chip.add_theme_stylebox_override("panel",P.chip(P.ANIMALS[animal].darkened(.15),P.ANIMALS[animal].darkened(.3),6,7,0))
		title.add_child(chip)
		info.add_child(title)
		var description = ui._label("",16,P.MUTED)
		info.add_child(description)
		var points = ui._heading("",22,P.GOLD_DEEP,700)
		info.add_child(points)
		cards[animal] = {"letter":letter,"description":description,"points":points}
		row.add_child(info)
		content.add_child(button)
	results = ui._button("查看完整计分",ui.show_results,true)
	content.add_child(results)
	hint = ui._wrap("栖息地连成片，动物各有所爱。\n计分在旅程结束后进行。",16,P.MUTED)
	content.add_child(hint)

func update(state: Dictionary) -> void:
	var game = state.game
	for animal in cards:
		var row = cards[animal]
		var letter = game.config.cards[animal]
		if row.letter.text != letter:
			View.apply(row.letter,&"text",letter)
			View.apply(row.description,&"text",Cards.title(animal,letter))
		View.apply(row.points,&"visible",game.finished)
		if game.finished:
			View.apply(row.points,&"text","%d 分" % state.reports[state.view].wildlife[animal].points)
	View.apply(results,&"visible",game.finished)
	View.apply(hint,&"visible",not game.finished)
