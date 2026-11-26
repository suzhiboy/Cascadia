extends Control

# Small vector emblems drawn in code so they stay crisp at any UI scale.
# kind: "logo" | "shell" | "hex" | "progress" | "check"
const Painter = preload("res://scripts/ui/tile_painter.gd")
const P = preload("res://scripts/ui/palette.gd")
var kind = "hex"
var color = P.DARK
var accent = P.CREAM
var text = ""
var value = 0
var total = 20
var font_size = 15

static func make(kind_name: String, minimum: Vector2, fill: Color = P.DARK, mark: Color = P.CREAM, caption: String = "") -> Control:
	var emblem = load("res://scripts/ui/ornament.gd").new()
	emblem.kind = kind_name
	emblem.color = fill
	emblem.accent = mark
	emblem.text = caption
	emblem.custom_minimum_size = minimum
	return emblem

static func badge(fill: Color, edge: Color) -> StyleBoxFlat:
	return P.chip(fill,edge,9,10,3)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resized.connect(queue_redraw)

static func hexagon(center: Vector2, radius: float, flat: bool = false) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		points.append(center+Vector2.from_angle(deg_to_rad((0.0 if flat else -30.0)+i*60))*radius)
	return points

func _draw() -> void:
	var center = size*.5
	var radius = minf(size.x,size.y)*.5
	match kind:
		"logo":
			_logo(center,radius)
		"shell":
			draw_colored_polygon(hexagon(center+Vector2(0,1.5),radius*.98),Color(0,0,0,.18))
			draw_colored_polygon(hexagon(center,radius*.96),color)
			Painter.shell(self,center,radius*.6,accent,color)
		"hex":
			draw_colored_polygon(hexagon(center+Vector2(0,1.5),radius*.98),Color(0,0,0,.14))
			draw_colored_polygon(hexagon(center,radius*.96),color)
			if text != "":
				var font = P.font(700)
				var width = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
				draw_string(font,center+Vector2(-width*.5,font_size*.36),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,accent)
		"check":
			draw_colored_polygon(hexagon(center,radius*.96),color)
			draw_polyline(PackedVector2Array([center+Vector2(-radius*.42,0),center+Vector2(-radius*.1,radius*.32),center+Vector2(radius*.45,-radius*.34)]),accent,maxf(2.0,radius*.2),true)
		"progress":
			_progress()

func _logo(center: Vector2, radius: float) -> void:
	draw_colored_polygon(hexagon(center+Vector2(0,2),radius),Color(0,0,0,.25))
	draw_colored_polygon(hexagon(center,radius),P.GOLD)
	draw_colored_polygon(hexagon(center,radius*.87),P.DARK)
	draw_circle(center+Vector2(.21,-.26)*radius,radius*.19,P.GOLD_LIGHT,true,-1,true)
	for j in range(2):
		var wave = PackedVector2Array()
		for i in range(15):
			var t = i/14.0
			wave.append(center+Vector2((t-.5)*1.18,.18+j*.21+sin(t*TAU)*.09)*radius)
		draw_polyline(wave,P.CREAM,maxf(1,radius*.072),true)
	var bird = PackedVector2Array([center+Vector2(-.59,-.18)*radius,center+Vector2(-.38,-.19)*radius,center+Vector2(-.18,-.10)*radius,center+Vector2(-.04,-.30)*radius,center+Vector2(.09,-.36)*radius])
	draw_polyline(bird,P.CREAM,maxf(1,radius*.071),true)

func _progress() -> void:
	# A 20-step trail: done steps filled, the current one ringed in brass.
	var gap = 3.0
	var width = (size.x-gap*(total-1))/float(total)
	for i in range(total):
		var rect = Rect2(Vector2(i*(width+gap),size.y*.5-4),Vector2(width,8))
		var fill = color if i < value else Color(accent.r,accent.g,accent.b,.22)
		draw_rect(rect,fill,true)
		if i == value and value < total:
			draw_rect(rect.grow(1.5),P.GOLD,false,1.5)
