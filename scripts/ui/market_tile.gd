extends Control

const Painter = preload("res://scripts/ui/tile_painter.gd")
var tile_id = 0
var animal = ""
var show_token = false
var tile_rotation = 0
var market_display = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if show_token and animal != "":
		Painter.token(self,size*.5,minf(size.x,size.y)*.40,animal)
	elif tile_id > 0:
		var radius = minf(size.x*.48,size.y*.43)
		Painter.tile(self,size*.5-Vector2(0,radius*.06),radius,tile_id,tile_rotation,"",market_display)
