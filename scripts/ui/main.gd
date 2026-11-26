extends Control

const G = preload("res://scripts/core/game_state.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const S = preload("res://scripts/core/scorer.gd")
const P = preload("res://scripts/ui/palette.gd")
const HeaderBar = preload("res://scripts/ui/panels/header_bar.gd")
const MarketPanel = preload("res://scripts/ui/panels/market_panel.gd")
const BoardPanel = preload("res://scripts/ui/panels/board_panel.gd")
const CardsPanel = preload("res://scripts/ui/panels/cards_panel.gd")
const ActionBar = preload("res://scripts/ui/panels/action_bar.gd")
const Modal = preload("res://scripts/ui/modals/modal.gd")
const ResultsModal = preload("res://scripts/ui/modals/results_modal.gd")
const CardModal = preload("res://scripts/ui/modals/card_modal.gd")
const NatureModal = preload("res://scripts/ui/modals/nature_modal.gd")
const PracticeModal = preload("res://scripts/ui/modals/practice_modal.gd")
const HelpModal = preload("res://scripts/ui/modals/help_modal.gd")
const SettingsModal = preload("res://scripts/ui/modals/settings_modal.gd")
const SetupModal = preload("res://scripts/ui/modals/setup_modal.gd")
const LobbyModal = preload("res://scripts/ui/modals/lobby_modal.gd")
const Feedback = preload("res://scripts/ui/feedback.gd")
const FocusNavigation = preload("res://scripts/ui/focus_navigation.gd")
const Practice = preload("res://scripts/ui/first_turn_practice.gd")
const Music = preload("res://scripts/ui/music.gd")
const Sound = preload("res://scripts/ui/sound.gd")
const LanSessionClass = preload("res://scripts/network/lan_session.gd")
const LanProtocol = preload("res://scripts/network/lan_protocol.gd")
const LanDiscoveryClass = preload("res://scripts/network/lan_discovery.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")
const BACKGROUND = preload("res://assets/art/tidal_islands.svg")

const RecordsModal = preload("res://scripts/ui/modals/records_modal.gd")
var records = preload("res://scripts/core/field_records.gd").new()

const AI = preload("res://scripts/ai/greedy_ai.gd")

var ai_timer = Timer.new()
var ai_steps = []
var ai_turn = []
var ai_executing = false
var game
var board
var screen: Control
var modal: Control
var status_label: Label
var sound: Sound
var music: AudioStreamPlayer
var view_player = 0:
	set(index):
		if index != view_player:
			if is_instance_valid(board):
				turn_effects.clear_view()
				board.stop_landing()
			_market_drop.clear()
		view_player = index
var mode = "tile"
var selection_tile = -1
var selection_animal = -1
var independent = false
var refreshing = false
var refresh_indices: Array = []
var highlight: Array = []
var reports: Array = []
var status = "选取一组地块与动物，开始构筑你的生态世界。"
var settings = {"language":"zh_CN","volume":0.6,"music_volume":0.35,"fullscreen":false,"animations":true,"large_text":false,"animal_names":true,"habitat_labels":true,"fast_ai":false}
var header_bar
var market_panel
var board_panel
var cards_panel
var action_bar
var turn_effects
var _focus_before_modal: Control
var _market_drop := {}
var _market_drop_request := 0
var _screen_game
var _large_text = false
var _feedback_game_id = 0
var _feedback_turns = 0
var _feedback_rng = ""
var _feedback_toast: Label
var _toast_label: Label
var _toast_tween: Tween
var _market_tokens: Array = []
var _practicing = false
var _practice_start_score: Dictionary
var lan_session
var lan_modal_body: VBoxContainer
var lan_discovery
var lan_room_list: VBoxContainer

func _ready() -> void:
	ai_timer.one_shot = true
	ai_timer.timeout.connect(_play_ai_step)
	add_child(ai_timer)
	theme = P.theme()
	DisplayServer.window_set_min_size(Vector2i(1280,720))
	_load_settings()
	sound = Sound.new()
	add_child(sound)
	music = Music.new()
	add_child(music)
	_apply_audio()
	music.play_next()
	show_menu()
	if not OS.has_feature("web") and not OS.has_feature("editor") and DisplayServer.get_name() != "headless":
		add_child(preload("res://scripts/update/check.gd").new())
	lan_session = LanSessionClass.new()
	lan_session.name = "LanSession"
	add_child(lan_session)
	lan_session.state_changed.connect(_on_lan_state_changed)
	lan_session.session_closed.connect(_on_lan_closed)
	lan_session.lobby_changed.connect(_on_lan_lobby_changed)
	lan_session.connection_changed.connect(_on_lan_connection_changed)
	lan_session.action_result.connect(_on_lan_action_result)
	lan_discovery = LanDiscoveryClass.new()
	add_child(lan_discovery)
	lan_discovery.room_found.connect(_on_lan_room_found)
	get_tree().auto_accept_quit = false
	if "--lan-test" in OS.get_cmdline_user_args():
		add_child.call_deferred(load("res://tests/lan_process_test.gd").new())
	if "--playtest" in OS.get_cmdline_user_args():
		var runner = load("res://tests/visual_playtest.gd").new()
		add_child.call_deferred(runner)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_exit_game()

func _exit_game() -> void:
	if lan_session != null and lan_session.started:
		lan_session.shutdown()
	elif game != null and not _practicing:
		game.save_game()
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion): return
	var on_board = is_instance_valid(board)
	var scores = on_board and not _practicing and event.is_action_pressed("ui_focus_next",false,true)
	if is_instance_valid(modal):
		if event.is_action_pressed("turn_undo") or (scores and modal.get_meta("live_scores",false)):
			_close_modal()
			get_viewport().set_input_as_handled()
			return
	elif scores:
		show_results()
		get_viewport().set_input_as_handled()
		return
	elif on_board and _board_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	for action in ["ui_left","ui_right","ui_up","ui_down","ui_focus_next","ui_focus_prev","ui_accept"]:
		if event.is_action_pressed(action,true):
			_prepare_focus()
			return

