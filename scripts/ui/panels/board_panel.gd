extends VBoxContainer

const View = preload("res://scripts/ui/view_properties.gd")
const H = preload("res://scripts/core/hex.gd")
const P = preload("res://scripts/ui/palette.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")
const BoardView = preload("res://scripts/ui/board.gd")
const Practice = preload("res://scripts/ui/first_turn_practice.gd")
const Feedback = preload("res://scripts/ui/feedback.gd")
const Preview = preload("res://scripts/ui/score_preview.gd")
const S = preload("res://scripts/core/scorer.gd")

var board = BoardView.new()
var emblem: Control
var title: Label
var nature: Label
var turns: Label
var trail: Control
var turn_total: Label
var lesson: PanelContainer
var lesson_progress: Label
var lesson_title: Label
var lesson_text: Label
var lan_phase: Label
var keyboard_hints: VBoxContainer
var gamepad_hints: VBoxContainer
var last_step := -1
var last_view := -1
var last_turn: Array = []
var manual_cameras := {}
var last_board_state: Array = []

func build(ui) -> void:
	name = "BoardPanel"
	add_theme_constant_override("separation",10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var caption = ui._hbox(10)
	emblem = Ornament.make("hex",Vector2(20,22))
	caption.add_child(emblem)
	title = ui._heading("",25,P.CREAM,640)
	caption.add_child(title)
	ui._spacer(caption)
	caption.add_child(Ornament.make("shell",Vector2(24,26),P.CREAM,P.MOSS))
	nature = ui._label("",19,P.CREAM)
	caption.add_child(nature)
	var divider = VSeparator.new()
	divider.add_theme_stylebox_override("separator",ui._rule(Color(P.CREAM.r,P.CREAM.g,P.CREAM.b,.25)))
	caption.add_child(divider)
	if not ui._practicing:
		caption.add_child(ui._label(GameLocale.text("回合"),19,P.SAGE))
		turns = ui._heading("",21,P.CREAM,640)
		caption.add_child(turns)
		trail = Ornament.make("progress",Vector2(190,16),P.GOLD_LIGHT,P.CREAM)
		caption.add_child(trail)
		turn_total = ui._heading("",21,P.GOLD_LIGHT,700)
		turn_total.name = "TurnTotal"
		turn_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		turn_total.mouse_filter = Control.MOUSE_FILTER_PASS
		turn_total.custom_minimum_size.x = 64
		turn_total.add_theme_stylebox_override("normal",Ornament.badge(P.DARK,P.GOLD))
		turn_total.hide()
		caption.add_child(turn_total)
	add_child(caption)
	if ui._practicing:
		var row = ui._hbox(18)
		lesson_progress = ui._heading("",22,P.GOLD_DEEP)
		row.add_child(lesson_progress)
		var text = ui._vbox(3)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lesson_title = ui._heading("",24,P.DARK)
		lesson_text = ui._wrap("",21,P.INK)
		text.add_child(lesson_title)
		text.add_child(lesson_text)
		row.add_child(text)
		lesson = ui._chip(ui._margin(row,6),"CardPanel")
		add_child(lesson)
	lan_phase = ui._label("",17,P.CREAM)
	add_child(lan_phase)
	board.animations = ui.settings.animations
	board.cell_clicked.connect(ui._board_click)
	board.rotation_requested.connect(ui._rotate)
	board.market_tile_dropped.connect(ui._drop_market_tile)
	add_child(board)
	var navigation = ui._hbox(8)
	keyboard_hints = ui._vbox(3)
	gamepad_hints = ui._vbox(3)
	for group in [keyboard_hints,gamepad_hints]: navigation.add_child(group)
	var camera_hint = GameLocale.text("拖海面 / 中键 / WASD 平移 · 滚轮 / + − 缩放 · F / Home 居中 · 拖市集地块摆放")
	var turn_hint = GameLocale.text("1–4 选组 · Enter 确认 · Esc 撤回 · 方向键选格 · 右键 / Shift+滚轮 / Q E 旋转")
	if not ui._practicing: turn_hint += GameLocale.text(" · Tab 得分")
	keyboard_hints.add_child(ui._label(camera_hint,16,P.SAGE))
	keyboard_hints.add_child(ui._label(turn_hint,16,P.SAGE))
	gamepad_hints.add_child(ui._label(GameLocale.text("十字键 选格 / 导航 · A 放置 / 确认 · B 撤回"),16,P.SAGE))
	gamepad_hints.add_child(ui._label(GameLocale.text("LB / RB 旋转 · Start 完成回合"),16,P.SAGE))
	ui._spacer(navigation)
	navigation.add_child(ui._styled(ui._button(GameLocale.text("居中版图"),board.center_board),"GhostButton"))
	add_child(navigation)
	Input.joy_connection_changed.connect(_joy_changed)
	_show_navigation(not Input.get_connected_joypads().is_empty())

func _joy_changed(_device: int, connected: bool) -> void:
	_show_navigation(connected or not Input.get_connected_joypads().is_empty())

func _show_navigation(using_pad: bool) -> void:
	keyboard_hints.visible = not using_pad
	gamepad_hints.visible = using_pad

func update(state: Dictionary) -> void:
	var game = state.game
	var viewed = game.players[state.view]
	View.apply(title,&"text",GameLocale.player_name(viewed.name)+GameLocale.text(" 的生态版图"))
	View.apply(nature,&"text",GameLocale.text("自然标记 %d") % int(viewed.nature))
	if turns != null:
		View.apply(turns,&"text","%d / 20" % int(viewed.turns))
		if trail.value != viewed.turns:
			trail.value = viewed.turns
			trail.queue_redraw()
	if state.practice and last_step != state.step:
		last_step = state.step
		var progress = GameLocale.text("完成") if last_step == Practice.Step.REVIEW else "%d / 6" % (last_step+1)
		View.apply(lesson_progress,&"text",GameLocale.text("首回合练习  ·  ")+progress)
		View.apply(lesson_title,&"text",GameLocale.text(Practice.LESSONS[last_step][0]))
		View.apply(lesson_text,&"text",GameLocale.text(Practice.LESSONS[last_step][1]))
		Feedback.reveal(lesson,.18)
	View.apply(lan_phase,&"visible",state.lan)
	if state.lan:
		var phase = GameLocale.text("正在选取") if game.pending.is_empty() else (GameLocale.text("等待确认") if game.ready_to_commit() else GameLocale.text("正在摆放"))
		View.apply(lan_phase,&"text",GameLocale.text("轮到 ")+GameLocale.player_name(game.players[game.active].name)+" · "+phase+GameLocale.text(" · 可自由查看版图与计分卡"))
	var turn = [game.active,game.players[game.active].turns,game.finished]
	var turn_changed = last_turn != turn
	var view_changed = last_view != state.view
	if turn_changed:
		last_turn = turn
		manual_cameras.clear()
	elif view_changed and board.camera_adjusted:
		manual_cameras[last_view] = [board.pan,board.zoom]
	if turn_changed or view_changed:
		board.set_score_preview(Callable(),board.NO_CELL,false)
		board.restore_camera(manual_cameras.get(state.view,[]))
		board.clear_cursor()
	if view_changed:
		last_view = state.view
		emblem.color = P.PLAYERS[last_view%P.PLAYERS.size()]
		emblem.queue_redraw()
	var active = state.view == game.active
	board.rotation_enabled = active and state.can_act and not game.finished and not game.pending.is_empty() and (not state.practice or game.pending.tile_pos == null)
	board.market_drop_enabled = active and state.can_act and not game.finished and game.pending.is_empty() and not state.practice and not state.independent and not state.refreshing
	var board_state = [viewed.board,game.pending if active else {},state.highlight,active,state.mode,state.step,state.can_act,game.finished,state.view,game.config.cards]
	var board_changed = last_board_state != board_state
	if board_changed:
		last_board_state = board_state.duplicate(true)
		board.cells = game.preview_board() if active else viewed.board
		board.interactive = active and not game.finished and state.can_act
		board.highlight = state.highlight.duplicate()
		var placing = board.interactive and not game.pending.is_empty()
		var tile_mode = state.mode == "tile"
		board.camera_frontier = game.frontier() if active and not game.finished and not state.practice else []
		board.frontier = board.camera_frontier if placing and tile_mode else []
		board.legal_animals = game.legal_animal_cells() if placing and not tile_mode else []
		board.preview_key = H.key(Vector2i(game.pending.tile_pos[0],game.pending.tile_pos[1])) if placing and game.pending.tile_pos != null else ""
		board.ghost_tile = int(game.pending.tile) if placing and tile_mode else 0
		board.ghost_rotation = int(game.pending.rotation) if placing else 0
		board.ghost_animal = str(game.pending.animal) if placing and not tile_mode else ""
		if state.practice:
			board.interactive = state.step in [Practice.Step.ROTATE,Practice.Step.TILE,Practice.Step.ANIMAL]
			board.emphasize_frontier = true
			board.frontier = [Practice.TARGET] if state.step in [Practice.Step.ROTATE,Practice.Step.TILE] else []
			board.legal_animals = [Practice.TARGET] if state.step == Practice.Step.ANIMAL else []
		board.placement_points = Preview.placement_points(game,board.legal_animals)
		if active and not game.pending.is_empty():
			var pending = game.pending
			var anchor = pending.animal_pos if pending.animal_pos != null else pending.tile_pos
			var position = Vector2i(anchor[0],anchor[1]) if anchor != null else board.NO_CELL
			var scores = S.game_scores(game)
			board.set_score_preview(func(tile,animal): return Preview.estimate(game,scores,tile,animal),position,pending.animal_pos != null)
		else:
			board.set_score_preview(Callable(),board.NO_CELL,false)
		board.update_cursor()
		board.queue_redraw()
	if board_changed or turn_changed or view_changed:
		board.request_fit(turn_changed or view_changed)
