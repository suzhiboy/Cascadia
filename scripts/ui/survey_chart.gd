extends Control

const H = preload("res://scripts/core/hex.gd")
const Paint = preload("res://scripts/ui/tile_painter.gd")
const P = preload("res://scripts/ui/palette.gd")

var players: Array = []

func show_players(value: Array) -> void:
	players = value
	custom_minimum_size = Vector2(800,205)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if players.is_empty(): return
	var plot = Rect2(49,10,size.x-73,size.y-41)
	var ceiling = 10
	for player in players:
		for move in player.get("history",[]):
			ceiling = maxi(ceiling,int(move.get("round_total",move.total)))
	ceiling = ceili(ceiling/10.0)*10
	for i in range(3):
		var y = plot.end.y-i*plot.size.y*.5
		draw_line(Vector2(plot.position.x,y),Vector2(plot.end.x,y),P.LINE,1,true)
		draw_string(P.font(500),Vector2(0,y+6),str(roundi(i*ceiling*.5)),HORIZONTAL_ALIGNMENT_RIGHT,40,16,P.MUTED)
	for turn in [1,5,10,15,20]:
		var x = plot.position.x+(turn-1)*plot.size.x/19.0
		draw_string(P.font(500),Vector2(x-16,plot.end.y+23),str(turn),HORIZONTAL_ALIGNMENT_CENTER,32,17,P.MUTED)
	for i in range(players.size()):
		var line = PackedVector2Array()
		for move in players[i].get("history",[]):
			var total = move.get("round_total",move.total)
			line.append(Vector2(plot.position.x+(int(move.turn)-1)*plot.size.x/19.0,plot.end.y-int(total)*plot.size.y/ceiling))
		var color = P.PLAYERS[i].darkened(.24)
		if line.size() > 1: draw_polyline(line,color,3,true)
		for point in line: draw_circle(point,2.6,color)

static func best_move(history: Array) -> Dictionary:
	var best := {}
	for move in history:
		if move.get("delta") != null and (best.is_empty() or move.delta > best.delta):
			best = move
	return best

class FinalBoard extends Control:
	var cells := {}
	var best := {}

	func _draw() -> void:
		if cells.is_empty(): return
		var order = cells.keys()
		order.sort_custom(func(a,b):return H.to_pixel(H.coord(a),1).y < H.to_pixel(H.coord(b),1).y)
		var bounds = Rect2(H.to_pixel(H.coord(order[0]),1),Vector2.ZERO)
		for key in order: bounds = bounds.expand(H.to_pixel(H.coord(key),1))
		var radius = minf((size.x-8)/(bounds.size.x+2),(size.y-8)/(bounds.size.y+2.3))
		var origin = size*.5-bounds.get_center()*radius
		for key in order:
			var cell = cells[key]
			var at = origin+H.to_pixel(H.coord(key),radius)
			Paint.tile(self,at,radius*.95,int(cell.tile),int(cell.rotation),cell.animal)
		if not best.is_empty():
			var p = Vector2i(best.cell[0],best.cell[1])
			Paint.outline(self,origin+H.to_pixel(p,radius),radius*.99,P.GOLD_DEEP,2)
			if best.animal_cell != null:
				var resident = Vector2i(best.animal_cell[0],best.animal_cell[1])
				draw_arc(origin+H.to_pixel(resident,radius),radius*.45,0,TAU,30,P.GOLD_DEEP,2,true)