func _board_shortcut(event: InputEvent) -> bool:
	var holding = board.interactive and not game.pending.is_empty()
	var directions = [Vector2.LEFT,Vector2.UP,Vector2.RIGHT,Vector2.DOWN]
	for i in range(4):
		var side = ["left","up","right","down"][i]
		if event.is_action_pressed("board_pan_"+side,true):
			board.pan_by(-directions[i]*42)
			return true
		if event.is_action_pressed("board_"+side,true):
			if holding: return board.move_cursor(directions[i])
			if event is InputEventKey:
				board.pan_by(-directions[i]*42)
				return true
	if event.is_action_pressed("board_center"):
		board.center_board()
	elif event.is_action_pressed("board_zoom_in",true) or event.is_action_pressed("board_zoom_out",true):
		board.zoom_by(1 if event.is_action_pressed("board_zoom_in",true) else -1,board.size*.5)
	elif event.is_action_pressed("board_rotate_left") or event.is_action_pressed("board_rotate_right"):
		_rotate(-1 if event.is_action_pressed("board_rotate_left") else 1)
	elif event.is_action_pressed("turn_undo"):
		if not _market_drop.is_empty():
			_market_drop.clear()
		elif holding:
			_undo_placement()
		elif selection_tile >= 0 or selection_animal >= 0 or independent or refreshing:
			_reset_selection()
			_render_game()
		else:
			show_settings()
	elif event.is_action_pressed("board_place") and holding:
		return board.place_cursor()
	elif event.is_action_pressed("turn_commit") and holding and not action_bar.confirm.disabled:
		action_bar.confirm.pressed.emit()
	elif event.is_action_pressed("turn_confirm"):
		if holding and game.ready_to_commit():
			action_bar.confirm.pressed.emit()
		elif holding:
			return board.place_cursor()
		elif not market_panel.take.disabled:
			market_panel.take.pressed.emit()
			board.move_cursor(Vector2.ZERO)
		else:
			return false
	else:
		for row in range(4):
			if event.is_action_pressed("market_row_%d" % (row+1)) and not market_panel.rows[row].tile.disabled:
				_market_pick(row,refreshing)
				return true
		return false
	return true

func _prepare_focus() -> void:
	var scope = modal if is_instance_valid(modal) else screen
	if not is_instance_valid(scope): return
	var owner = get_viewport().gui_get_focus_owner()
	var has_focus = owner != null and scope.is_ancestor_of(owner) and owner.is_visible_in_tree() and not (owner is BaseButton and owner.disabled)
	if not has_focus and scope == screen and is_instance_valid(board):
		var target = action_bar.back if action_bar.back.visible else (action_bar.release if action_bar.hand.visible else market_panel.rows[0].tile)
		if target.is_visible_in_tree() and not target.disabled:
			target.grab_focus()
	FocusNavigation.update(scope)

