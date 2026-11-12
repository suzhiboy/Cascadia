extends Control

const G = preload("res://scripts/core/game_state.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const H = preload("res://scripts/core/hex.gd")
const S = preload("res://scripts/core/scorer.gd")
const Cards = preload("res://scripts/core/scoring_card_definition.gd")
const P = preload("res://scripts/ui/palette.gd")
const BoardView = preload("res://scripts/ui/board.gd")
const MarketTile = preload("res://scripts/ui/market_tile.gd")
const Sound = preload("res://scripts/ui/sound.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")
const BACKGROUND = preload("res://assets/art/wilderness.png")
const WILDLIFE = preload("res://assets/art/wildlife.png")

var game
var board
var screen: Control
var modal: Control
var status_label: Label
var sound: AudioStreamPlayer
var view_player = 0
var mode = "tile"
var selection_tile = -1
var selection_animal = -1
var independent = false
var refreshing = false
var refresh_indices: Array = []
var highlight: Array = []
var reports: Array = []
var status = "选取一组地块与动物，开始构筑你的生态世界。"
var settings = {"volume":0.6,"fullscreen":false}
var board_pan = Vector2.ZERO
var board_zoom = 1.0
var preserve_camera = false

func _ready() -> void:
	theme = P.theme()
	DisplayServer.window_set_min_size(Vector2i(1280,720))
	_load_settings()
	sound = Sound.new()
	add_child(sound)
	show_menu()
	get_tree().auto_accept_quit = false
	if "--playtest" in OS.get_cmdline_user_args():
		var runner = load("res://tests/visual_playtest.gd").new()
		add_child.call_deferred(runner)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game != null:
			game.save_game()
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			_close_modal()
		elif game != null:
			show_settings()
	if is_instance_valid(modal):
		return
	if event.keycode == KEY_Q:
		_rotate(-1)
	elif event.keycode == KEY_E:
		_rotate(1)

func _label(text: String, font_size: int = 21, color: Color = P.INK) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _heading(text: String, font_size: int = 26, color: Color = P.INK, weight: int = 680) -> Label:
	var label = _label(text,font_size,color)
	label.add_theme_font_override("font",P.font(weight))
	return label

func _wrap(text: String, font_size: int = 21, color: Color = P.INK) -> Label:
	var label = _label(text,font_size,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 50
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	if primary:
		button.theme_type_variation = "PrimaryButton"
		button.add_theme_font_override("font",P.font(620))
	return button

func _styled(button: Button, variation: String) -> Button:
	button.theme_type_variation = variation
	return button

func _chip(child: Control, variation: String = "SunkenPanel") -> PanelContainer:
	var chip = PanelContainer.new()
	chip.theme_type_variation = variation
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(child)
	return chip

func _keycap(text: String) -> PanelContainer:
	var chip = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style = P.chip(Color(1,1,1,.08),Color(P.CREAM.r,P.CREAM.g,P.CREAM.b,.35),6,8,1)
	style.border_width_bottom = 2
	chip.add_theme_stylebox_override("panel",style)
	chip.add_child(_heading(text,15,P.CREAM,600))
	return chip

func _vbox(gap: int = 12) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",gap)
	return box

func _hbox(gap: int = 12) -> HBoxContainer:
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation",gap)
	return box

func _margin(child: Control, amount: int = 24) -> MarginContainer:
	var margin = MarginContainer.new()
	for edge in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,amount)
	margin.add_child(child)
	return margin

func _spacer(parent: Control) -> void:
	var control = Control.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(control)

func _reset_screen() -> void:
	_close_modal()
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	board = null
	status_label = null
	screen = Control.new()
	screen.name = "Screen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)

func _background(parent: Control, opacity: float = 1.0) -> void:
	var image = TextureRect.new()
	image.texture = BACKGROUND
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.modulate.a = opacity
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _art(animal: String) -> TextureRect:
	var image = TextureRect.new()
	var atlas = AtlasTexture.new()
	atlas.atlas = WILDLIFE
	var index = T.ANIMALS.find(animal)
	var width = float(WILDLIFE.get_width())/5.0
	atlas.region = Rect2(index*width,70,width,WILDLIFE.get_height()-160)
	image.texture = atlas
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func show_menu() -> void:
	_reset_screen()
	_background(screen)
	var panel = PanelContainer.new()
	panel.theme_type_variation = "MenuPanel"
	panel.position = Vector2(110,130)
	panel.size = Vector2(660,790)
	screen.add_child(panel)
	var content = _vbox(18)
	panel.add_child(_margin(content,48))
	var crest = _hbox(14)
	crest.add_child(Ornament.make("logo",Vector2(46,50)))
	crest.add_child(_label("太 平 洋 西 北 · 自 然 手 记",18,P.MUTED))
	content.add_child(crest)
	var title = _label("CASCADIA",66,P.DARK)
	title.add_theme_font_override("font",P.font(640,5))
	content.add_child(title)
	content.add_child(_heading("卡斯卡迪亚之旅",36,P.DARK,600))
	var divider = HSeparator.new()
	content.add_child(divider)
	content.add_child(_wrap("一片山林，一条河流。\n让每一种生命，找到它的位置。",25))
	_spacer(content)
	content.add_child(_button("开始新的旅程",show_setup,true))
	var resume = _button("继续上次旅程",_continue_game)
	resume.disabled = not FileAccess.file_exists("user://autosave.json")
	content.add_child(resume)
	var row = _hbox()
	var help = _styled(_button("玩法说明",show_help),"QuietButton")
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(help)
	var options = _styled(_button("设置",show_settings),"QuietButton")
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(options)
	content.add_child(row)
	content.add_child(_label("1–4 位旅行者   /   20 回合   /   离线游玩",18,P.MUTED))
	var footer = _label("自然之美，始于彼此相连。",19,P.PAPER)
	footer.add_theme_color_override("font_shadow_color",Color(.05,.12,.08,.75))
	footer.add_theme_constant_override("shadow_offset_y",2)
	footer.add_theme_constant_override("shadow_outline_size",6)
	footer.position = Vector2(1330,1005)
	screen.add_child(footer)

func _open_modal(title: String, width: float = 850, height: float = 740) -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.name = "Modal"
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = ColorRect.new()
	shade.color = Color(.03,.1,.07,.72)
	modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = PanelContainer.new()
	panel.theme_type_variation = "ModalPanel"
	modal.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -width*.5
	panel.offset_right = width*.5
	panel.offset_top = -height*.5
	panel.offset_bottom = height*.5
	var body = _vbox(18)
	panel.add_child(_margin(body,30))
	var header = _hbox(12)
	header.add_child(Ornament.make("hex",Vector2(18,20),P.GOLD))
	header.add_child(_heading(title,30,P.DARK))
	_spacer(header)
	header.add_child(_styled(_button("关闭",_close_modal),"QuietButton"))
	body.add_child(header)
	return body

func _close_modal() -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null

func show_setup() -> void:
	var body = _open_modal("一起出发",930,840)
	body.add_child(_wrap("选择同行人数与本局计分卡。初次游玩推荐使用全部 A 卡。",22,P.MUTED))
	var count = OptionButton.new()
	for text in ["单人 · 独行之旅","2 人 · 同机轮流","3 人 · 同机轮流","4 人 · 同机轮流"]:
		count.add_item(text)
	count.custom_minimum_size.y = 55
	body.add_child(count)
	var names = []
	var name_grid = GridContainer.new()
	name_grid.columns = 2
	name_grid.add_theme_constant_override("h_separation",16)
	name_grid.add_theme_constant_override("v_separation",10)
	body.add_child(name_grid)
	for i in range(4):
		var input = LineEdit.new()
		input.placeholder_text = "旅行者 %d" % (i+1)
		input.max_length = 12
		input.custom_minimum_size = Vector2(390,50)
		input.visible = i == 0
		input.add_theme_stylebox_override("normal",_player_field(P.PLAYERS[i]))
		name_grid.add_child(input)
		names.append(input)
	count.item_selected.connect(func(index):
		for i in range(4):
			names[i].visible = i <= index)
	body.add_child(_heading("本局野生动物计分卡",23))
	var choices = {}
	var cards_row = _hbox(14)
	for animal in T.ANIMALS:
		var column = _vbox(4)
		var frame = _chip(column,"CardPanel")
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var art = _art(animal)
		art.custom_minimum_size = Vector2(110,108)
		column.add_child(art)
		var label = _heading(T.ANIMAL_NAMES[animal],20,P.INK,620)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		var choice = OptionButton.new()
		for text in ["A","B","C","D","随机"]:
			choice.add_item(text)
		column.add_child(choice)
		choices[animal] = choice
		cards_row.add_child(frame)
	body.add_child(cards_row)
	var presets = _hbox()
	presets.add_child(_styled(_button("全部 A 卡",func():
		for choice in choices.values(): choice.select(0)),"QuietButton"))
	presets.add_child(_styled(_button("全部随机",func():
		for choice in choices.values(): choice.select(4)),"QuietButton"))
	body.add_child(presets)
	_spacer(body)
	body.add_child(_button("进入山林",func():
		var config = {"count":count.selected+1,"names":[],"cards":{}}
		for input in names: config.names.append(input.text)
		for animal in T.ANIMALS: config.cards[animal] = ["A","B","C","D","random"][choices[animal].selected]
		start_game(config),true))

# Name field with a stripe in that traveller's colour, matching their tab in game.

func _player_field(color: Color) -> StyleBoxFlat:
	var style = P.box(Color("fffaf0"),8,P.LINE)
	style.border_width_left = 6
	style.border_color = color.darkened(.1)
	return style

func start_game(config: Dictionary) -> void:
	game = G.new()
	game.start(config)
	view_player = 0
	reports.clear()
	highlight.clear()
	board = null
	preserve_camera = false
	_reset_selection()
	status = "选取一组地块与动物，开始构筑你的生态世界。"
	_save()
	_render_game()

func _continue_game() -> void:
	var resumed = G.new()
	if not resumed.load_game():
		var body = _open_modal("无法读取存档",650,310)
		body.add_child(_wrap("存档无法读取。可以关闭此窗口并开始新的旅程。"))
		return
	game = resumed
	view_player = game.active
	highlight.clear()
	_reset_selection()
	mode = "animal" if not game.pending.is_empty() and game.pending.tile_pos != null else "tile"
	status = "旅程已恢复，继续上次的选择。"
	preserve_camera = false
	reports = S.game_scores(game) if game.finished else []
	_render_game()

func _reset_selection() -> void:
	selection_tile = -1
	selection_animal = -1
	independent = false
	refreshing = false
	refresh_indices.clear()
	mode = "tile"

func _save() -> void:
	if game.save_game() != OK:
		status = "自动存档写入失败，请检查磁盘空间。"

func _remember_camera() -> void:
	if is_instance_valid(board):
		board_pan = board.pan
		board_zoom = board.zoom
		preserve_camera = true

func _render_game() -> void:
	_remember_camera()
	_reset_screen()
	var background = ColorRect.new()
	background.color = P.DARK
	screen.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Decoration lives inside the background node so the child order of screen is unchanged.
	_background(background,.55)
	var tint = ColorRect.new()
	tint.color = Color(P.DARK.r,P.DARK.g,P.DARK.b,.86)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(tint)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root = _vbox(16)
	var outer = _margin(root,24)
	screen.add_child(outer)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header = _hbox(14)
	var brand = _hbox(12)
	brand.custom_minimum_size.x = 300
	brand.add_child(Ornament.make("logo",Vector2(44,48)))
	var wordmark = _vbox(0)
	var name_label = _label("CASCADIA",24,P.CREAM)
	name_label.add_theme_font_override("font",P.font(640,4))
	wordmark.add_child(name_label)
	wordmark.add_child(_label("卡斯卡迪亚之旅",15,P.GOLD_LIGHT))
	brand.add_child(wordmark)
	header.add_child(brand)
	for i in range(game.players.size()):
		var player = game.players[i]
		var caption = ("● " if i == game.active and not game.finished else "")+player.name
		var tab = _button(caption,func():_view(i))
		tab.custom_minimum_size = Vector2(210,50)
		tab.clip_text = true
		tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		P.apply_tab(tab,P.PLAYERS[i%P.PLAYERS.size()],i == view_player)
		if i == view_player:
			tab.add_theme_font_override("font",P.font(640))
		tab.tooltip_text = "查看 %s 的生态版图" % player.name
		header.add_child(tab)
	_spacer(header)
	header.add_child(_styled(_button("规则",show_help),"GhostButton"))
	header.add_child(_styled(_button("设置",show_settings),"GhostButton"))
	header.add_child(_styled(_button("主菜单",func():
		_save()
		show_menu()),"GhostButton"))
	root.add_child(header)
	var body = _hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_build_market(body)
	var center = _vbox(10)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var viewed = game.players[view_player]
	var caption = _hbox(10)
	caption.add_child(Ornament.make("hex",Vector2(20,22),P.PLAYERS[view_player%P.PLAYERS.size()]))
	caption.add_child(_heading(viewed.name+" 的生态版图",25,P.CREAM,640))
	_spacer(caption)
	caption.add_child(Ornament.make("leaf",Vector2(24,26),P.CREAM,P.MOSS))
	caption.add_child(_label("自然标记 %d" % int(viewed.nature),19,P.CREAM))
	var divider = VSeparator.new()
	divider.add_theme_stylebox_override("separator",_rule(Color(P.CREAM.r,P.CREAM.g,P.CREAM.b,.25)))
	caption.add_child(divider)
	caption.add_child(_label("回合",19,P.SAGE))
	caption.add_child(_heading("%d / 20" % int(viewed.turns),21,P.CREAM,640))
	var trail = Ornament.make("progress",Vector2(190,16),P.GOLD_LIGHT,P.CREAM)
	trail.value = int(viewed.turns)
	caption.add_child(trail)
	center.add_child(caption)
	board = BoardView.new()
	board.cells = game.preview_board() if view_player == game.active else game.players[view_player].board
	board.interactive = view_player == game.active and not game.finished
	board.highlight = highlight
	if board.interactive and not game.pending.is_empty():
		board.frontier = game.frontier() if mode == "tile" else []
		board.legal_animals = game.legal_animal_cells() if mode == "animal" else []
		if game.pending.tile_pos != null:
			board.preview_key = H.key(Vector2i(game.pending.tile_pos[0],game.pending.tile_pos[1]))
		# Presentation only: a translucent copy of the pending piece follows the cursor.
		board.ghost_tile = int(game.pending.tile) if mode == "tile" else 0
		board.ghost_rotation = int(game.pending.rotation)
		board.ghost_animal = str(game.pending.animal) if mode == "animal" else ""
	board.cell_clicked.connect(_board_click)
	center.add_child(board)
	if preserve_camera:
		board.pan = board_pan
		board.zoom = board_zoom
	else:
		board.call_deferred("center_board")
	var navigation = _hbox(8)
	for hint in [["滚轮","缩放"],["中键","拖动"],["Q","E","旋转"]]:
		for i in range(hint.size()-1):
			navigation.add_child(_keycap(hint[i]))
		navigation.add_child(_label(hint[-1],16,P.SAGE))
		var gap = Control.new()
		gap.custom_minimum_size.x = 10
		navigation.add_child(gap)
	_spacer(navigation)
	navigation.add_child(_styled(_button("居中版图",func():board.center_board()),"GhostButton"))
	center.add_child(navigation)
	_build_cards(body)
	_build_actions(root)

func _rule(color: Color) -> StyleBoxLine:
	var line = StyleBoxLine.new()
	line.color = color
	line.vertical = true
	line.grow_begin = -8
	line.grow_end = -8
	return line

func _view(index: int) -> void:
	view_player = index
	highlight.clear()
	board = null
	preserve_camera = false
	_render_game()

func _build_market(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 310
	parent.add_child(panel)
	var content = _vbox(10)
	panel.add_child(_margin(content,8))
	content.add_child(_heading("山林市集",27,P.DARK))
	content.add_child(_label("选一块栖息地 · 邀一位新邻居",16,P.MUTED))
	if independent or refreshing:
		var notice = _wrap("自由搭配：分别点选地块与动物" if independent else "更换动物：点选要换掉的动物",16,P.RUST)
		content.add_child(_chip(notice))
	var locked = game.finished or not game.pending.is_empty()
	for i in range(4):
		var row = _hbox(8)
		var paired = selection_tile == i and selection_animal == i
		var badge = Ornament.make("hex",Vector2(24,26),P.GOLD_DEEP if paired else Color(P.DARK.r,P.DARK.g,P.DARK.b,.75),P.CREAM,str(i+1))
		row.add_child(badge)
		var tile_button = _button("",func():_market_pick(i,false))
		tile_button.custom_minimum_size = Vector2(140,102)
		tile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile_button.disabled = locked
		if selection_tile == i:
			tile_button.theme_type_variation = "ActiveButton"
		var picture = MarketTile.new()
		picture.tile_id = int(game.market_tiles[i])
		if locked: picture.modulate.a = .5
		tile_button.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if picture.tile_id > 0:
			var tile = T.get_tile(picture.tile_id)
			tile_button.tooltip_text = " · ".join(tile.habitats.map(func(h):return T.HABITAT_NAMES[h]))+"\n可安置："+"、".join(tile.wildlife.map(func(a):return T.ANIMAL_NAMES[a]))
		row.add_child(tile_button)
		var animal_button = _button("",func():_market_pick(i,true))
		animal_button.custom_minimum_size = Vector2(90,102)
		animal_button.disabled = locked
		if i in refresh_indices:
			animal_button.theme_type_variation = "MarkedButton"
		elif selection_animal == i:
			animal_button.theme_type_variation = "ActiveButton"
		var token = MarketTile.new()
		token.show_token = true
		token.animal = game.market_animals[i]
		if locked: token.modulate.a = .5
		animal_button.add_child(token)
		token.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		animal_button.tooltip_text = T.ANIMAL_NAMES.get(token.animal,"")
		row.add_child(animal_button)
		content.add_child(row)
	if game.config.count == 1:
		content.add_child(_wrap("单人：最下方剩余地块与动物将在回合结束时离场。",16,P.MUTED))
	else:
		content.add_child(_label("剩余地块  %d" % game.deck.size(),17,P.MUTED))
	_spacer(content)
	var take = _button("确认更换动物" if refreshing else ("自由搭配 · 确认" if independent else "确认选取"),func():
		if refreshing:
			var error = game.refresh(refresh_indices,true)
			if error.is_empty(): _reset_selection()
			_action(error)
		else: _draft(),true)
	take.disabled = (refresh_indices.is_empty() if refreshing else selection_tile < 0 or selection_animal < 0) or not game.pending.is_empty() or game.finished
	content.add_child(take)
	var free = _styled(_button("更换三枚同种动物",func():_action(game.refresh(game.triplicate(),false))),"QuietButton")
	free.disabled = game.triplicate().is_empty()
	content.add_child(free)
	var nature = _styled(_button("使用自然标记  ·  %d" % int(game.players[game.active].nature),show_nature),"QuietButton")
	nature.disabled = game.players[game.active].nature < 1 or not game.pending.is_empty() or game.finished
	content.add_child(nature)

func _build_cards(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 330
	parent.add_child(panel)
	var content = _vbox(10)
	panel.add_child(_margin(content,8))
	content.add_child(_heading("野生动物手记",27,P.DARK))
	content.add_child(_label("点击卡片，查看完整计分规则",16,P.MUTED))
	for animal in T.ANIMALS:
		var card = game.config.cards[animal]
		var button = _styled(_button("",func():show_card(animal,card)),"CardButton")
		button.custom_minimum_size = Vector2(285,115)
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var row = _hbox(6)
		var margin = _margin(row,10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art = _art(animal)
		art.custom_minimum_size.x = 101
		row.add_child(art)
		var info = _vbox(2)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		var title = _hbox(8)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(_heading(T.ANIMAL_NAMES[animal],22,P.INK,650))
		var letter = _chip(_heading(card,15,P.CREAM,700))
		letter.add_theme_stylebox_override("panel",P.chip(P.ANIMALS[animal].darkened(.15),P.ANIMALS[animal].darkened(.3),6,7,0))
		title.add_child(letter)
		info.add_child(title)
		info.add_child(_label(Cards.title(animal,card),16,P.MUTED))
		if game.finished:
			info.add_child(_heading("%d 分" % reports[view_player].wildlife[animal].points,22,P.GOLD_DEEP,700))
		row.add_child(info)
		content.add_child(button)
	if game.finished:
		content.add_child(_button("查看完整计分",show_results,true))
	else:
		content.add_child(_wrap("栖息地连成片，动物各有所爱。\n计分在旅程结束后进行。",16,P.MUTED))

# Turn steps: pick, place habitat, place wildlife, confirm (habitat and wildlife in any order).

func _stepper() -> HBoxContainer:
	var row = _hbox(6)
	var picked = not game.pending.is_empty()
	var done = [picked,picked and game.pending.tile_pos != null,picked and (game.pending.animal_pos != null or game.pending.discarded),false]
	var current = 0
	if picked:
		current = 3 if game.ready_to_commit() else (1 if mode == "tile" else 2)
	var names = ["选取","地块","动物","确认"]
	for i in range(4):
		var chip = _hbox(6)
		var is_current = i == current
		var finished_step = done[i] and not is_current
		var fill = P.DARK if is_current else (P.MOSS if finished_step else Color(0,0,0,0))
		var mark_fill = P.GOLD if is_current else (P.CREAM if finished_step else Color(P.MUTED.r,P.MUTED.g,P.MUTED.b,.35))
		var mark_ink = P.DARK if is_current else (P.MOSS if finished_step else P.PAPER)
		var mark = Ornament.make("check" if finished_step else "hex",Vector2(20,22),mark_fill,mark_ink,str(i+1))
		mark.font_size = 13
		chip.add_child(mark)
		chip.add_child(_heading(names[i],17,P.CREAM if is_current or finished_step else P.MUTED,650 if is_current else 520))
		var holder = _chip(chip)
		holder.add_theme_stylebox_override("panel",P.chip(fill,P.DARK if is_current else (P.MOSS if finished_step else P.LINE),14,10,3))
		row.add_child(holder)
		if i < 3:
			row.add_child(_label("›",18,Color(P.MUTED.r,P.MUTED.g,P.MUTED.b,.6)))
	return row

func _build_actions(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.theme_type_variation = "BarPanel"
	parent.add_child(panel)
	var row = _hbox(12)
	panel.add_child(row)
	var information = _vbox(4)
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information.alignment = BoxContainer.ALIGNMENT_CENTER
	if game.finished:
		information.add_child(_heading("旅程完成  ·  %d 分" % reports[view_player].total,24,P.DARK))
	elif view_player != game.active:
		information.add_child(_heading("正在查看其他旅行者的版图",24,P.DARK))
	else:
		information.add_child(_stepper())
	status_label = _wrap(status,17,P.MUTED)
	information.add_child(status_label)
	row.add_child(information)
	if game.finished:
		row.add_child(_button("查看计分",show_results))
		row.add_child(_button("再来一局",show_setup,true))
	elif view_player != game.active:
		row.add_child(_button("返回当前玩家",func():_view(game.active),true))
	elif not game.pending.is_empty():
		var hand = _hbox(2)
		var pending_tile = MarketTile.new()
		pending_tile.tile_id = int(game.pending.tile)
		pending_tile.tile_rotation = int(game.pending.rotation)
		pending_tile.custom_minimum_size = Vector2(95,90)
		hand.add_child(pending_tile)
		var pending_animal = MarketTile.new()
		pending_animal.show_token = true
		pending_animal.animal = game.pending.animal
		pending_animal.custom_minimum_size = Vector2(55,70)
		pending_animal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hand.add_child(pending_animal)
		row.add_child(_chip(hand))
		row.add_child(VSeparator.new())
		var tile_mode = _button("放地块",func():mode="tile";_render_game())
		var animal_mode = _button("放动物",func():mode="animal";_render_game())
		(tile_mode if mode == "tile" else animal_mode).theme_type_variation = "ActiveButton"
		row.add_child(tile_mode)
		row.add_child(animal_mode)
		row.add_child(_button("↶ Q",func():_rotate(-1)))
		row.add_child(_button("E ↷",func():_rotate(1)))
		row.add_child(VSeparator.new())
		row.add_child(_styled(_button("放归动物",func():
			game.discard_animal()
			_action("")),"QuietButton"))
		row.add_child(_styled(_button("撤回摆放",func():
			game.clear_preview()
			mode="tile"
			_action("")),"QuietButton"))
		row.add_child(VSeparator.new())
		var confirm = _button("完成回合",_commit,true)
		confirm.custom_minimum_size.x = 150
		confirm.disabled = not game.ready_to_commit()
		row.add_child(confirm)
	# Keep bar buttons at their natural height instead of stretching to the bar.
	for child in row.get_children():
		if child is Button:
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			child.custom_minimum_size.y = 54

func _market_pick(index: int, is_animal: bool) -> void:
	if game.finished or not game.pending.is_empty(): return
	if view_player != game.active:
		view_player = game.active
		board = null
		preserve_camera = false
	if refreshing:
		if is_animal:
			if index in refresh_indices: refresh_indices.erase(index)
			else: refresh_indices.append(index)
	elif independent:
		if is_animal: selection_animal = index
		else: selection_tile = index
	else:
		selection_tile = index
		selection_animal = index
	status = "选择完成后，点击「确认选取」。"
	_render_game()

func _draft() -> void:
	var error = game.draft(selection_tile,selection_animal)
	if error.is_empty():
		_reset_selection()
		status = "点击虚线空格放地块；也可先切换到「放动物」。"
	_action(error)

func _board_click(cell: Vector2i) -> void:
	if game.pending.is_empty():
		_message("请先从左侧市集选取一组地块与动物。")
		return
	var error = ""
	if mode == "tile":
		error = game.place_tile(cell,int(game.pending.rotation))
		if error.is_empty():
			mode = "animal"
			status = "点击带白圈的栖息地安置动物，也可选择放归。"
	else:
		error = game.place_animal(cell)
		if error.is_empty():
			mode = "tile" if game.pending.tile_pos == null else "animal"
			status = "地块与动物均可继续调整。满意后点击「完成回合」。" if game.ready_to_commit() else "动物已选择栖息地，接着摆放地块。"
	_action(error)

func _rotate(amount: int) -> void:
	if game == null or not is_instance_valid(board) or game.finished or game.pending.is_empty() or view_player != game.active:
		return
	game.pending.rotation = posmod(int(game.pending.rotation)+amount,6)
	_action("")
	board.rotation_offset = -amount*PI/3.0

func _action(error: String) -> void:
	if not error.is_empty():
		_message(error)
		return
	_save()
	sound.tap()
	_render_game()

func _message(text: String) -> void:
	status = text
	if is_instance_valid(status_label):
		status_label.text = text
		status_label.add_theme_color_override("font_color",Color("a45333"))

func _commit() -> void:
	var error = game.commit_turn()
	if not error.is_empty():
		_message(error)
		return
	sound.tap(1)
	_save()
	_reset_selection()
	highlight.clear()
	view_player = game.active
	board = null
	preserve_camera = false
	status = game.players[game.active].name+"，轮到你了。选择下一组地块与动物。"
	if game.finished:
		reports = S.game_scores(game)
		status = "点击计分项目，可在版图上查看得分依据。"
	_render_game()
	if game.finished: show_results()

func show_nature() -> void:
	var body = _open_modal("自然标记",770,480)
	var intro = _hbox(14)
	intro.add_child(Ornament.make("leaf",Vector2(40,44),P.MOSS,P.CREAM))
	intro.add_child(_wrap("每枚自然标记可帮助你选择更合适的伙伴。未使用的标记在终局各值 1 分。",23))
	body.add_child(intro)
	body.add_child(_button("自由搭配 · 任选一块地与一枚动物",func():
		_reset_selection()
		independent=true
		status="分别点击一个地块与一枚动物。跨组选取消耗 1 枚自然标记。"
		_render_game(),true))
	body.add_child(_button("更换动物 · 选择任意数量",func():
		_reset_selection()
		refreshing=true
		status="点击市集中想更换的动物，再点击「确认更换动物」。"
		_render_game()))
	body.add_child(_wrap("更换会揭示新动物，确认后无法撤回。可在同一回合多次使用自然标记。",18,P.MUTED))

func show_card(animal: String, card: String) -> void:
	var body = _open_modal(T.ANIMAL_NAMES[animal]+" · "+card+"  "+Cards.title(animal,card),820,710)
	var art = _art(animal)
	art.custom_minimum_size.y = 250
	var frame = _chip(art,"CardPanel")
	frame.size_flags_vertical = Control.SIZE_FILL
	body.add_child(frame)
	body.add_child(_wrap(Cards.description(animal,card),24))
	if animal == "elk" and card == "B":
		body.add_child(_wrap("三只组成互相邻接的紧密三角；四只组成两个共享边的三角形。",20,P.MUTED))
	if animal == "salmon":
		body.add_child(_wrap("相连鱼群中出现任何一只邻接三只或更多鲑鱼，整个鱼群失效。三个相连的三角形鱼群有效。",19,P.MUTED))
	_spacer(body)
	if game.finished:
		body.add_child(_button("查看本项得分 · %d 分" % reports[view_player].wildlife[animal].points,func():_highlight_score(view_player,animal,true),true))

func _highlight_score(player: int, category: String, is_wildlife: bool) -> void:
	view_player = player
	highlight.clear()
	var points = 0
	if is_wildlife:
		var part = reports[player].wildlife[category]
		points = part.points
		for group in part.groups:
			for k in group.cells:
				if k not in highlight: highlight.append(k)
		status = "%s：%d 分。金色边框显示参与计分的地块。" % [T.ANIMAL_NAMES[category],points]
	else:
		var part = reports[player].habitats[category]
		highlight = part.cells.duplicate()
		status = "%s：最大相连区域 %d 分，奖励 %d 分。" % [T.HABITAT_NAMES[category],part.points,part.bonus]
	board = null
	preserve_camera = false
	_render_game()

func show_results() -> void:
	var body = _open_modal("旅程的收获",1150,950)
	var winners_list = S.winners(game,reports)
	var names = winners_list.map(func(i):return game.players[i].name)
	var heading = " · ".join(names)+("  并列获胜" if names.size()>1 else "  获胜")
	if game.players.size() == 1:
		var total = reports[0].total
		heading = "你的生态世界 · %d 分" % total
	var banner = _wrap(heading,27,P.GOLD_DEEP)
	banner.add_theme_font_override("font",P.font(680))
	body.add_child(banner)
	body.add_child(_label("点击动物或生境得分，查看版图上的计分依据。",18,P.MUTED))
	var grid = GridContainer.new()
	grid.columns = game.players.size()+1
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",5)
	grid.add_child(_heading("计分项目",20,P.MUTED,600))
	for i in range(game.players.size()):
		var player = game.players[i]
		var label = _heading(player.name,21,P.INK,640)
		label.clip_text = true
		label.custom_minimum_size.x = 145
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = player.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stripe = P.chip(Color(0,0,0,0),P.PLAYERS[i%P.PLAYERS.size()].darkened(.15),0,0,2)
		stripe.set_border_width_all(0)
		stripe.border_width_bottom = 4
		label.add_theme_stylebox_override("normal",stripe)
		grid.add_child(label)
	for animal in T.ANIMALS:
		grid.add_child(_label(T.ANIMAL_NAMES[animal]+" "+game.config.cards[animal],20))
		for i in range(game.players.size()):
			var button = _button(str(reports[i].wildlife[animal].points),func():_highlight_score(i,animal,true))
			button.custom_minimum_size.y = 39
			_compact_score_button(button)
			grid.add_child(button)
	for habitat in T.HABITATS:
		grid.add_child(_label(T.HABITAT_NAMES[habitat],20))
		for i in range(game.players.size()):
			var part = reports[i].habitats[habitat]
			var button = _button("%d + %d" % [part.points,part.bonus],func():_highlight_score(i,habitat,false))
			button.custom_minimum_size.y = 39
			_compact_score_button(button)
			grid.add_child(button)
	grid.add_child(_label("剩余自然标记",20))
	for report in reports:
		var nature = _label(str(report.nature),22)
		nature.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(nature)
	grid.add_child(_heading("总分",26,P.DARK))
	for i in range(reports.size()):
		var total = _heading(str(reports[i].total),35,P.GOLD_DEEP if i in winners_list else P.DARK,720)
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(total)
	body.add_child(grid)
	_spacer(body)
	var row = _hbox()
	row.add_child(_styled(_button("回看生态版图",_close_modal),"QuietButton"))
	_spacer(row)
	row.add_child(_button("再来一局",show_setup,true))
	body.add_child(row)

func _compact_score_button(button: Button) -> void:
	button.theme_type_variation = "ScoreButton"

func show_help() -> void:
	var body = _open_modal("山林旅行指南",1000,900)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var content = _vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var sections = [
		["01  选一组，放两次","从四组市集中选取一个地块和一枚动物。地块须与已有地块共边，地形无需匹配。动物须放在有对应图标、且未入住的地块；可以是新地块，也可以是旧地块。地块与动物可按任意顺序摆放。"],
		["02  为动物找到家","每个地块最多一枚动物。如果没有合适的栖息地，或你不想放置，可以选择「放归动物」，它会回到袋中。单一动物图标、带叶形标记的关键地块入住后，获得一枚自然标记。"],
		["03  自然标记与动物过剩","花一枚自然标记可跨组自由搭配，或更换市集任意数量动物。同回合可多次使用。四枚同种动物会自动更换；三枚同种可每回合免费更换一次。"],
		["04  让山林彼此相连","地块可旋转六个方向。相邻且地形接边一致，才形成连续生境。每种生境的最大相连区域，每格 1 分；动物另按本局五张计分卡计算。点击右侧卡片可看规则。"],
		["05  独行与同行","单人回合结束：从剩余地块、动物两列各移除最下方一个，其余下移，上方补新组件。多人只补空位，轮流行动。每位旅行者恰好进行 20 回合。"],
		["06  终局计分","加总五种动物、五种最大生境、奖励与剩余自然标记。单人每种生境达到 7 格奖励 2 分。两人最大生境得 2 分，平手各 1 分。三四人第一得 3 分，第二得 1 分；两人并列第一各 2 分，三人以上并列各 1 分，第二名并列不得分。总分平手比较剩余自然标记，仍相同则共享胜利。"],
		["操作与存档","点击落子；Q / E 每次旋转 60°；滚轮缩放；中键拖动；「居中版图」找回全景。落子预览可撤回，随机刷新不可撤回。每次确认的操作都会自动保存，主菜单可继续。"]
	]
	for i in range(sections.size()):
		var section = sections[i]
		var title = _hbox(10)
		title.add_child(Ornament.make("hex",Vector2(16,18),P.GOLD))
		title.add_child(_heading(section[0],24,P.DARK))
		content.add_child(title)
		var text = _wrap(section[1],20,P.INK)
		text.add_theme_constant_override("line_spacing",6)
		content.add_child(text)
		if i < sections.size()-1:
			var gap = Control.new()
			gap.custom_minimum_size.y = 8
			content.add_child(gap)

func show_settings() -> void:
	var body = _open_modal("旅途设置",720,470)
	body.add_child(_heading("音效音量",22,P.DARK,620))
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = .05
	slider.value = settings.volume
	slider.custom_minimum_size.y = 45
	slider.value_changed.connect(func(value):
		settings.volume=value
		AudioServer.set_bus_volume_db(0,linear_to_db(value))
		_save_settings())
	body.add_child(slider)
	var toggle = CheckButton.new()
	toggle.text = "全屏显示"
	toggle.button_pressed = settings.fullscreen
	toggle.toggled.connect(func(value):
		settings.fullscreen=value
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		_save_settings())
	body.add_child(toggle)
	body.add_child(_wrap("所有对局均保存在本机，无需联网。",19,P.MUTED))
	_spacer(body)
	body.add_child(_button("返回旅程",_close_modal,true))

func _load_settings() -> void:
	if FileAccess.file_exists("user://settings.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
		if data is Dictionary:
			settings.merge(data,true)
	AudioServer.set_bus_volume_db(0,linear_to_db(clampf(float(settings.volume),0,1)))
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save_settings() -> void:
	var file = FileAccess.open("user://settings.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(settings))
