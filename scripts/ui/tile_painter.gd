extends RefCounted

const H = preload("res://scripts/core/hex.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const P = preload("res://scripts/ui/palette.gd")
const EDGE_TOP = Color("e9dcb2")
const EDGE_SIDE = Color("a8956a")
static var icons: Dictionary = {}

static func polygon(center: Vector2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		points.append(center+Vector2.from_angle(deg_to_rad(-30+i*60))*radius)
	return points

static func outline(canvas: CanvasItem, center: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	var points = polygon(center,radius)
	points.append(points[0])
	canvas.draw_polyline(points,color,width,true)

# Deterministic 0..1 noise so each tile keeps the same scenery between redraws.
static func _rand(id: int, a: int, b: int) -> float:
	var v = sin(float(id)*12.9898+float(a)*78.233+float(b)*37.719)*43758.5453
	return v-floor(v)

static func tile(canvas: CanvasItem, center: Vector2, radius: float, id: int, rotation: int, animal: String = "") -> void:
	var definition = T.get_tile(id)
	var depth = radius*.085
	# Cast shadow, then the cardboard edge, then the printed face.
	canvas.draw_colored_polygon(polygon(center+Vector2(radius*.03,depth+radius*.07),radius*1.01),Color(0.08,0.12,0.07,0.16))
	canvas.draw_colored_polygon(polygon(center+Vector2(0,depth),radius),EDGE_SIDE)
	outline(canvas,center+Vector2(0,depth),radius,Color(0.32,0.26,0.16,0.35),1.0)
	canvas.draw_colored_polygon(polygon(center+Vector2(0,depth*.45),radius),EDGE_SIDE.lightened(.18))
	canvas.draw_colored_polygon(polygon(center,radius),EDGE_TOP)
	var corners = polygon(center,radius-3)
	var terrains = []
	for d in range(6):
		terrains.append(H.edge(definition,rotation,d))
	for d in range(6):
		var base = P.TERRAIN[terrains[d]]
		# Light falls from the upper left: brighter centre, cooler rim.
		canvas.draw_polygon(PackedVector2Array([center,corners[d],corners[(d+1)%6]]),PackedColorArray([base.lightened(.1),base.darkened(.05),base.darkened(.05)]))
	for d in range(6):
		_scenery(canvas,center,radius,id,d,terrains[d])
	# Seams where two habitats meet.
	for d in range(6):
		if terrains[d] != terrains[(d+1)%6]:
			canvas.draw_line(center,corners[(d+1)%6],Color(0.18,0.2,0.12,0.22),3.2,true)
			canvas.draw_line(center,corners[(d+1)%6],Color(1,.97,.86,.7),1.4,true)
	# Bevel: a lit upper-left rim and a shaded lower-right rim.
	var rim = polygon(center,radius-4.5)
	var light = Vector2(-0.45,-0.89)
	for d in range(6):
		var a = rim[d]
		var b = rim[(d+1)%6]
		var facing = ((a+b)*.5-center).normalized().dot(light)
		var shade = Color(1,1,.94,.38*facing) if facing > 0 else Color(.08,.14,.1,-.2*facing)
		canvas.draw_line(a,b,shade,2.6,true)
	outline(canvas,center,radius-1.2,EDGE_TOP,2.6)
	outline(canvas,center,radius+.4,Color(0.3,0.26,0.16,0.4),1.0)
	if definition.wildlife.size() == 1:
		_keystone(canvas,center+Vector2(0,-radius*.66),radius*.13)
	if animal != "":
		token(canvas,center,radius*.39,animal)
	else:
		var animals = definition.wildlife
		var spacing = radius*.45
		for i in range(animals.size()):
			token(canvas,center+Vector2((i-(animals.size()-1)*.5)*spacing,0),radius*.205,animals[i],true)

# Keystone tiles (one wildlife) award a nature token: marked with the same leaf as the token.
static func _keystone(canvas: CanvasItem, center: Vector2, size: float) -> void:
	canvas.draw_circle(center+Vector2(0,1.2),size*1.12,Color(0,0,0,.18))
	canvas.draw_circle(center,size*1.12,Color("fbf3dc"))
	canvas.draw_arc(center,size*1.12,0,TAU,24,P.GOLD_DEEP,1.2,true)
	leaf(canvas,center,size*1.25,P.MOSS)

static func leaf(canvas: CanvasItem, center: Vector2, length: float, tint: Color) -> void:
	var tip = center+Vector2(length*.5,-length*.5)
	var stem = center+Vector2(-length*.5,length*.5)
	var points = PackedVector2Array()
	for i in range(11):
		var t = float(i)/10.0
		points.append(stem.lerp(tip,t)+Vector2(-.7071,-.7071)*sin(t*PI)*length*.38)
	for i in range(10,-1,-1):
		var t = float(i)/10.0
		points.append(stem.lerp(tip,t)+Vector2(.7071,.7071)*sin(t*PI)*length*.38)
	canvas.draw_colored_polygon(points,tint)
	canvas.draw_line(stem+(stem-tip)*.1,tip.lerp(stem,.2),tint.lightened(.45),maxf(.8,length*.06),true)

# Hand-drawn scenery for one sixth of the tile, kept inside its wedge so habitats stay legible.
static func _scenery(canvas: CanvasItem, center: Vector2, radius: float, id: int, d: int, habitat: String) -> void:
	var base = P.TERRAIN[habitat]
	var s = radius*.12
	var count = 2
	for k in range(count):
		var angle = deg_to_rad(60.0*d+(k*2-1)*14.0+(_rand(id,d,k)-.5)*10.0)
		var dist = radius*(.52+_rand(id,d,k+7)*.2) if k == 0 else radius*(.6+_rand(id,d,k+3)*.14)
		var p = center+Vector2.from_angle(angle)*dist
		var size = s*(.85+_rand(id,d,k+11)*.35)
		match habitat:
			"forest":
				_fir(canvas,p,size,base)
			"mountain":
				_peak(canvas,p,size*(1.15 if k == 0 else .85),base)
			"prairie":
				_grass(canvas,p,size,base,_rand(id,d,k+5) > .6)
			"wetland":
				if k == 0: _reeds(canvas,p,size,base)
				else: _lily(canvas,p,size,base)
			"river":
				_waves(canvas,p,size,base)

static func _fir(canvas: CanvasItem, p: Vector2, s: float, base: Color) -> void:
	var dark = base.darkened(.42)
	canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(-s*.75,s*.95),p+Vector2(s*.75,s*.95),p+Vector2(s*.95,s*1.15),p+Vector2(-s*.95,s*1.15)]),Color(0,0,0,.08))
	canvas.draw_line(p+Vector2(0,s*.55),p+Vector2(0,s*1.05),Color("5b4632"),maxf(1.2,s*.18),true)
	for i in range(3):
		var y = -s*1.25+i*s*.5
		var w = s*(.38+i*.2)
		canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(0,y),p+Vector2(w,y+s*.75),p+Vector2(-w,y+s*.75)]),dark)
		canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(0,y),p+Vector2(w,y+s*.75),p+Vector2(w*.15,y+s*.75)]),dark.lightened(.16))