func _queue_initial_focus() -> void:
	if not get_tree().process_frame.is_connected(_initial_focus):
		get_tree().process_frame.connect(_initial_focus,CONNECT_ONE_SHOT)

func _initial_focus() -> void:
	if is_instance_valid(modal):
		FocusNavigation.update(modal)
	elif not is_instance_valid(board) and is_instance_valid(screen):
		FocusNavigation.update(screen)

func _label(text: String, font_size: int = 21, color: Color = P.INK) -> Label:
	var label = Label.new()
	label.text = text
	label.set_meta("base_font_size",font_size)
	label.add_theme_font_size_override("font_size",font_size+ (2 if settings.large_text else 0))
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
	button.pressed.connect(sound.play.bind("ui_click"))
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
	ai_timer.stop()
	ai_steps.clear()
	ai_turn.clear()
	_close_modal()
	_screen_game = null
	_feedback_toast = null
	_market_tokens = []
	_market_drop.clear()
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
	image.texture = load("res://assets/art/plates/%s.png" % animal)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func show_menu() -> void:
	if _practicing:
		_practicing = false
		game = null
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
	crest.add_child(_label(GameLocale.text("潮 间 带 · 观 测 手 记"),18,P.MUTED))
	content.add_child(crest)
	var title = _label("TIDETRACE ISLES",49,P.DARK)
	title.add_theme_font_override("font",P.font(640,5))
	content.add_child(title)
	if not TranslationServer.get_locale().begins_with("en"):
		content.add_child(_heading(GameLocale.text("潮痕群岛"),36,P.DARK,600))
	var divider = HSeparator.new()
	content.add_child(divider)
	content.add_child(_wrap(GameLocale.text("退潮后，礁石与泥滩渐渐露出。\n沿着潮线，为五种动物留下栖身之处。"),25))
	_spacer(content)
	var journeys = _hbox(12)
	for button in [_button(GameLocale.text("开始新的旅程"),show_setup,true),_button(GameLocale.text("每日挑战"),_show_daily)]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		journeys.add_child(button)
	content.add_child(journeys)
	var notes = _hbox(12)
	for button in [_styled(_button(GameLocale.text("首回合练习"),_start_practice),"ActiveButton"),_button(GameLocale.text("调查记录"),_show_records)]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		notes.add_child(button)
	content.add_child(notes)
	if not OS.has_feature("web"):
		content.add_child(_button(GameLocale.text("局域网联机"),show_lan_lobby))
	var resume = _button(GameLocale.text("继续上次旅程"),_continue_game)
	resume.disabled = not FileAccess.file_exists("user://autosave.json")
	content.add_child(resume)
	var row = _hbox()
	var help = _styled(_button(GameLocale.text("玩法说明"),show_help),"QuietButton")
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(help)
	var options = _styled(_button(GameLocale.text("设置"),show_settings),"QuietButton")
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(options)
	var exit_button = _styled(_button(GameLocale.text("退出游戏"),_exit_game),"QuietButton")
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(exit_button)
	content.add_child(row)
	content.add_child(_label(GameLocale.text("1–4 位旅行者   /   20 回合   /   离线游玩"),18,P.MUTED))
	var footer = _label(GameLocale.text("低潮调查 · 群岛生态记录"),19,P.PAPER)
	footer.add_theme_color_override("font_shadow_color",Color(.05,.12,.08,.75))
	footer.add_theme_constant_override("shadow_offset_y",2)
	footer.add_theme_constant_override("shadow_outline_size",6)
	footer.position = Vector2(1330,1005)
	screen.add_child(footer)
	_queue_initial_focus()

func _open_modal(title: String, width: float = 850, height: float = 740, dialog = null) -> VBoxContainer:
	_close_modal()
	_focus_before_modal = get_viewport().gui_get_focus_owner()
	modal = dialog if dialog != null else Modal.new()
	modal.name = "Modal"
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_queue_initial_focus()
	return modal.frame(self,title,width,height)

func _close_modal() -> void:
	if not is_instance_valid(modal): return
	var apply_size = modal.get_meta("comfort",false)
	lan_modal_body = null
	lan_room_list = null
	remove_child(modal)
	modal.queue_free()
	modal = null
	if is_instance_valid(_focus_before_modal) and _focus_before_modal.is_visible_in_tree():
		_focus_before_modal.grab_focus()
	_focus_before_modal = null
	if apply_size: _refresh_comfort_screen.call_deferred()
	_schedule_ai()

func _refresh_comfort_screen() -> void:
	if is_instance_valid(modal): return
	if is_instance_valid(board): _render_game()
	else: show_menu()

