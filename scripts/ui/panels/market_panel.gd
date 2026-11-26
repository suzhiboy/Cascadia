extends PanelContainer

const View = preload("res://scripts/ui/view_properties.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const P = preload("res://scripts/ui/palette.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")
const MarketTile = preload("res://scripts/ui/market_tile.gd")
const Practice = preload("res://scripts/ui/first_turn_practice.gd")

const Feedback = preload("res://scripts/ui/feedback.gd")

var last_tiles: Array = []
var last_animals: Array = []
var last_turn := -1
var hover_card: PanelContainer
var hover_picture: Control
var hover_text: Label
var hovered_row := -1
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
		picture.market_display = true
		tile.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var old_tile = _old_piece(tile,false)
		tile.mouse_entered.connect(_hover.bind(i))
		tile.mouse_exited.connect(_leave.bind(i))
		row.add_child(tile)
		var animal = ui._button("",ui._market_pick.bind(i,true))
		animal.custom_minimum_size = Vector2(90,102)
		var token = MarketTile.new()
		token.show_token = true
		tokens.append(token)
		animal.add_child(token)
		token.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var old_token = _old_piece(animal,true)
		animal.clip_contents = true
		tile.clip_contents = true
		row.add_child(animal)
		content.add_child(row)
		rows.append({"badge":badge,"tile":tile,"picture":picture,"animal":animal,"token":token,"old_tile":old_tile,"old_token":old_token,"tile_tween":null,"token_tween":null})
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
	hover_card = PanelContainer.new()
	hover_card.top_level = true
	hover_card.z_index = 8
	hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var details = ui._vbox(2)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_picture = MarketTile.new()
	hover_picture.market_display = true
	hover_picture.custom_minimum_size = Vector2(180,150)
	details.add_child(hover_picture)
	hover_text = ui._wrap("",17,P.INK)
	hover_text.custom_minimum_size.x = 175
	details.add_child(hover_text)
	hover_card.add_child(details)
	add_child(hover_card)
	hover_card.hide()

func _hover(index: int) -> void:
	hovered_row = index
	var row = rows[index]
	if row.picture.tile_id <= 0:
		hover_card.hide()
		return
	hover_picture.tile_id = row.picture.tile_id
	hover_picture.queue_redraw()
	hover_text.text = row.tile.tooltip_text
	hover_card.global_position = Vector2(get_global_rect().end.x+6,row.tile.global_position.y)
	hover_card.show()

func _leave(index: int) -> void:
	if hovered_row == index:
		hovered_row = -1
		hover_card.hide()

func _old_piece(button: Button, token: bool) -> Control:
	var piece = MarketTile.new()
	piece.show_token = token
	piece.market_display = true
	button.add_child(piece)
	piece.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	piece.hide()
	return piece

func _transition(row: Dictionary, token: bool, old_value, new_value, eject: bool) -> void:
	var key = "token_tween" if token else "tile_tween"
	var previous = row.old_token if token else row.old_tile
	var incoming = row.token if token else row.picture
	if row[key]: row[key].kill()
	previous.hide()
	incoming.position = Vector2.ZERO
	incoming.modulate.a = 1.0
	var tween = create_tween().set_parallel(true)
	row[key] = tween
	if old_value:
		if token: previous.animal = old_value
		else: previous.tile_id = old_value
		previous.position = Vector2.ZERO
		previous.modulate.a = 1.0
		previous.show()
		previous.queue_redraw()
		tween.tween_property(previous,"position:y",62 if eject else 8,.16)
		tween.tween_property(previous,"modulate:a",0,.17)
	if new_value:
		incoming.position.y = -23
		incoming.modulate.a = 0.0
		tween.tween_property(incoming,"position:y",0,.19).set_delay(.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(incoming,"modulate:a",1,.18).set_delay(.045)
	tween.chain().tween_callback(previous.hide)

func stop_motion() -> void:
	for row in rows:
		for key in ["tile_tween","token_tween"]:
			if row[key]: row[key].kill()
		for piece in [row.picture,row.token]:
			piece.position = Vector2.ZERO
			piece.modulate.a = 1.0
		row.old_tile.hide()
		row.old_token.hide()

func update(state: Dictionary) -> void:
	var game = state.game
	View.apply(notice_panel,&"visible",state.independent or state.refreshing)
	if notice_panel.visible:
		View.apply(notice,&"text","自由搭配：分别点选地块与动物" if state.independent else "更换动物：点选要换掉的动物")
	var turns = 0
	for player in game.players: turns += int(player.turns)
	var refill = last_turn >= 0 and game.pending.is_empty() and not game.finished and Feedback.enabled
	var solo_eject = refill and turns > last_turn and game.config.count == 1
	var last_tile = -1
	var last_token = -1
	if solo_eject:
		for i in range(4):
			if last_tiles[i] != 0: last_tile = i
			if last_animals[i] != "": last_token = i
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
		if refill and (last_tiles[i] != tile_id or (solo_eject and i == last_tile)):
			_transition(row,false,last_tiles[i],tile_id,solo_eject and i == last_tile)
		if refill and (last_animals[i] != game.market_animals[i] or (solo_eject and i == last_token)):
			_transition(row,true,last_animals[i],game.market_animals[i],solo_eject and i == last_token)
		if row.picture.tile_id != tile_id:
			row.picture.tile_id = tile_id
			row.picture.queue_redraw()
			View.apply(row.tile,&"tooltip_text","")
			if tile_id > 0:
				var tile = T.get_tile(tile_id)
				View.apply(row.tile,&"tooltip_text"," · ".join(tile.habitats.map(func(h):return T.HABITAT_NAMES[h]))+"\n可安置："+"、".join(tile.wildlife.map(func(a):return T.ANIMAL_NAMES[a])))
			if hovered_row == i: _hover(i)
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
	last_turn = turns
	last_tiles = game.market_tiles.duplicate()
	last_animals = game.market_animals.duplicate()
