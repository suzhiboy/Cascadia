extends Control

const MarketTile = preload("res://scripts/ui/market_tile.gd")
const P = preload("res://scripts/ui/palette.gd")
const Feedback = preload("res://scripts/ui/feedback.gd")
const Preview = preload("res://scripts/ui/score_preview.gd")
const S = preload("res://scripts/core/scorer.gd")

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
		var label = ui._heading("",22,P.CREAM,700)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color",P.DARK)
		label.add_theme_constant_override("outline_size",7)
		label.hide()
		add_child(label)
		score_labels.append(label)

func update(state: Dictionary) -> void:
	var game = state.game
	var turns = 0
	for player in game.players: turns += int(player.turns)
	var changed_turn = turns != last_turn
	if changed_turn:
		var next_scores = S.game_scores(game)
		if Feedback.enabled and last_turn >= 0 and not previous_hand.is_empty() and state.view == last_actor and ui.board_panel.last_view == last_actor:
			_show_score_changes(Preview.changes(baseline[last_actor],next_scores[last_actor]),previous_hand)
		baseline = next_scores
	elif Feedback.enabled and previous_hand.is_empty() and not game.pending.is_empty() and state.view == game.active:
		_start_flight(game.pending)
	if not game.pending.is_empty() and state.view == game.active:
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
	if score_tween: score_tween.kill()
	for label in score_labels: label.hide()
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
		label.text = "%s %+d" % [part.label,part.points]
		label.size = Vector2(180,34)
		_position_score(0.0,label,cell,level)
		label.modulate.a = 1.0
		label.show()
		score_tween.tween_method(_position_score.bind(label,cell,level),0.0,23.0,.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		score_tween.tween_property(label,"modulate:a",0,.22).set_delay(.48)
	score_tween.chain().tween_callback(func():
		for label in score_labels: label.hide())

func _position_score(rise: float, label: Label, cell: Vector2i, level: int) -> void:
	var bounds = ui.board.get_global_rect()
	var anchor = bounds.position+ui.board.screen_position(cell)
	label.position = (anchor-Vector2(90,42+level*31+rise)).clamp(bounds.position,bounds.end-label.size)

func stop_motion() -> void:
	_end_flight()
	if score_tween: score_tween.kill()
	for label in score_labels: label.hide()
