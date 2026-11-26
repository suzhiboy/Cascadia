extends VBoxContainer

const View = preload("res://scripts/ui/view_properties.gd")
const H = preload("res://scripts/core/hex.gd")
const P = preload("res://scripts/ui/palette.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")
const BoardView = preload("res://scripts/ui/board.gd")
const Practice = preload("res://scripts/ui/first_turn_practice.gd")
const Feedback = preload("res://scripts/ui/feedback.gd")
const Preview = preload("res://scripts/ui/score_preview.gd")

var board = BoardView.new()
var emblem: Control
var title: Label
var nature: Label
var turns: Label
var trail: Control
var lesson: PanelContainer
var lesson_progress: Label
var lesson_title: Label
var lesson_text: Label
var lan_phase: Label
var preview: Label
var last_step := -1
var last_view := -1
var cameras := {}
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
		caption.add_child(ui._label("回合",19,P.SAGE))
		turns = ui._heading("",21,P.CREAM,640)
		caption.add_child(turns)
		trail = Ornament.make("progress",Vector2(190,16),P.GOLD_LIGHT,P.CREAM)
		caption.add_child(trail)
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
	preview = ui._wrap("",17,P.GOLD_LIGHT)
	add_child(preview)
	board.animations = ui.settings.animations
	board.cell_clicked.connect(ui._board_click)
	add_child(board)
	var navigation = ui._hbox(8)
	var hints = [["滚轮","缩放"],["中键","拖动"],["Q","E","旋转"]]
	if not ui._practicing: hints.append(["Tab","得分"])
	for hint in hints:
		for i in range(hint.size()-1): navigation.add_child(ui._keycap(hint[i]))
		navigation.add_child(ui._label(hint[-1],16,P.SAGE))
		var gap = Control.new()
		gap.custom_minimum_size.x = 10
		navigation.add_child(gap)
	ui._spacer(navigation)
	navigation.add_child(ui._styled(ui._button("居中版图",board.center_board),"GhostButton"))
	add_child(navigation)

func update(state: Dictionary) -> void:
	var game = state.game
	var viewed = game.players[state.view]
	View.apply(title,&"text",viewed.name+" 的生态版图")
	View.apply(nature,&"text","自然标记 %d" % int(viewed.nature))
	if turns != null:
		View.apply(turns,&"text","%d / 20" % int(viewed.turns))
		if trail.value != viewed.turns:
			trail.value = viewed.turns
			trail.queue_redraw()
	if state.practice and last_step != state.step:
		last_step = state.step
		var progress = "完成" if last_step == Practice.Step.REVIEW else "%d / 6" % (last_step+1)
		View.apply(lesson_progress,&"text","首回合练习  ·  "+progress)
		View.apply(lesson_title,&"text",Practice.LESSONS[last_step][0])
		View.apply(lesson_text,&"text",Practice.LESSONS[last_step][1])
		Feedback.reveal(lesson,.18)
	View.apply(lan_phase,&"visible",state.lan)
	if state.lan:
		var phase = "正在选取" if game.pending.is_empty() else ("等待确认" if game.ready_to_commit() else "正在摆放")
		View.apply(lan_phase,&"text","轮到 "+game.players[game.active].name+" · "+phase+" · 可自由查看版图与计分卡")
	var active = state.view == game.active
	var board_state = [viewed.board,game.pending if active else {},state.highlight,active,state.mode,state.step,state.can_act,game.finished,state.view,game.config.cards]
	if last_board_state != board_state:
		last_board_state = board_state.duplicate(true)
		View.apply(preview,&"visible",active and not game.pending.is_empty())
		if preview.visible: View.apply(preview,&"text",Preview.describe(game))
		board.cells = game.preview_board() if active else viewed.board
		board.interactive = active and not game.finished and state.can_act
		board.highlight = state.highlight.duplicate()
		var placing = board.interactive and not game.pending.is_empty()
		var tile_mode = state.mode == "tile"
		board.frontier = game.frontier() if placing and tile_mode else []
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
		board.queue_redraw()
	if last_view != state.view:
		if last_view >= 0: cameras[last_view] = [board.pan,board.zoom]
		last_view = state.view
		emblem.color = P.PLAYERS[last_view%P.PLAYERS.size()]
		emblem.queue_redraw()
		if cameras.has(last_view):
			board.pan = cameras[last_view][0]
			board.zoom = cameras[last_view][1]
		elif state.practice:
			board.pan = Vector2(0,-52)
			board.zoom = 1.1
		else:
			_center_new_view.call_deferred(last_view)
		board.queue_redraw()

func _center_new_view(view: int) -> void:
	if is_inside_tree() and view == last_view: board.center_board()
