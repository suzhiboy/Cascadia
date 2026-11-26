extends Control

const H = preload("res://scripts/core/hex.gd")
const P = preload("res://scripts/ui/palette.gd")
const Paint = preload("res://scripts/ui/tile_painter.gd")
const S = preload("res://scripts/core/scorer.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")
const TILE_BOUNDS = Rect2(-.93,-1.03,1.90,2.20)

# Paired field sketches. Each placement records axial position, catalogue tile and resident.
const EXAMPLES = {
	"crab": {
		"A": [
			[[Vector2i(0,0),31,"crab"]],
			[[Vector2i(0,0),17,"crab"]]
		],
		"B": [
			[[Vector2i(0,0),31,"crab"]],
			[[Vector2i(0,0),31,"crab"], [Vector2i(1,0),16,""], [Vector2i(0,1),17,""]]
		],
		"C": [
			[[Vector2i(0,0),31,"crab"], [Vector2i(1,0),33,"crab"], [Vector2i(0,1),17,"crab"]],
			[[Vector2i(0,0),31,"crab"], [Vector2i(1,0),33,"crab"], [Vector2i(2,0),17,"crab"]]
		],
		"D": [
			[[Vector2i(0,0),31,"crab"], [Vector2i(1,0),16,""], [Vector2i(0,1),36,""]],
			[[Vector2i(0,0),31,"crab"], [Vector2i(1,0),16,""], [Vector2i(0,1),17,""]]
		]
	},
	"limpet": {
		"A": [
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),17,""]],
			[[Vector2i(0,0),37,"limpet"]]
		],
		"B": [
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),17,""], [Vector2i(-1,0),36,""]],
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),17,""], [Vector2i(0,1),36,""]]
		],
		"C": [
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),3,"",3]],
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),3,""]]
		],
		"D": [
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),37,"limpet"], [Vector2i(2,0),18,"limpet"]],
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),37,"limpet"], [Vector2i(0,1),18,"limpet"]]
		]
	},
	"tern": {
		"A": [
			[[Vector2i(0,0),27,"tern"], [Vector2i(0,1),16,""], [Vector2i(-1,1),17,""], [Vector2i(-1,0),18,""], [Vector2i(0,-1),26,""]],
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(-1,1),17,""], [Vector2i(0,-1),18,""]]
		],
		"B": [
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(-1,1),17,""], [Vector2i(0,-1),18,""]],
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(2,0),36,""]]
		],
		"C": [
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(2,0),21,"tern"]],
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(1,1),21,"tern"]]
		],
		"D": [
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(2,0),21,""]],
			[[Vector2i(0,0),27,"tern"], [Vector2i(0,1),16,""], [Vector2i(1,1),36,""], [Vector2i(2,0),21,""]]
		]
	},
	"goby": {
		"A": [
			[[Vector2i(0,0),32,"goby"]],
			[[Vector2i(0,0),19,"goby"]]
		],
		"B": [
			[[Vector2i(0,0),32,"goby"], [Vector2i(1,0),16,""], [Vector2i(0,1),26,""]],
			[[Vector2i(0,0),91,"goby"], [Vector2i(1,0),36,""]]
		],
		"C": [
			[[Vector2i(0,0),19,"goby"], [Vector2i(1,0),32,"goby"], [Vector2i(1,1),36,"goby"]],
			[[Vector2i(0,0),19,"goby"], [Vector2i(1,0),32,"goby"], [Vector2i(2,0),16,""], [Vector2i(3,0),36,"goby"]]
		],
		"D": [
			[[Vector2i(0,0),19,"goby"], [Vector2i(1,0),31,""], [Vector2i(-1,0),36,""]],
			[[Vector2i(0,0),19,"goby"], [Vector2i(1,0),31,""], [Vector2i(0,1),36,""]]
		]
	},
	"otter": {
		"A": [
			[[Vector2i(0,0),38,"otter"], [Vector2i(1,0),17,"crab"], [Vector2i(0,1),16,"limpet"]],
			[[Vector2i(0,0),38,"otter"], [Vector2i(1,0),17,"tern"]]
		],
		"B": [
			[[Vector2i(0,0),38,"otter"], [Vector2i(1,-1),16,""], [Vector2i(1,0),17,""], [Vector2i(0,1),18,""]],
			[[Vector2i(0,0),38,"otter"], [Vector2i(1,0),16,""], [Vector2i(-1,1),17,""], [Vector2i(0,-1),18,""]]
		],
		"C": [
			[[Vector2i(0,0),38,"otter"], [Vector2i(1,0),18,"otter"], [Vector2i(2,0),16,""], [Vector2i(3,0),38,"otter"], [Vector2i(4,0),26,"otter"]],
			[[Vector2i(0,0),38,"otter"], [Vector2i(1,0),18,"otter"], [Vector2i(2,0),26,"otter"], [Vector2i(3,0),38,"otter"]]
		],
		"D": [
			[[Vector2i(0,0),38,"otter"], [Vector2i(1,0),36,""], [Vector2i(2,0),37,""], [Vector2i(3,0),39,""]],
			[[Vector2i(0,0),18,"otter"], [Vector2i(1,0),16,""], [Vector2i(2,0),36,""]]
		]
	}
}

