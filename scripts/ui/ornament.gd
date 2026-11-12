extends Control

# Small vector emblems drawn in code so they stay crisp at any UI scale.
# kind: "logo" | "leaf" | "hex" | "progress" | "check"
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
		"leaf":
			draw_colored_polygon(hexagon(center+Vector2(0,1.5),radius*.98),Color(0,0,0,.18))
			draw_colored_polygon(hexagon(center,radius*.96),color)
			_leaf(center,radius*.62,accent)
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

func _leaf(center: Vector2, length: float, tint: Color) -> void:
	# A conifer-needle leaf: two arcs meeting at tip and stem, with a midrib.
	var tip = center+Vector2(length*.55,-length*.55)
	var stem = center+Vector2(-length*.55,length*.55)
	var points = PackedVector2Array()
	for i in range(13):
		var t = float(i)/12.0
		var base = stem.lerp(tip,t)
		points.append(base+Vector2(-1,-1).normalized()*sin(t*PI)*length*.42)
	for i in range(12,-1,-1):
		var t = float(i)/12.0
		var base = stem.lerp(tip,t)
		points.append(base+Vector2(1,1).normalized()*sin(t*PI)*length*.42)
	draw_colored_polygon(points,tint)
	draw_line(stem+(stem-tip)*.12,tip.lerp(stem,.15),color.darkened(.1),maxf(1.0,length*.07),true)

func _logo(center: Vector2, radius: float) -> void:
	draw_colored_polygon(hexagon(center+Vector2(0,2),radius),Color(0,0,0,.25))
	draw_colored_polygon(hexagon(center,radius),P.GOLD)
	var inner = hexagon(center,radius*.84)
	draw_colored_polygon(inner,P.PINE_MID)
	# Sky band, snowy peak, a fir and a river line — the four lands of the game in one mark.
	var r = radius*.84
	draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.78,r*.2),center+Vector2(-r*.18,-r*.5),center+Vector2(r*.25,r*.02),center+Vector2(r*.5,-r*.22),center+Vector2(r*.85,r*.2)]),P.TERRAIN.mountain)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.36,-r*.29),center+Vector2(-r*.18,-r*.5),center+Vector2(0,-r*.29)]),P.CREAM)
	var tree = center+Vector2(r*.36,r*.05)
	for i in range(3):
		var y = -r*.42+i*r*.17
		var w = r*(.13+i*.07)
		draw_colored_polygon(PackedVector2Array([tree+Vector2(0,y),tree+Vector2(w,y+r*.24),tree+Vector2(-w,y+r*.24)]),P.TERRAIN.forest.darkened(.25))
	var water = PackedVector2Array()
	for i in range(9):
		var t = float(i)/8.0
		water.append(center+Vector2(lerpf(-r*.8,r*.8,t),r*.48+sin(t*TAU*1.2)*r*.07))
	draw_polyline(water,P.TERRAIN.river.lightened(.3),maxf(1.5,r*.1),true)

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