func _show_daily(date: String = "") -> void:
	RecordsModal.new().open_daily(self,Time.get_date_string_from_system() if date.is_empty() else date)

func _show_records() -> void:
	RecordsModal.new().open_stats(self)

func show_setup() -> void:
	SetupModal.new().open(self)

func show_lan_lobby() -> void:
	LobbyModal.new().open(self)

func _render_lan_lobby() -> void:
	if is_instance_valid(modal) and modal is LobbyModal: modal.render_lobby()

func _on_lan_lobby_changed(data: Dictionary) -> void:
	if lan_session.is_host() and lan_discovery != null:
		lan_discovery.start_announce(data)
	if is_instance_valid(lan_modal_body):
		status = GameLocale.text("已连接 %d / %d 位旅行者。") % [data.get("slots",[]).filter(func(s):return s.connected).size(),int(data.get("count",2))]
		_render_lan_lobby()

func _on_lan_room_found(room: Dictionary) -> void:
	if not is_instance_valid(lan_room_list) or not is_instance_valid(lan_modal_body) or lan_session.started:
		return
	var key = str(room.get("room_id", room.get("address", "")))
	for child in lan_room_list.get_children():
		if child.get_meta("room_key", "") == key:
			return
	var address = str(room.get("address", "127.0.0.1"))
	var port = int(room.get("port", LanProtocol.DEFAULT_GAME_PORT))
	var button = _button(GameLocale.text("加入  %s  ·  %s/%s") % [str(room.get("host_name", GameLocale.text("房主"))),int(room.get("joined", 0)),int(room.get("count", 2))],func():
		lan_session.join_lobby(address,port,GameLocale.text("旅行者"),1)
		status = GameLocale.text("正在连接房间……")
		_render_lan_lobby())
	button.set_meta("room_key",key)
	lan_room_list.add_child(button)

func _on_lan_connection_changed(kind: String, _details: Dictionary) -> void:
	if kind != "connected": _market_drop.clear()
	status = {"connected":GameLocale.text("已连接房主，等待开局。"),"reconnecting":GameLocale.text("连接中断，正在尝试重连（最多 120 秒）。"),"paused":GameLocale.text("当前玩家断线，等待重连。")}.get(kind,GameLocale.text("正在连接……"))
	if is_instance_valid(lan_modal_body):
		_render_lan_lobby()

func _on_lan_state_changed(snapshot: Dictionary, _revision: int) -> void:
	var first = not is_instance_valid(board)
	if first or game == null: game = G.new()
	game.restore(snapshot)
	if first:
		_close_modal()
		lan_modal_body = null
		view_player = lan_session.local_seat()
		_reset_selection()
	if game.pending.is_empty(): _reset_selection()
	if game.finished: reports = S.game_scores(game)
	status = GameLocale.text("轮到 ")+GameLocale.player_name(game.players[game.active].name)+" · "+(GameLocale.text("请选择地块与动物。") if game.pending.is_empty() else GameLocale.text("正在摆放，可等待或查看其他版图。"))
	_render_game()
	if _market_drop.is_empty(): return
	if not lan_session.can_control_player(game.active) or view_player != game.active:
		_market_drop.clear()
	elif not game.pending.is_empty():
		var dropped = _market_drop.duplicate()
		_market_drop.clear()
		if game.pending.tile_index == dropped.market_row and game.pending.animal_index == dropped.market_row and game.pending.tile == dropped.tile and game.pending.animal == dropped.animal and dropped.cell in game.frontier():
			_board_click(dropped.cell)

func _on_lan_action_result(request_id: int, accepted: bool, message: String) -> void:
	if accepted: return
	if request_id == _market_drop_request: _market_drop.clear()
	_message(message)

func _on_lan_closed(reason: String) -> void:
	lan_discovery.stop()
	lan_session.shutdown()
	game = null
	show_menu()
	status = GameLocale.text(reason)
	var body = _open_modal(GameLocale.text("联机提示"),780,400)
	body.add_child(_wrap(GameLocale.text(reason),22))
	body.add_child(_button(GameLocale.text("重新连接"),show_lan_lobby,true))

# Name field with a stripe in that traveller's colour, matching their tab in game.

func _player_field(color: Color) -> StyleBoxFlat:
	var style = P.box(Color("fffaf0"),8,P.LINE)
	style.border_width_left = 6
	style.border_color = color.darkened(.1)
	return style

