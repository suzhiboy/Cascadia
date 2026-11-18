extends RefCounted
const G = preload("res://scripts/core/game_state.gd")
const S = preload("res://scripts/core/scorer.gd")
const T = preload("res://scripts/core/tile_definition.gd")

static func describe(game) -> String:
	if game.pending.is_empty(): return ""
	var before = S.game_scores(game)[game.active]
	var copy = G.new()
	copy.restore(game.snapshot())
	copy.players[copy.active].board = game.preview_board()
	if game.pending.animal_pos != null:
		var p = game.pending.animal_pos
		var cell = copy.players[copy.active].board["%d,%d" % [p[0],p[1]]]
		if T.keystone(int(cell.tile)): copy.players[copy.active].nature += 1
	var after = S.game_scores(copy)[copy.active]
	var parts = []
	for animal in T.ANIMALS:
		var difference = after.wildlife[animal].points-before.wildlife[animal].points
		if difference != 0: parts.append("%s %+d" % [T.ANIMAL_NAMES[animal],difference])
	var habitat = 0
	var bonus = 0
	for h in T.HABITATS:
		habitat += after.habitats[h].points-before.habitats[h].points
		bonus += after.habitats[h].bonus-before.habitats[h].bonus
	if habitat != 0: parts.append("生境 %+d" % habitat)
	if bonus != 0: parts.append("奖励 %+d" % bonus)
	if after.nature != before.nature: parts.append("自然标记 %+d" % (after.nature-before.nature))
	return "试摆预估：%+d 分%s（确认后落定；奖励按当前排名）" % [after.total-before.total," · "+ " / ".join(parts) if not parts.is_empty() else ""]
