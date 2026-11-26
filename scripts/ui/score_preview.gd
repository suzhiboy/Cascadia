extends RefCounted

const S = preload("res://scripts/core/scorer.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const H = preload("res://scripts/core/hex.gd")

# Both the provisional summary and committed popups compare the same score fields.
static func changes(before: Dictionary, after: Dictionary) -> Array:
	var parts = []
	for animal in T.ANIMALS:
		var points = after.wildlife[animal].points-before.wildlife[animal].points
		if points: parts.append({"kind":"wildlife","animal":animal,"label":GameLocale.text(T.ANIMAL_NAMES[animal]),"points":points})
	var habitat = 0
	var bonus = 0
	for h in T.HABITATS:
		habitat += after.habitats[h].points-before.habitats[h].points
		bonus += after.habitats[h].bonus-before.habitats[h].bonus
	if habitat: parts.append({"kind":"habitat","label":GameLocale.text("最大连片"),"points":habitat})
	if bonus: parts.append({"kind":"bonus","label":GameLocale.text("奖励"),"points":bonus})
	if after.nature != before.nature:
		parts.append({"kind":"nature","label":GameLocale.text("自然标记"),"points":after.nature-before.nature})
	return parts

static func growth(before: Dictionary, after: Dictionary) -> Array:
	var regions = []
	for h in T.HABITATS:
		var previous = before.habitats[h].points
		var current = after.habitats[h]
		if current.points > previous:
			var label = GameLocale.text("%s连片 %d → %d") % [GameLocale.text(T.HABITAT_NAMES[h]),previous,current.points]
			regions.append({"label":label,"cells":current.cells})
	return regions

static func estimate(game, reports: Array, tile_target: Variant = null, animal_target: Variant = null) -> Dictionary:
	var before = reports[game.active]
	var board = game.preview_board(tile_target,animal_target)
	var nature = int(before.nature)
	var resident = animal_target
	if resident == null and game.pending.animal_pos != null:
		var p = game.pending.animal_pos
		resident = tile_target if tile_target != null and p == game.pending.tile_pos else Vector2i(p[0],p[1])
	if resident != null and T.keystone(int(board[H.key(resident)].tile)): nature += 1
	var after = S.player_score(board,nature,game.config.cards)
	for h in T.HABITATS:
		var sizes = reports.map(func(report): return report.habitats[h].points)
		sizes[game.active] = after.habitats[h].points
		after.habitats[h].bonus = S.majority(sizes)[game.active]
		after.total += after.habitats[h].bonus
	var parts = changes(before,after).map(func(part):return GameLocale.text("%s %+d") % [part.label,part.points])
	var details = GameLocale.text("试摆预估")
	if not parts.is_empty(): details += "\n"+" · ".join(parts)
	details += "\n"+GameLocale.text("计入当前连片奖励，确认后落定。")
	return {"delta":after.total-before.total,"details":details}

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