func _start_practice() -> void:
	lan_discovery.stop()
	lan_session.shutdown()
	lan_modal_body = null
	_practicing = true
	start_game({"count":1,"names":["练习旅行者"]},Practice.SEED)
	_practice_start_score = S.game_scores(game)[0]

func _practice_step() -> Practice.Step:
	return Practice.step(game,selection_tile)

func _practice_results() -> void:
	PracticeModal.new().open(self)

func start_game(config: Dictionary, seed_value: int = -1) -> void:
	game = G.new()
	var options = config.duplicate(true)
	options.survey_id = Crypto.new().generate_random_bytes(16).hex_encode()
	game.start(options,seed_value)
	view_player = 0
	reports = []
	highlight.clear()
	_reset_selection()
	status = GameLocale.text("选取一组地块与动物，开始构筑你的生态世界。")
	_save()
	_render_game()

func _continue_game() -> void:
	var resumed = G.new()
	if not resumed.load_game():
		var body = _open_modal(GameLocale.text(resumed.last_notice) if resumed.last_notice != "" else GameLocale.text("无法读取存档"),650,310)
		body.add_child(_wrap(GameLocale.text("存档无法读取。可以关闭此窗口并开始新的旅程。")))
		return
	game = resumed
	view_player = game.active
	highlight.clear()
	_reset_selection()
	mode = "animal" if not game.pending.is_empty() and game.pending.tile_pos != null else "tile"
	status = GameLocale.text("旅程已恢复，继续上次的选择。")
	reports = S.game_scores(game) if game.finished else []
	if game.finished: _record_result()
	_render_game()

func _reset_selection() -> void:
	selection_tile = -1
	selection_animal = -1
	independent = false
	refreshing = false
	refresh_indices.clear()
	mode = "tile"

func _save() -> void:
	if _practicing or (lan_session != null and lan_session.started):
		return
	if game.save_game() != OK:
		status = GameLocale.text("自动存档写入失败，请检查磁盘空间。")

func _render_game() -> void:
	var completed_turns = 0
	for player in game.players: completed_turns += int(player.turns)
	var feedback_event = ""
	if _feedback_game_id == game.get_instance_id():
		if completed_turns > _feedback_turns:
			feedback_event = GameLocale.text("旅程完成") if game.finished else GameLocale.text("回合完成")
		elif str(game.rng.state) != _feedback_rng:
			feedback_event = GameLocale.text("动物已刷新")
	_feedback_game_id = game.get_instance_id()
	_feedback_turns = completed_turns
	_feedback_rng = str(game.rng.state)

	if _screen_game != game or not is_instance_valid(board):
		_build_game_screen()
	var notices = refresh()
	if _practicing: feedback_event = ""
	if not notices.is_empty(): feedback_event = notices if feedback_event.is_empty() else feedback_event+"\n"+notices
	if not feedback_event.is_empty(): _show_feedback(feedback_event)

	_schedule_ai()

func _ai_level() -> String:
	if game == null or game.finished or _practicing or (lan_session != null and lan_session.started): return ""
	var seats = game.config.get("seats",[])
	if game.active >= seats.size() or seats[game.active] == "human": return ""
	return str(seats[game.active])

func _schedule_ai() -> void:
	if not is_instance_valid(board) or is_instance_valid(modal) or _ai_level().is_empty(): return
	var turn = [game.get_instance_id(),game.active,game.players[game.active].turns]
	if ai_turn != turn:
		ai_turn = turn
		ai_steps.clear()
	if ai_timer.is_stopped():
		ai_timer.start(.01 if settings.fast_ai else .48)

func _play_ai_step() -> void:
	var level = _ai_level()
	if not is_instance_valid(board) or is_instance_valid(modal) or level.is_empty(): return
	if ai_steps.is_empty(): ai_steps = AI.actions(game,AI.plan(game,level))
	if ai_steps.is_empty(): return
	var entry = ai_steps.pop_front()
	ai_executing = true
	if entry.action == "commit_turn":
		_commit()
	else:
		var error = _request_action(entry.action,entry.args)
		if error.is_empty():
			var name = str(GameLocale.player_name(game.players[game.active].name))
			match entry.action:
				"draft":
					status = GameLocale.text("%s 领取了地块与%s。") % [name,GameLocale.text(T.ANIMAL_NAMES[game.pending.animal])]
					mode = "tile"
				"place_tile":
					status = GameLocale.text("%s 拼接了新的海岸地块。") % name
					mode = "animal"
				"place_animal": status = GameLocale.text("%s 安置了%s。") % [name,GameLocale.text(T.ANIMAL_NAMES[game.pending.animal])]
				"discard_animal": status = GameLocale.text("%s 放归了%s。") % [name,GameLocale.text(T.ANIMAL_NAMES[game.pending.animal])]
			_action("")
		else:
			ai_steps.clear()
			_message(error)
	ai_executing = false

