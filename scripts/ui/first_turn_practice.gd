extends RefCounted

enum Step { SELECT, DRAFT, ROTATE, TILE, ANIMAL, COMMIT, REVIEW }

const SEED = 3
const MARKET_GROUP = 0
const TARGET = Vector2i(1,0)
const LESSONS = [
	["选取一组","点击左侧金边的第 1 组。点地块或鲑鱼都可以，两件会一起选中。"],
	["拿到手中","点击市集下方的「确认选取」，把这组地块和鲑鱼拿到手中。"],
	["转一转地块","按 E 或点击「E ↷」，把新地块的湿地转向左侧，与地图上的湿地接边。"],
	["拼接湿地","点击棋盘上的金色六角空位。同类生境接边，会连成更大的区域。"],
	["安置鲑鱼","点击新地块上的白色圆圈。鲑鱼只能住进带鲑鱼图标、还没住动物的格子。"],
	["完成回合","看一眼上方的试摆分差，再点击「完成回合」。确认前可以撤回摆放。"],
	["练习完成","首回合已经落定。点击「查看练习得分」，看看生境与动物分别怎样得分。"],
]

static func step(game: GameState, selection: int) -> Step:
	if game.players[0].turns > 0: return Step.REVIEW
	if game.pending.is_empty(): return Step.SELECT if selection < 0 else Step.DRAFT
	if game.pending.tile_pos == null:
		return Step.TILE if game.pending.rotation == 0 else Step.ROTATE
	return Step.ANIMAL if game.pending.animal_pos == null else Step.COMMIT
