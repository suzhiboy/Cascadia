extends Control
const H = preload("res://scripts/core/hex.gd")
const P = preload("res://scripts/ui/palette.gd")
const Paint = preload("res://scripts/ui/tile_painter.gd")
const S = preload("res://scripts/core/scorer.gd")
var animal = "bear"
var card = "A"

func _ready() -> void:
	custom_minimum_size = Vector2(700,260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func example(alternate: bool) -> Dictionary:
	var coords = [Vector2i(0,0),Vector2i(1,0)]
	match animal:
		"bear":
			var n = {"A":2,"B":3,"C":3,"D":4}[card]
			coords = []
			for i in range(n + (1 if alternate else 0)): coords.append(Vector2i(i,0))
		"elk":
			coords = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)]
			if card == "B": coords = [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)]
			if card == "D": coords = H.neighbors(Vector2i.ZERO)
			if alternate: coords = [Vector2i(0,0)]
		"salmon":
			coords = [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0)]
			if alternate: coords.append(Vector2i(0,1))
		"hawk":
			coords = [Vector2i(0,0),Vector2i(3,0)] if not alternate else [Vector2i(0,0),Vector2i(1,0)]
		"fox":
			coords = [Vector2i(0,0)]
			if card == "D": coords.append(Vector2i(1,0))
	var board = {}
	for pos in coords: board[H.key(pos)] = {"q":pos.x,"r":pos.y,"tile":16,"rotation":0,"animal":animal}
	if animal == "hawk" and card == "D" and not alternate:
		for i in [1,2]: board[H.key(Vector2i(i,0))] = {"q":i,"r":0,"tile":16,"rotation":0,"animal":"bear" if i==1 else "elk"}
	if animal == "fox" and not alternate:
		for pos in [Vector2i(0,-1),Vector2i(1,-1)]:
			board[H.key(pos)] = {"q":pos.x,"r":pos.y,"tile":16,"rotation":0,"animal":"bear"}
	return board

func _draw() -> void:
	for side in range(2):
		var board = example(side == 1)
		var radius = 27.0
		var low = Vector2(INF,INF)
		var high = Vector2(-INF,-INF)
		for cell in board.values():
			var pos = H.to_pixel(Vector2i(cell.q,cell.r),radius)
			low = low.min(pos)
			high = high.max(pos)
		var origin = Vector2(size.x*(0.25+side*0.5),115)-(low+high)*0.5
		for cell in board.values():
			var pos = origin+H.to_pixel(Vector2i(cell.q,cell.r),radius)
			draw_colored_polygon(Paint.polygon(pos,radius-1),P.PAPER)
			Paint.outline(self,pos,radius-1,P.GOLD,1.5)
			Paint.token(self,pos,radius*.65,cell.animal)
		var score = S.wildlife(board,animal,card).points
		var caption = ("例一" if side == 0 else "对照") + "：%d 分" % score
		draw_string(P.font(600),Vector2(size.x*side*0.5+25,225),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,23,P.INK)
	draw_line(Vector2(size.x/2,25),Vector2(size.x/2,235),P.LINE,1)