static func _peak(canvas: CanvasItem, p: Vector2, s: float, base: Color) -> void:
	var apex = p+Vector2(0,-s*1.1)
	var left = p+Vector2(-s*1.1,s*.6)
	var right = p+Vector2(s*1.1,s*.6)
	var foot = p+Vector2(s*.15,s*.6)
	canvas.draw_colored_polygon(PackedVector2Array([apex,left,foot]),base.darkened(.12))
	canvas.draw_colored_polygon(PackedVector2Array([apex,foot,right]),base.darkened(.34))
	var snow_l = apex.lerp(left,.36)
	var snow_r = apex.lerp(right,.36)
	canvas.draw_colored_polygon(PackedVector2Array([apex,snow_l,snow_l.lerp(snow_r,.33)+Vector2(0,s*.12),snow_l.lerp(snow_r,.62)-Vector2(0,s*.04),snow_r]),Color("f4efe0"))

static func _grass(canvas: CanvasItem, p: Vector2, s: float, base: Color, flower: bool) -> void:
	var ink = base.darkened(.38)
	for i in range(5):
		var lean = (i-2)*.32
		canvas.draw_line(p+Vector2(lean*s*.25,0),p+Vector2(lean*s*.9,-s*(.9-absf(lean)*.35)),ink,maxf(1.0,s*.11),true)
	if flower:
		canvas.draw_circle(p+Vector2(s*.55,-s*.55),maxf(1.4,s*.16),Color("f6ead0"))
		canvas.draw_circle(p+Vector2(s*.55,-s*.55),maxf(.7,s*.07),P.GOLD_DEEP)

