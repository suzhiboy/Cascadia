extends PanelContainer

const View = preload("res://scripts/ui/view_properties.gd")
const P = preload("res://scripts/ui/palette.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")
const MarketTile = preload("res://scripts/ui/market_tile.gd")
const Practice = preload("res://scripts/ui/first_turn_practice.gd")

var stepper: HBoxContainer
var steps: Array[Dictionary] = []
var caption: Label
var status: Label
var hand: HBoxContainer
var tile: Control
var animal: Control
var tile_mode: Button
var animal_mode: Button
var rotate_left: Button
var rotate_right: Button
var release: Button
var confirm: Button
var review: Button
var results: Button
var again: Button
var back: Button

func build(ui) -> void:
	name = "ActionBar"
	theme_type_variation = "BarPanel"
	var row = ui._hbox(12)
	add_child(row)
	var info = ui._vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	caption = ui._heading("",24,P.DARK)
	info.add_child(caption)
	stepper = ui._hbox(6)
	info.add_child(stepper)
	for i in range(4):
		var chip = ui._hbox(6)
		var mark = Ornament.make("hex",Vector2(20,22),P.GOLD,P.DARK,str(i+1))
		mark.font_size = 13
		chip.add_child(mark)
		var label = ui._heading([GameLocale.text("选取"),GameLocale.text("地块"),GameLocale.text("动物"),GameLocale.text("确认")][i],17)
		chip.add_child(label)
		var holder = ui._chip(chip)
		stepper.add_child(holder)
		steps.append({"mark":mark,"label":label,"holder":holder,"appearance":-1})
		if i < 3: stepper.add_child(ui._label("›",18,Color(P.MUTED.r,P.MUTED.g,P.MUTED.b,.6)))
	status = ui._wrap("",17,P.MUTED)
	info.add_child(status)
	review = ui._button(GameLocale.text("查看练习得分"),ui._practice_results,true)
	results = ui._button(GameLocale.text("查看计分"),ui.show_results)
	again = ui._button(GameLocale.text("再来一局"),ui.show_setup,true)
	back = ui._button(GameLocale.text("返回当前玩家"),func():ui._view(ui.game.active),true)
	for button in [review,results,again,back]: row.add_child(button)
	hand = ui._hbox(12)
	row.add_child(hand)
	var pieces = ui._hbox(2)
	tile = MarketTile.new()
	tile.custom_minimum_size = Vector2(95,90)
	pieces.add_child(tile)
	animal = MarketTile.new()
	animal.show_token = true
	animal.custom_minimum_size = Vector2(55,70)
	animal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pieces.add_child(animal)
	hand.add_child(ui._chip(pieces))
	hand.add_child(VSeparator.new())
	tile_mode = ui._button(GameLocale.text("放地块"),ui._set_mode.bind("tile"))
	animal_mode = ui._button(GameLocale.text("放动物"),ui._set_mode.bind("animal"))
	tile_mode.visible = not ui._practicing
	animal_mode.visible = not ui._practicing
	hand.add_child(tile_mode)
	hand.add_child(animal_mode)
	rotate_left = ui._button("↶ Q",ui._rotate.bind(-1))
	rotate_right = ui._button("E ↷",ui._rotate.bind(1))
	hand.add_child(rotate_left)
	hand.add_child(rotate_right)
	hand.add_child(VSeparator.new())
	release = ui._button(GameLocale.text("放归动物"),func():ui._action(ui._request_action("discard_animal")))
	release.disabled = ui._practicing
	hand.add_child(ui._styled(release,"QuietButton"))
	hand.add_child(ui._styled(ui._button(GameLocale.text("撤回摆放"),ui._undo_placement),"QuietButton"))
	hand.add_child(VSeparator.new())
	confirm = ui._button(GameLocale.text("完成回合"),ui._commit,true)
	confirm.custom_minimum_size.x = 150
	hand.add_child(confirm)
	for button in find_children("*","Button",true,false):
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size.y = 54

func update(state: Dictionary) -> void:
	var game = state.game
	var in_review = state.step == Practice.Step.REVIEW
	var spectating = state.view != game.active
	View.apply(review,&"visible",in_review)
	View.apply(results,&"visible",not in_review and game.finished)
	View.apply(again,&"visible",results.visible)
	View.apply(back,&"visible",not in_review and not game.finished and spectating)
	View.apply(caption,&"visible",review.visible or results.visible or back.visible or state.ai)
	View.apply(stepper,&"visible",not caption.visible)
	View.apply(status,&"text",state.status)
	if status.get_theme_color("font_color") != P.MUTED:
		status.add_theme_color_override("font_color",P.MUTED)
	if state.ai and not spectating:
		View.apply(caption,&"text",GameLocale.player_name(game.players[game.active].name)+GameLocale.text(" · 电脑回合"))
	elif caption.visible:
		View.apply(caption,&"text",GameLocale.text("首回合已确认") if in_review else (GameLocale.text("旅程完成  ·  %d 分") % state.reports[state.view].total if game.finished else GameLocale.text("正在查看其他旅行者的版图")))
	var picked = not game.pending.is_empty()
	View.apply(hand,&"visible",stepper.visible and picked and state.can_act)
	var ready = picked and game.ready_to_commit()
	if stepper.visible:
		var done = [picked,picked and game.pending.tile_pos != null,picked and (game.pending.animal_pos != null or game.pending.discarded),false]
		var current = 0 if not picked else (3 if ready else (1 if state.mode == "tile" else 2))
		for i in range(steps.size()):
			_update_step(steps[i],2 if i == current else (1 if done[i] else 0))
	if hand.visible:
		if tile.tile_id != game.pending.tile or tile.tile_rotation != game.pending.rotation:
			tile.tile_id = game.pending.tile
			tile.tile_rotation = game.pending.rotation
			tile.queue_redraw()
		if animal.animal != game.pending.animal:
			animal.animal = game.pending.animal
			animal.queue_redraw()
		View.apply(tile_mode,&"theme_type_variation","ActiveButton" if state.mode == "tile" else "")
		View.apply(animal_mode,&"theme_type_variation","ActiveButton" if state.mode == "animal" else "")
		View.apply(rotate_left,&"disabled",state.practice and game.pending.tile_pos != null)
		View.apply(rotate_right,&"disabled",rotate_left.disabled)
		View.apply(rotate_right,&"theme_type_variation","PrimaryButton" if state.step == Practice.Step.ROTATE else "")
		View.apply(confirm,&"disabled",not ready)

func _update_step(step: Dictionary, appearance: int) -> void:
	if step.appearance == appearance: return
	step.appearance = appearance
	var current = appearance == 2
	var done = appearance == 1
	step.mark.kind = "check" if done else "hex"
	step.mark.color = P.GOLD if current else (P.CREAM if done else Color(P.MUTED.r,P.MUTED.g,P.MUTED.b,.35))
	step.mark.accent = P.DARK if current else (P.MOSS if done else P.PAPER)
	step.mark.queue_redraw()
	step.label.add_theme_font_override("font",P.font(650 if current else 520))
	step.label.add_theme_color_override("font_color",P.CREAM if current or done else P.MUTED)
	var fill = P.DARK if current else (P.MOSS if done else Color.TRANSPARENT)
	step.holder.add_theme_stylebox_override("panel",P.chip(fill,P.DARK if current else (P.MOSS if done else P.LINE),14,10,3))
