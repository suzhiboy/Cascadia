extends Control

const MarketTile = preload("res://scripts/ui/market_tile.gd")
const P = preload("res://scripts/ui/palette.gd")
const Feedback = preload("res://scripts/ui/feedback.gd")
const Preview = preload("res://scripts/ui/score_preview.gd")
const S = preload("res://scripts/core/scorer.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")

const SCORE_DURATION = 1.2
const SCORE_STAGGER = .08

var flying_tile = MarketTile.new()
var flying_token = MarketTile.new()
var score_labels: Array[Label] = []
var ui
var last_turn := -1
var last_actor := -1
var previous_hand := {}
var baseline: Array = []
var flight: Tween
var score_tween: Tween
var growth_tween: Tween
var turn_delta := 0
var total_format := "%+d"

func build(controller) -> void:
	name = "TurnEffects"
	ui = controller
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flying_token.show_token = true
	for piece in [flying_tile,flying_token]:
		add_child(piece)
		piece.hide()
	# At most five wildlife categories plus habitat, majority and nature.
	for i in range(8):
		var label = ui._heading("",28,P.CREAM,700)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_stylebox_override("normal",Ornament.badge(P.DARK,P.CREAM))
		label.hide()
		add_child(label)
		score_labels.append(label)

func update(state: Dictionary) -> String:
	var game = state.game
	var turns = 0
	for player in game.players: turns += int(player.turns)
	var changed_turn = turns != last_turn
	var notices = PackedStringArray()
	if changed_turn:
		clear_view()
		var next_scores = S.game_scores(game)
		if last_turn >= 0 and turns == last_turn+1:
			var before = baseline[last_actor]
			var after = next_scores[last_actor]
			var move = game.players[last_actor].history.back()
			var same_board = state.view == last_actor and ui.board_panel.last_view == last_actor
			var regions = Preview.growth(before,after)
			if same_board:
				if _animated():
					var hand = {"tile_pos":move.cell,"animal_pos":move.animal_cell}
					_show_score_changes(Preview.changes(before,after),hand)
				_show_growth(regions)
			turn_delta = int(move.delta) if move.delta != null else int(after.total-before.total)
			var actor = GameLocale.player_name(game.players[last_actor].name)
			_show_total(actor,same_board)
			if not regions.is_empty():
				var growth = " · ".join(regions.map(func(region): return region.label))
				notices.append(growth if same_board else GameLocale.text("%s · %s") % [actor,growth])
			notices.append_array(_rank_changes(game.players,baseline,next_scores))
		elif last_turn < 0 and game.turn_nature_spent > 0:
			next_scores[game.active].nature += game.turn_nature_spent
			next_scores[game.active].total += game.turn_nature_spent
		baseline = next_scores
	elif previous_hand.is_empty() and not game.pending.is_empty():
		clear_view()
		if _animated() and state.view == game.active: _start_flight(game.pending)
	if _animated() and not game.pending.is_empty() and state.view == game.active:
		var tile_pos = game.pending.tile_pos
		var animal_pos = game.pending.animal_pos
		if tile_pos != null and tile_pos != previous_hand.get("tile_pos"):
			ui.board.land(Vector2i(tile_pos[0],tile_pos[1]),false)
		if animal_pos != null and animal_pos != previous_hand.get("animal_pos"):
			ui.board.land(Vector2i(animal_pos[0],animal_pos[1]),true)
	if game.pending.is_empty() and not previous_hand.is_empty(): _end_flight()
	last_turn = turns
	last_actor = game.active
	previous_hand = game.pending.duplicate(true)
	return "\n".join(notices)

func _animated() -> bool:
	return Feedback.enabled and ui.board.animations

func _rank_changes(players: Array, before: Array, after: Array) -> PackedStringArray:
	var notices = PackedStringArray()
	for i in range(players.size()):
		var old_rank = _rank(before,i)
		var new_rank = _rank(after,i)
		if new_rank == old_rank: continue
		var message = "%s 升至第 %d" if new_rank < old_rank else "%s 降至第 %d"
		notices.append(GameLocale.text(message) % [GameLocale.player_name(players[i].name),new_rank])
	return notices

func _rank(scores: Array, seat: int) -> int:
	var score = scores[seat]
	var rank = 1
	for other in scores:
		if other.total > score.total or (other.total == score.total and other.nature > score.nature): rank += 1
	return rank