static func _reeds(canvas: CanvasItem, p: Vector2, s: float, base: Color) -> void:
	var stem = base.darkened(.42)
	canvas.draw_arc(p+Vector2(0,s*.55),s*.8,PI*1.1,PI*1.9,10,Color(1,1,1,.32),maxf(1.0,s*.09),true)
	for i in range(3):
		var x = (i-1)*s*.32
		var top = p+Vector2(x+(i-1)*s*.12,-s*(1.0-absf(i-1)*.25))
		canvas.draw_line(p+Vector2(x,s*.4),top,stem,maxf(1.0,s*.09),true)
		if i != 1:
			var head = PackedVector2Array()
			for j in range(10):
				head.append(top+Vector2(0,s*.18)+Vector2(cos(j*TAU/10)*s*.1,sin(j*TAU/10)*s*.24))
			canvas.draw_colored_polygon(head,Color("6b4a33"))

static func _lily(canvas: CanvasItem, p: Vector2, s: float, base: Color) -> void:
	var pad = PackedVector2Array([p])
	for j in range(15):
		var a = deg_to_rad(25.0+j*22.0)
		pad.append(p+Vector2(cos(a)*s*.62,sin(a)*s*.4))
	canvas.draw_colored_polygon(pad,base.darkened(.28))
	canvas.draw_arc(p,s*.82,PI*.15,PI*.85,10,Color(1,1,1,.28),maxf(.8,s*.07),true)

static func _waves(canvas: CanvasItem, p: Vector2, s: float, base: Color) -> void:
	for row in range(2):
		var points = PackedVector2Array()
		for i in range(9):
			var t = float(i)/8.0
			points.append(p+Vector2((t-.5)*s*2.1,row*s*.55+sin(t*TAU)*s*.16))
		canvas.draw_polyline(points,Color(.95,.99,.98,.62 if row == 0 else .36),maxf(1.0,s*.12),true)
	canvas.draw_line(p+Vector2(-s*.9,-s*.5),p+Vector2(-s*.5,-s*.5),base.darkened(.22),maxf(1.0,s*.1),true)

static func token(canvas: CanvasItem, center: Vector2, radius: float, animal: String, small: bool = false) -> void:
	if animal == "":
		return
	if not icons.has(animal):
		icons[animal] = load("res://assets/art/"+animal+".svg")
	var hue = P.ANIMALS[animal]
	if small:
		# Wildlife a tile can host: cream disc, ring in the animal's colour.
		canvas.draw_circle(center+Vector2(0,1.4),radius+.6,Color(0.1,0.12,0.08,.28))
		canvas.draw_circle(center,radius,Color("fbf4df"))
		canvas.draw_arc(center,radius-maxf(1.0,radius*.09),0,TAU,28,hue.darkened(.05),maxf(1.4,radius*.17),true)
		canvas.draw_texture_rect(icons[animal],Rect2(center-Vector2.ONE*radius*.66,Vector2.ONE*radius*1.32),false,hue.darkened(.48))
		return
	# A placed wildlife token: brass rim, coloured face, cream silhouette.
	canvas.draw_circle(center+Vector2(radius*.04,radius*.12),radius*1.04,Color(0.08,0.1,0.06,.32))
	canvas.draw_circle(center,radius,P.GOLD.lightened(.12))
	canvas.draw_circle(center,radius*.9,hue.lightened(.08))
	canvas.draw_arc(center,radius*.78,0,TAU,40,hue.darkened(.22),maxf(1.0,radius*.05),true)
	canvas.draw_arc(center,radius*.97,PI*1.1,PI*1.8,16,Color(1,.98,.9,.75),maxf(1.0,radius*.05),true)
	canvas.draw_texture_rect(icons[animal],Rect2(center-Vector2.ONE*radius*.74+Vector2(0,radius*.05),Vector2.ONE*radius*1.48),false,Color(0,0,0,.18))
	canvas.draw_texture_rect(icons[animal],Rect2(center-Vector2.ONE*radius*.74,Vector2.ONE*radius*1.48),false,Color("fff7df"))