func _build_game_screen() -> void:
	_reset_screen()
	_screen_game = game
	_large_text = settings.large_text
	var background = ColorRect.new()
	background.color = P.DARK
	screen.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Decoration lives inside the background node so the child order of screen is unchanged.
	_background(background,.55)
	var tint = ColorRect.new()
	tint.color = Color(P.DARK.r,P.DARK.g,P.DARK.b,.78)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(tint)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root = _vbox(16)
	var outer = _margin(root,24)
	screen.add_child(outer)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_bar = HeaderBar.new()
	root.add_child(header_bar)
	header_bar.build(self)
	var body = _hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	market_panel = MarketPanel.new()
	body.add_child(market_panel)
	market_panel.build(self)
	_market_tokens = market_panel.tokens
	board_panel = BoardPanel.new()
	body.add_child(board_panel)
	board_panel.build(self)
	board = board_panel.board
	cards_panel = CardsPanel.new()
	body.add_child(cards_panel)
	cards_panel.build(self)
	action_bar = ActionBar.new()
	root.add_child(action_bar)
	action_bar.build(self)
	status_label = action_bar.status
	_toast_label = _heading("",26,P.GOLD_LIGHT,650)
	_toast_label.add_theme_stylebox_override("normal",Ornament.badge(Color(P.DARK,.96),P.GOLD))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.hide()
	screen.add_child(_toast_label)
	turn_effects = preload("res://scripts/ui/turn_effects.gd").new()
	screen.add_child(turn_effects)
	turn_effects.build(self)

func _view_state() -> Dictionary:
	var lan = lan_session != null and lan_session.started
	return {"game":game,"view":view_player,"mode":mode,"tile":selection_tile,"animal":selection_animal,
		"independent":independent,"refreshing":refreshing,"indices":refresh_indices,"highlight":highlight,
		"reports":reports,"status":status,"practice":_practicing,"step":_practice_step() if _practicing else -1,
		"lan":lan,"ai":not _ai_level().is_empty(),"can_act":_ai_level().is_empty() and (not lan or lan_session.can_control_player(game.active))}

func refresh() -> String:
	var state = _view_state()
	var notices = turn_effects.update(state)
	for panel in [header_bar,market_panel,board_panel,cards_panel,action_bar]:
		panel.update(state)
	if is_instance_valid(modal): modal.update(state)
	if _large_text != settings.large_text:
		_large_text = settings.large_text
		for label in screen.find_children("*","Label",true,false):
			if label.has_meta("base_font_size"):
				label.add_theme_font_size_override("font_size",label.get_meta("base_font_size")+(2 if _large_text else 0))
	return notices

func _set_mode(next: String) -> void:
	if not _ai_level().is_empty(): return
	mode = next
	_render_game()