func _start_flight(hand: Dictionary) -> void:
	_end_flight()
	var tile_origin = ui.market_panel.rows[int(hand.tile_index)].tile.get_global_rect().get_center()
	var animal_origin = ui.market_panel.rows[int(hand.animal_index)].animal.get_global_rect().get_center()
	flying_tile.tile_id = hand.tile
	flying_tile.tile_rotation = hand.rotation
	flying_token.animal = hand.animal
	flying_tile.size = Vector2(115,108)
	flying_token.size = Vector2(70,70)
	var sources = [tile_origin,animal_origin]
	var pieces = [flying_tile,flying_token]
	var targets = [ui.action_bar.tile,ui.action_bar.animal]
	flight = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(2):
		var piece = pieces[i]
		piece.position = sources[i]-piece.size*.5
		piece.show()
		piece.queue_redraw()
		# The hand's container is laid out on the next frame. Resolve its centre as we fly.
		flight.tween_method(_fly.bind(piece,sources[i],targets[i]),0.0,1.0,.24)
	flight.chain().tween_callback(_hide_flight)

func _fly(t: float, piece: Control, origin: Vector2, target: Control) -> void:
	piece.position = origin.lerp(target.get_global_rect().get_center(),t)-piece.size*.5-Vector2(0,45*sin(t*PI))

func _end_flight() -> void:
	if flight: flight.kill()
	_hide_flight()

func _hide_flight() -> void:
	flying_tile.hide()
	flying_token.hide()

func _show_score_changes(changes: Array, hand: Dictionary) -> void:
	if changes.is_empty(): return
	score_tween = create_tween().set_parallel(true)
	var levels = {}
	for i in range(changes.size()):
		var part = changes[i]
		var pos = hand.animal_pos if part.kind in ["wildlife","nature"] and hand.animal_pos != null else hand.tile_pos
		if pos == null: continue
		var cell = Vector2i(pos[0],pos[1])
		var level = levels.get(cell,0)
		levels[cell] = level+1
		var label = score_labels[i]
		label.get_theme_stylebox("normal").bg_color = P.ANIMALS.get(part.get("animal",""),P.DARK)
		label.text = GameLocale.text("%s %+d") % [part.label,part.points]
		label.reset_size()
		_position_score(0.0,label,cell,level)
		label.modulate.a = 1.0
		var delay = i*SCORE_STAGGER
		if i == 0: label.show()
		else: score_tween.tween_callback(label.show).set_delay(delay)
		score_tween.tween_method(_position_score.bind(label,cell,level),0.0,28.0,SCORE_DURATION-delay).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		score_tween.tween_property(label,"modulate:a",0.0,.24).set_delay(SCORE_DURATION-.24)
	score_tween.tween_callback(_hide_scores).set_delay(SCORE_DURATION)

func _position_score(rise: float, label: Label, cell: Vector2i, level: int) -> void:
	var bounds = ui.board.get_global_rect()
	var anchor = bounds.position+ui.board.screen_position(cell)
	var stack = level*(label.size.y+4)
	var y = anchor.y-40-label.size.y-stack-rise
	if anchor.y-bounds.position.y < 160: y = anchor.y+30+stack-rise
	label.position = Vector2(anchor.x-label.size.x*.5,y).clamp(bounds.position,bounds.end-label.size)

func _show_total(actor: String, same_board: bool) -> void:
	var label = ui.board_panel.turn_total
	if label == null: return
	total_format = "%+d" if same_board else "上回合 %+d"
	label.tooltip_text = GameLocale.text("%s 本回合得分") % actor
	label.show()
	if not _animated():
		_set_total(turn_delta)
		return
	_set_total(0.0)
	if score_tween == null: score_tween = create_tween().set_parallel(true)
	score_tween.tween_method(_set_total,0.0,float(turn_delta),.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_total(value: float) -> void:
	var label = ui.board_panel.turn_total
	if label != null: label.text = GameLocale.text(total_format) % roundi(value)

func _show_growth(regions: Array) -> void:
	if regions.is_empty(): return
	var cells = {}
	for region in regions:
		for key in region.cells: cells[key] = true
	ui.board.turn_highlight = cells.keys()
	ui.board.turn_highlight_pulse = 1.0
	ui.board.queue_redraw()
	growth_tween = create_tween()
	if _animated():
		growth_tween.tween_method(func(t: float):
			ui.board.turn_highlight_pulse = .5+.5*cos(t*TAU*2.0)
			ui.board.queue_redraw(),0.0,1.0,1.0)
	else:
		growth_tween.tween_interval(1.0)
	growth_tween.tween_callback(_clear_growth)

func _clear_growth() -> void:
	ui.board.turn_highlight.clear()
	ui.board.queue_redraw()

func _hide_scores() -> void:
	for label in score_labels: label.hide()

func stop_motion() -> void:
	_end_flight()
	if score_tween: score_tween.kill()
	score_tween = null
	_hide_scores()
	if growth_tween: growth_tween.kill()
	_clear_growth()
	_set_total(turn_delta)

func clear_view() -> void:
	stop_motion()
	if ui.board_panel.turn_total != null: ui.board_panel.turn_total.hide()
