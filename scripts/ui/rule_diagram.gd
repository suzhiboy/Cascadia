extends Control

const H = preload("res://scripts/core/hex.gd")
const P = preload("res://scripts/ui/palette.gd")
const Paint = preload("res://scripts/ui/tile_painter.gd")
const S = preload("res://scripts/core/scorer.gd")
const T = preload("res://scripts/core/tile_definition.gd")

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
			[[Vector2i(0,0),31,"crab"], [Vector2i(1,0),33,"crab"], [Vector2i(0,1),16,""]],
			[[Vector2i(0,0),31,"crab"], [Vector2i(1,0),17,"tern"]]
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
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),17,""]],
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),36,""]]
		],
		"D": [
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),37,"limpet"]],
			[[Vector2i(0,0),16,"limpet"], [Vector2i(1,0),18,"limpet"]]
		]
	},
	"tern": {
		"A": [
			[[Vector2i(0,0),27,"tern"]],
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(-1,1),17,""], [Vector2i(0,-1),18,""]]
		],
		"B": [
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(0,1),17,""]],
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(2,0),36,""]]
		],
		"C": [
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(1,1),32,"goby"]],
			[[Vector2i(0,0),27,"tern"], [Vector2i(1,0),16,""], [Vector2i(2,0),17,""], [Vector2i(3,0),32,"goby"]]
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
			[[Vector2i(0,0),19,"goby"], [Vector2i(1,0),31,""], [Vector2i(0,1),36,""]],
			[[Vector2i(0,0),32,"goby"], [Vector2i(1,0),31,""]]
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
			[[Vector2i(0,0),38,"otter"], [Vector2i(1,0),26,""]],
			[[Vector2i(0,0),38,"otter"], [Vector2i(1,0),27,"tern"]]
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

func _ready() -> void:
	if compact:
		custom_minimum_size = Vector2(80,60)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	custom_minimum_size = Vector2(700,260)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "点击图例中的动物可暂时移除，再点同一格可恢复。"

func example(alternate: bool) -> Dictionary:
	var board = {}
	for placement in EXAMPLES[animal][card][int(alternate)]:
		var p = placement[0]
		board[H.key(p)] = {"q":p.x,"r":p.y,"tile":placement[1],"rotation":0,"animal":placement[2]}
	return board

func reset_example() -> void:
	removed = [{},{}]
	queue_redraw()

func _layout(side: int, board: Dictionary) -> Dictionary:
	var low = Vector2(INF,INF)
	var high = Vector2(-INF,-INF)
	var centers = {}
	for key in board:
		var center = H.to_pixel(H.coord(key),32)
		centers[key] = center
		low = low.min(center)
		high = high.max(center)
	var origin = Vector2(size.x*(0.25+side*0.5),105)-(low+high)*0.5
	for key in centers:
		centers[key] += origin
	return centers

func _gui_input(event: InputEvent) -> void:
	if compact or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for side in range(2):
		var board = example(side == 1)
		var centers = _layout(side,board)
		for key in board:
			if board[key].animal != "" and event.position.distance_to(centers[key]) <= 27:
				if removed[side].has(key):
					removed[side].erase(key)
				else:
					removed[side][key] = true
				queue_redraw()
				accept_event()
				return

func _draw_cell(center: Vector2, cell: Dictionary) -> void:
	var tile = T.get_tile(cell.tile)
	var corners = Paint.polygon(center,31)
	for d in range(6):
		var terrain = H.edge(tile,cell.rotation,d)
		draw_colored_polygon(PackedVector2Array([center,corners[d],corners[(d+1)%6]]),P.TERRAIN[terrain])
	Paint.outline(self,center,31,P.INK,1)
	if cell.animal != "":
		Paint.token(self,center+Vector2(0,-5),15,cell.animal)
	if compact:
		return
	var names = tile.habitats.map(func(h): return T.HABITAT_NAMES[h])
	var caption = "·".join(names)
	var label_pos = center + Vector2(-31,19 if cell.animal != "" else 5)
	draw_string_outline(P.font(600),label_pos,caption,HORIZONTAL_ALIGNMENT_CENTER,62,12,3,P.INK)
	draw_string(P.font(600),label_pos,caption,HORIZONTAL_ALIGNMENT_CENTER,62,12,P.PAPER)

func _draw_thumbnail() -> void:
	var board = example(false)
	var bounds = Rect2()
	var first = true
	for key in board:
		var center = H.to_pixel(H.coord(key),32)
		var cell_bounds = Rect2(center-Vector2(29,32),Vector2(58,64))
		bounds = cell_bounds if first else bounds.merge(cell_bounds)
		first = false
	var scale_factor = minf((size.x-4)/bounds.size.x,(size.y-4)/bounds.size.y)
	draw_set_transform(size/2-bounds.get_center()*scale_factor,0,Vector2.ONE*scale_factor)
	for key in board:
		_draw_cell(H.to_pixel(H.coord(key),32),board[key])
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _draw() -> void:
	if compact:
		_draw_thumbnail()
		return
	for side in range(2):
		var board = example(side == 1)
		var centers = _layout(side,board)
		for key in board:
			if removed[side].has(key):
				board[key].animal = ""
			_draw_cell(centers[key],board[key])
		var score = S.wildlife(board,animal,card).points
		var caption = ("例一" if side == 0 else "对照") + "　%d 分" % score
		draw_string(P.font(600),Vector2(size.x*side*0.5,225),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x*.5,23,P.INK)
	draw_line(Vector2(size.x/2,25),Vector2(size.x/2,235),P.LINE,1)
