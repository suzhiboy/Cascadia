extends PanelContainer

const View = preload("res://scripts/ui/view_properties.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const P = preload("res://scripts/ui/palette.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")
const MarketTile = preload("res://scripts/ui/market_tile.gd")
const Practice = preload("res://scripts/ui/first_turn_practice.gd")

var rows: Array[Dictionary] = []
var tokens: Array = []
var notice: Label
var notice_panel: Control
var footer: Label
var take: Button
var free_refresh: Button
var nature: Button

func build(ui) -> void:
	name = "MarketPanel"
	custom_minimum_size.x = 310
	var content = ui._vbox(10)
	add_child(ui._margin(content,8))
	content.add_child(ui._heading("海岸市集",27,P.DARK))
	content.add_child(ui._label("选一块栖息地 · 邀一位新邻居",16,P.MUTED))
	notice = ui._wrap("",16,P.RUST)
	notice_panel = ui._chip(notice)
	content.add_child(notice_panel)
	for i in range(4):
		var row = ui._hbox(8)
		var badge = Ornament.make("hex",Vector2(24,26),P.GOLD_DEEP,P.CREAM,str(i+1))
		row.add_child(badge)
		var tile = ui._button("",ui._market_pick.bind(i,false))
		tile.custom_minimum_size = Vector2(140,102)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var picture = MarketTile.new()
		tile.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_child(tile)
		var animal = ui._button("",ui._market_pick.bind(i,true))
		animal.custom_minimum_size = Vector2(90,102)
		var token = MarketTile.new()
		token.show_token = true
		tokens.append(token)
		animal.add_child(token)
		token.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_child(animal)
		content.add_child(row)
		rows.append({"badge":badge,"tile":tile,"picture":picture,"animal":animal,"token":token})
	footer = ui._wrap("",16,P.MUTED)
	content.add_child(footer)
	ui._spacer(content)
	take = ui._button("",func():
		if ui.refreshing:
			var error = ui._request_action("refresh",{"indices":ui.refresh_indices,"spend_nature":true})
			if error.is_empty(): ui._reset_selection()
			ui._action(error)
		else: ui._draft(),true)
	content.add_child(take)
	free_refresh = ui._styled(ui._button("更换三枚同种动物",func():
		ui._action(ui._request_action("refresh",{"indices":ui.game.triplicate(),"spend_nature":false}))),"QuietButton")
	content.add_child(free_refresh)
	nature = ui._styled(ui._button("",ui.show_nature),"QuietButton")
	content.add_child(nature)

func update(state: Dictionary) -> void:
	var game = state.game
	View.apply(notice_panel,&"visible",state.independent or state.refreshing)
	if notice_panel.visible:
		View.apply(notice,&"text","自由搭配：分别点选地块与动物" if state.independent else "更换动物：点选要换掉的动物")
	var locked = game.finished or not game.pending.is_empty()
	for i in range(rows.size()):
		var row = rows[i]
		var practice_target = state.step == Practice.Step.SELECT and i == Practice.MARKET_GROUP
		var row_locked = locked or (state.practice and (i != Practice.MARKET_GROUP or state.step == Practice.Step.REVIEW))
		var paired = state.tile == i and state.animal == i
		var color = P.GOLD_DEEP if paired or practice_target else Color(P.DARK.r,P.DARK.g,P.DARK.b,.75)
		if row.badge.color != color:
			row.badge.color = color
			row.badge.queue_redraw()
		View.apply(row.tile,&"disabled",row_locked)
		View.apply(row.animal,&"disabled",row_locked)
		View.apply(row.tile,&"theme_type_variation","ActiveButton" if state.tile == i or practice_target else "")
		View.apply(row.animal,&"theme_type_variation","MarkedButton" if i in state.indices else ("ActiveButton" if state.animal == i or practice_target else ""))
		var tile_id = int(game.market_tiles[i])
		if row.picture.tile_id != tile_id:
			row.picture.tile_id = tile_id
			row.picture.queue_redraw()
			View.apply(row.tile,&"tooltip_text","")
			if tile_id > 0:
				var tile = T.get_tile(tile_id)
				View.apply(row.tile,&"tooltip_text"," · ".join(tile.habitats.map(func(h):return T.HABITAT_NAMES[h]))+"\n可安置："+"、".join(tile.wildlife.map(func(a):return T.ANIMAL_NAMES[a])))
		if row.token.animal != game.market_animals[i]:
			row.token.animal = game.market_animals[i]
			row.token.queue_redraw()
			View.apply(row.animal,&"tooltip_text",T.ANIMAL_NAMES.get(row.token.animal,""))
		var tint = Color(1,1,1,.5 if row_locked else 1.0)
		View.apply(row.picture,&"self_modulate",tint)
		View.apply(row.token,&"self_modulate",tint)
	View.apply(footer,&"text","教学市集 · 练习不影响正式存档" if state.practice else ("单人：最下方剩余地块与动物将在回合结束时离场。" if game.config.count == 1 else "剩余地块  %d" % game.deck.size()))
	View.apply(take,&"text","确认更换动物" if state.refreshing else ("自由搭配 · 确认" if state.independent else "确认选取"))
	View.apply(take,&"disabled",locked or (state.indices.is_empty() if state.refreshing else state.tile < 0 or state.animal < 0))
	View.apply(free_refresh,&"disabled",state.practice or game.triplicate().is_empty())
	var balance = int(game.players[game.active].nature)
	View.apply(nature,&"text","使用自然标记  ·  %d" % balance)
	View.apply(nature,&"disabled",state.practice or locked or balance < 1)