var animal = "crab"
var card = "A"
var compact = false
var removed = [{},{}]
var score_plate = Ornament.badge(P.CREAM,P.GOLD)

func _ready() -> void:
	name = "RuleDiagram"
	resized.connect(queue_redraw)
	if compact:
		custom_minimum_size = Vector2(146,90)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	custom_minimum_size = Vector2(0,386)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = GameLocale.text("点击图例中的动物可暂时移除，再点同一格可恢复。")

func example(alternate: bool) -> Dictionary:
	var board = {}
	for placement in EXAMPLES[animal][card][int(alternate)]:
		var p = placement[0]
		var key = H.key(p)
		var resident = "" if removed[int(alternate)].has(key) else placement[2]
		board[key] = {"q":p.x,"r":p.y,"tile":placement[1],"rotation":placement[3] if placement.size() > 3 else 0,"animal":resident}
	return board

func reset_example() -> void:
	removed = [{},{}]
	queue_redraw()

func _example_area(side: int) -> Rect2:
	var width = size.x if compact else size.x*.5
	var margin = 3.0 if compact else 14.0
	return Rect2(Vector2(width*side+margin,margin),Vector2(width-margin*2,size.y-margin-(24 if compact else 54)))

func _layout(board: Dictionary, area: Rect2) -> Dictionary:
	var bounds = Rect2()
	var centers = {}
	for key in board:
		var center = H.to_pixel(H.coord(key),1.0)
		centers[key] = center
		var tile = Rect2(center+TILE_BOUNDS.position,TILE_BOUNDS.size)
		bounds = tile if centers.size() == 1 else bounds.merge(tile)
	var fit = area.size/bounds.size
	var radius = minf(fit.x,fit.y)
	var origin = area.get_center()-bounds.get_center()*radius
	for key in centers:
		centers[key] = origin+centers[key]*radius
	return {"centers":centers,"radius":radius,"bounds":Rect2(origin+bounds.position*radius,bounds.size*radius)}

func _gui_input(event: InputEvent) -> void:
	if compact or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for side in range(2):
		var board = example(side == 1)
		var layout = _layout(board,_example_area(side))
		for key in board:
			if (board[key].animal != "" or removed[side].has(key)) and event.position.distance_to(layout.centers[key]) <= layout.radius*.65:
				if removed[side].has(key):
					removed[side].erase(key)
				else:
					removed[side][key] = true
				queue_redraw()
				accept_event()
				return

func _points(board: Dictionary) -> int:
	return S.wildlife(board,animal,card).points

func _draw() -> void:
	var width = size.x if compact else size.x*.5
	var font_size = 17 if compact else 23
	var font = P.font(700)
	for side in range(1 if compact else 2):
		var board = example(side == 1)
		var layout = _layout(board,_example_area(side))
		var radius = layout.radius*(.91 if compact else .975)
		for key in board:
			var cell = board[key]
			var center = layout.centers[key]
			Paint.tile(self,center,radius,cell.tile,cell.rotation,"" if compact else cell.animal,false,false)
			if compact and cell.animal != "":
				Paint.token(self,center,radius*.53,cell.animal)
		var marks = {}
		for key in board:
			if board[key].animal != animal: continue
			var edges = S.wildlife_edges(board,key,card)
			for marked in edges:
				if not marks.has(marked): marks[marked] = {}
				for d in edges[marked]: marks[marked][d] = true
		for key in marks:
			for d in marks[key]:
				Paint.scoring_edge(self,layout.centers[key],radius,d)
		var caption = GameLocale.text("示例 %d 分" if side == 0 else "对照 %d 分") % _points(board)
		var badge = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+20
		var y = size.y-(23 if compact else 42)
		draw_style_box(score_plate,Rect2((side+.5)*width-badge*.5,y,badge,23 if compact else 34))
		draw_string(font,Vector2(width*side,y+font.get_ascent(font_size)+1),caption,HORIZONTAL_ALIGNMENT_CENTER,width,font_size,P.INK)
	if not compact:
		draw_line(Vector2(width,14),Vector2(width,size.y-14),P.LINE,1)