func _show_feedback(text: String) -> void:
	if _toast_tween: _toast_tween.kill()
	_feedback_toast = _toast_label
	var caption = "✦  "+text
	var bounds = board.get_global_rect()
	var font = _toast_label.get_theme_font("font")
	var font_size = _toast_label.get_theme_font_size("font_size")
	var width = 0.0
	for line in caption.split("\n"):
		width = maxf(width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
	width = minf(width+32.0,maxf(220.0,bounds.size.x-32.0))
	_toast_label.size.x = width
	_toast_label.text = caption
	_toast_label.size.y = _toast_label.get_minimum_size().y
	_toast_label.position = Vector2(bounds.get_center().x-width*.5,bounds.position.y+20.0)
	_toast_label.show()
	_toast_tween = Feedback.toast(_toast_label,_hide_feedback,board.animations)

func _hide_feedback() -> void:
	_toast_label.hide()
	_feedback_toast = null

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
	_render_game()

func _market_pick(index: int, is_animal: bool) -> void:
	if not _market_drop.is_empty(): return
	if not _ai_level().is_empty(): return
	if _practicing and (index != Practice.MARKET_GROUP or _practice_step() == Practice.Step.REVIEW): return
	if lan_session != null and lan_session.started and not lan_session.can_control_player(game.active): return
	if game.finished or not game.pending.is_empty(): return
	if view_player != game.active:
		view_player = game.active
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
	status = GameLocale.text("选择完成后，点击「确认选取」。")
	_render_game()

func _market_drag_data(_position: Vector2, index: int) -> Variant:
	if not _can_drop_market_tile() or market_panel.rows[index].tile.disabled: return null
	return {"market_row":index,"tile":game.market_tiles[index],"animal":game.market_animals[index]}

func _can_drop_market_tile() -> bool:
	return is_instance_valid(board) and not is_instance_valid(modal) and board.market_drop_enabled and _market_drop.is_empty()

func _drop_market_tile(data: Dictionary, cell: Vector2i) -> void:
	if not _can_drop_market_tile() or cell not in game.frontier(): return
	var row = int(data.market_row)
	if game.market_tiles[row] != data.tile or game.market_animals[row] != data.animal: return
	_market_pick(row,false)
	if lan_session.started and not lan_session.host:
		_market_drop = data.duplicate()
		_market_drop.cell = cell
		_draft(true)
		return
	_draft()
	if not game.pending.is_empty(): _board_click(cell)

func _draft(from_drop: bool = false) -> void:
	if not from_drop and not _market_drop.is_empty(): return
	var error = _request_action("draft",{"tile_index":selection_tile,"animal_index":selection_animal})
	if error.is_empty():
		if _practicing: game.rotate_pending(-1)
		_reset_selection()
		status = GameLocale.text("试着旋转一次，看看地块的朝向怎样变化。") if _practicing else GameLocale.text("点击虚线空格放地块；也可先切换到「放动物」。")
	elif from_drop:
		_market_drop.clear()
	_action(error)

func _undo_placement() -> void:
	var error = _request_action("clear_preview")
	if error.is_empty(): mode = "tile"
	_action(error)

func _board_click(cell: Vector2i) -> void:
	if not _ai_level().is_empty(): return
	if _practicing:
		var practice_step = _practice_step()
		if practice_step == Practice.Step.ROTATE:
			_message(GameLocale.text("先转到泥滩对齐，再点击金色空位。"))
			return
		if practice_step not in [Practice.Step.TILE,Practice.Step.ANIMAL]: return
		if cell != Practice.TARGET:
			_message(GameLocale.text("请点亮框标出的练习落点。"))
			return
	if game.pending.is_empty():
		_message(GameLocale.text("请先从左侧市集选取一组地块与动物。"))
		return
	var error = ""
	if mode == "tile":
		error = _request_action("place_tile",{"q":cell.x,"r":cell.y,"rotation":int(game.pending.rotation)})
		if error.is_empty():
			mode = "animal"
			status = GameLocale.text("点击带白圈的栖息地安置动物，也可选择放归。")
			if _practicing: status = GameLocale.text("泥滩接上了！把弹涂鱼放到新地块上。")
	else:
		error = _request_action("place_animal",{"q":cell.x,"r":cell.y})
		if error.is_empty():
			mode = "tile" if game.pending.tile_pos == null else "animal"
			status = GameLocale.text("地块与动物均可继续调整。满意后点击「完成回合」。") if game.ready_to_commit() else GameLocale.text("动物已选择栖息地，接着摆放地块。")
			if _practicing: status = GameLocale.text("弹涂鱼已安置。可以确认这一回合，也可以撤回重试。")
	_action(error)

func _rotate(amount: int) -> void:
	if not _ai_level().is_empty(): return
	if game == null or not is_instance_valid(board) or game.finished or game.pending.is_empty() or view_player != game.active:
		return
	if _practicing and game.pending.tile_pos != null: return
	_request_action("rotate_pending",{"amount":amount})
	_action("")
	board.rotation_offset = -amount*PI/3.0 if settings.animations else 0.0

func _action(error: String) -> void:
	if not error.is_empty():
		_message(error)
		return
	_save()
	_render_game()

func _request_action(action: String, args: Dictionary = {}) -> String:
	if not ai_executing and not _ai_level().is_empty(): return GameLocale.text("电脑正在行动。")
	if lan_session != null and lan_session.started:
		if not lan_session.can_control_player(game.active):
			return GameLocale.text("请等待轮到自己且连接恢复后再操作。")
		var request_id = lan_session.request(action,args)
		if action == "draft" and not _market_drop.is_empty(): _market_drop_request = request_id
		status = GameLocale.text("正在同步操作……")
		return ""
	var error: String = game.apply_action(action,args)
	if error.is_empty():
		var cues = {"place_tile":"tile_place","place_animal":"token_place","rotate_pending":"rotate","refresh":"refresh","commit_turn":"game_end" if game.finished else "turn_end"}
		if cues.has(action): sound.play(cues[action])
	return error

func _message(text: String) -> void:
	text = GameLocale.text(text)
	sound.play("error")
	status = text
	if is_instance_valid(status_label):
		status_label.text = text
		status_label.add_theme_color_override("font_color",Color("a45333"))

func _commit() -> void:
	if lan_session != null and lan_session.started:
		var error = _request_action("commit_turn")
		if not error.is_empty(): _message(error)
		return
	var was_watching = view_player == game.active
	var error = _request_action("commit_turn")
	if not error.is_empty():
		_message(error)
		return
	_save()
	_reset_selection()
	highlight.clear()
	if was_watching or _ai_level().is_empty(): view_player = game.active
	status = GameLocale.player_name(game.players[game.active].name)+GameLocale.text("，轮到你了。选择下一组地块与动物。")
	if _practicing:
		status = GameLocale.text("这一回合已落定，练习数据不会保存。")
	if game.finished:
		reports = S.game_scores(game)
		status = GameLocale.text("点击计分项目，可在版图上查看得分依据。")
		_record_result()
	_render_game()
	if game.finished: show_results()

func _record_result() -> void:
	if _practicing or (lan_session != null and lan_session.started): return
	if records.record(game,reports) != OK:
		status = GameLocale.text("调查记录写入失败，重新打开存档后会重试。")

func show_nature() -> void:
	if not _ai_level().is_empty(): return
	NatureModal.new().open(self)

func show_card(animal: String, card: String) -> void:
	CardModal.new().open(self,animal,card)

func _highlight_score(player: int, category: String, is_wildlife: bool) -> void:
	_close_modal()
	view_player = player
	highlight.clear()
	var points = 0
	if is_wildlife:
		var part = reports[player].wildlife[category]
		points = part.points
		for group in part.groups:
			for k in group.cells:
				if k not in highlight: highlight.append(k)
		status = GameLocale.text("%s：%d 分。金色边框显示参与计分的地块。") % [GameLocale.text(T.ANIMAL_NAMES[category]),points]
	else:
		var part = reports[player].habitats[category]
		highlight = part.cells.duplicate()
		status = GameLocale.text("%s：最大相连区域 %d 分，奖励 %d 分。") % [GameLocale.text(T.HABITAT_NAMES[category]),part.points,part.bonus]
	_render_game()

func show_results() -> void:
	ResultsModal.new().open(self)

func show_help() -> void:
	HelpModal.new().open(self)

func show_settings() -> void:
	SettingsModal.new().open(self)

func _load_settings() -> void:
	if FileAccess.file_exists("user://settings.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
		if data is Dictionary:
			settings.merge(data,true)
	TranslationServer.set_locale("en" if settings.language == "en" else "zh_CN")
	get_window().title = GameLocale.text("潮痕群岛")
	_apply_comfort()
	_apply_audio()
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_language(language: String) -> void:
	if language not in ["zh_CN","en"]:
		return
	settings.language = language
	TranslationServer.set_locale(language)
	get_window().title = GameLocale.text("潮痕群岛")
	_save_settings()
	var reopen_settings = is_instance_valid(modal) and modal is SettingsModal
	var on_board = is_instance_valid(board)
	_close_modal()
	if on_board:
		status = ""
		_screen_game = null
		_render_game()
	else:
		show_menu()
	if reopen_settings:
		show_settings()

func _save_settings() -> void:
	var file = FileAccess.open("user://settings.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(settings))

func _apply_comfort() -> void:
	Feedback.enabled = bool(settings.animations)
	if not Feedback.enabled and is_instance_valid(modal) and modal is ResultsModal:
		modal.finish_reveal()
	load("res://scripts/ui/tile_painter.gd").habitat_labels = bool(settings.habitat_labels)
	if is_instance_valid(board):
		board.animations = settings.animations
		board.show_names = settings.animal_names
		if not settings.animations:
			if _toast_tween: _toast_tween.kill()
			_hide_feedback()
			turn_effects.stop_motion()
			market_panel.stop_motion()
			board.stop_landing()
			board.pulse = 1.0
			board.rotation_offset = 0.0
		board.queue_redraw()

func _apply_audio() -> void:
	if is_instance_valid(sound):
		sound.volume_db = linear_to_db(clampf(float(settings.volume),0,1))
	if is_instance_valid(music):
		music.volume_db = linear_to_db(clampf(float(settings.music_volume),0,1))
