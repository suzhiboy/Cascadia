extends RefCounted

const S = preload("res://scripts/core/scorer.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const H = preload("res://scripts/core/hex.gd")

# Both the provisional summary and committed popups compare the same score fields.
static func changes(before: Dictionary, after: Dictionary) -> Array:
	var parts = []
	for animal in T.ANIMALS:
		var points = after.wildlife[animal].points-before.wildlife[animal].points
		if points: parts.append({"kind":"wildlife","label":T.ANIMAL_NAMES[animal],"points":points})
	var habitat = 0
	var bonus = 0
	for h in T.HABITATS:
		habitat += after.habitats[h].points-before.habitats[h].points
		bonus += after.habitats[h].bonus-before.habitats[h].bonus
	if habitat: parts.append({"kind":"habitat","label":"最大连片","points":habitat})
	if bonus: parts.append({"kind":"bonus","label":"奖励","points":bonus})
	if after.nature != before.nature:
		parts.append({"kind":"nature","label":"自然标记","points":after.nature-before.nature})
	return parts

static func describe(game) -> String:
	if game.pending.is_empty(): return ""
	if game.pending.tile_pos == null and game.pending.animal_pos == null:
		return "试摆预估：+0 分（确认后落定；奖励按当前排名）"
	var reports = S.game_scores(game)
	var before = reports[game.active]
	var board = game.preview_board()
	var nature = int(before.nature)
	if game.pending.animal_pos != null:
		var p = game.pending.animal_pos
		var cell = board["%d,%d" % [p[0],p[1]]]
		if T.keystone(int(cell.tile)): nature += 1
	var after = S.player_score(board,nature,game.config.cards)
	for h in T.HABITATS:
		var sizes = reports.map(func(report): return report.habitats[h].points)
		sizes[game.active] = after.habitats[h].points
		after.habitats[h].bonus = S.majority(sizes)[game.active]
		after.total += after.habitats[h].bonus
	var parts = changes(before,after).map(func(part):return "%s %+d" % [part.label,part.points])
	return "试摆预估：%+d 分%s（确认后落定；奖励按当前排名）" % [after.total-before.total," · "+ " / ".join(parts) if not parts.is_empty() else ""]

# Holding the tile fixed, compare each residence with releasing the token. A resident
# may change the scores of other species. Habitat areas and majorities stay constant.
static func placement_points(game, legal: Array) -> Dictionary:
	var result = {}
	if legal.is_empty(): return result
	var board = game.preview_board()
	if game.pending.animal_pos != null:
		var p = game.pending.animal_pos
		board[H.key(Vector2i(p[0],p[1]))].animal = ""
	var baseline = _wildlife_total(board,game.config.cards)
	for cell in legal:
		var tile = board[H.key(cell)]
		tile.animal = game.pending.animal
		result[cell] = _wildlife_total(board,game.config.cards)-baseline+int(T.keystone(int(tile.tile)))
		tile.animal = ""
	return result

static func _wildlife_total(board: Dictionary, cards: Dictionary) -> int:
	var points = 0
	for animal in T.ANIMALS:
		points += S.wildlife(board,animal,cards[animal]).points
	return points
