extends RefCounted

const H = preload("res://scripts/core/hex.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const P = preload("res://scripts/ui/palette.gd")
const EDGE_TOP = Color("e9dcb2")
const EDGE_SIDE = Color("a8956a")
static var habitat_labels = true
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

static func scoring_edge(canvas: CanvasItem, center: Vector2, radius: float, side: int) -> void:
	var inset = clampf(radius*.075,1.25,6.0)
	var corners = polygon(center,radius-inset)
	var a = corners[side]
	var b = corners[(side+1)%6]
	var width = clampf(radius*.056,1.25,5.5)
	canvas.draw_line(a.lerp(b,.13),b.lerp(a,.13),P.INK,width*1.85,true)
	canvas.draw_line(a.lerp(b,.13),b.lerp(a,.13),P.GOLD_LIGHT,width,true)

# Deterministic 0..1 noise so each tile keeps the same scenery between redraws.
static func _rand(id: int, a: int, b: int) -> float:
	var v = sin(float(id)*12.9898+float(a)*78.233+float(b)*37.719)*43758.5453
	return v-floor(v)

static func tile(canvas: CanvasItem, center: Vector2, radius: float, id: int, rotation: int, animal: String = "", market_display: bool = false, show_slots: bool = true) -> void:
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
	if habitat_labels and radius >= 40:
		for i in range(definition.habitats.size()):
			var habitat = definition.habitats[i]
			var label_pos = center+Vector2((-0.66 if i == 0 else 0.66)*radius,0).rotated(rotation*PI/3.0)+Vector2(-radius*.09,radius*.08)
			# Pale habitats (shingle) take dark ink; the rest keep cream lettering.
			var ink = Color(.24,.21,.15,.78) if P.TERRAIN[habitat].get_luminance() > .62 else Color("fff9e8")
			canvas.draw_string(P.font(600),label_pos,GameLocale.text(T.HABITAT_NAMES[habitat]).left(1),HORIZONTAL_ALIGNMENT_LEFT,-1,int(radius*.20),ink)
	if definition.wildlife.size() == 1:
		_keystone(canvas,center+Vector2(0,-radius*.66),radius*.13)
	if animal != "":
		token(canvas,center,radius*.39,animal)
	elif show_slots:
		var animals = definition.wildlife
		var scale = 1.12 if market_display else 1.0
		for i in range(animals.size()):
			token(canvas,center+_slot(animals.size(),i)*radius*scale,radius*scale*_slot_size(animals.size()),animals[i],true)

# Hostable wildlife sit in a row of one or two, or a triangle of three, so the icons can stay large.
static func _slot(count: int, index: int) -> Vector2:
	match count:
		1: return Vector2.ZERO
		2: return Vector2(-.27 if index == 0 else .27,0)
		_: return [Vector2(-.26,-.14),Vector2(.26,-.14),Vector2(0,.31)][index]

static func _slot_size(count: int) -> float:
	return [.29,.29,.25,.225][mini(count,3)]

# A shell fan identifies the bonus printed on a single-species shore.
static func _keystone(canvas: CanvasItem, center: Vector2, size: float) -> void:
	canvas.draw_circle(center+Vector2(0,1.2),size*1.12,Color(0,0,0,.18))
	canvas.draw_circle(center,size*1.12,Color("fbf3dc"))
	canvas.draw_arc(center,size*1.12,0,TAU,24,P.GOLD_DEEP,1.2,true)
	shell(canvas,center,size*.85,P.MOSS,Color("fbf3dc"))

static func shell(canvas: CanvasItem, center: Vector2, size: float, tint: Color, line: Color) -> void:
	var hinge = center+Vector2(0,size*.71)
	var fan = PackedVector2Array([hinge])
	for i in range(21):
		var angle = deg_to_rad(208+i*6.2)
		var distance = size*(1.35 if i%4 == 2 else 1.29)
		fan.append(hinge+Vector2.from_angle(angle)*distance)
	canvas.draw_colored_polygon(fan,tint)
	for i in range(3):
		var ray = Vector2.from_angle(deg_to_rad(241+29*i))*size
		canvas.draw_line(hinge+ray*.18,hinge+ray*1.07,line,maxf(.7,size*.085),true)

# Coastal landmarks are drawn inside each terrain wedge, even at a rotated boundary.
static func _scenery(canvas: CanvasItem, center: Vector2, radius: float, id: int, d: int, habitat: String) -> void:
	var base = P.TERRAIN[habitat]
	for k in range(2):
		var angle = deg_to_rad(60.0*d+(k*2-1)*14.0+(_rand(id,d,k)-.5)*10.0)
		var p = center+Vector2.from_angle(angle)*radius*(.57+_rand(id,d,k+7)*.15)
		var s = radius*(.1+_rand(id,d,k+11)*.035)
		var ink = base.darkened(.35)
		match habitat:
			"reef":
				var rock = PackedVector2Array([p+Vector2(-1,.45)*s,p+Vector2(-.7,-.2)*s,p+Vector2(.15,-.62)*s,p+Vector2(.84,-.35)*s,p+Vector2(1,.2)*s,p+Vector2(.3,.47)*s])
				canvas.draw_colored_polygon(rock,ink)
				canvas.draw_line(rock[1],rock[2],base.lightened(.5),maxf(1,s*.17),true)
				canvas.draw_line(rock[2],p,base.lightened(.17),maxf(1,s*.12),true)
			"marsh":
				for blade in range(-2,3):
					var root = p+Vector2(blade*.14,.55)*s
					var tip = p+Vector2(blade*.47,-1.0+.18*absi(blade))*s
					canvas.draw_colored_polygon(PackedVector2Array([root,root.lerp(tip,.5)+Vector2(s*.12,0),tip,root+Vector2(-s*.12,0)]),ink)
			"shingle":
				for j in range(3):
					var stone = p+Vector2(-.58+.64*j,.25 if j != 1 else -.23)*s
					canvas.draw_circle(stone,s*(.28+.07*(j%2)),ink,true,-1,true)
					canvas.draw_line(stone-Vector2(.13,.07)*s,stone+Vector2(.08,-.12)*s,base.lightened(.5),maxf(.7,s*.11),true)
			"mudflat":
				for j in range(2):
					var rill = PackedVector2Array()
					for i in range(6):
						rill.append(p+Vector2((i-2.5)*.34,sin(i*.8)*.23+j*.43)*s)
					canvas.draw_polyline(rill,ink,maxf(.8,s*.12),true)
				canvas.draw_circle(p+Vector2(-.38,-.48)*s,s*.15,ink)
			"pool":
				for j in range(2):
					var ripple = PackedVector2Array()
					for i in range(13):
						var a = i*TAU/12.0
						ripple.append(p+Vector2(cos(a),sin(a)*.37)*s*(.64+j*.45))
					canvas.draw_polyline(ripple,base.lightened(.45) if j == 0 else ink,maxf(.7,s*.12),true)

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
		canvas.draw_arc(center,radius-maxf(1.0,radius*.08),0,TAU,32,hue.darkened(.05),maxf(1.4,radius*.14),true)
		canvas.draw_texture_rect(icons[animal],Rect2(center-Vector2.ONE*radius*.76,Vector2.ONE*radius*1.52),false,hue.darkened(.4))
		return
	# A placed wildlife token: brass rim, coloured face, cream silhouette.
	canvas.draw_circle(center+Vector2(radius*.04,radius*.12),radius*1.04,Color(0.08,0.1,0.06,.32))
	canvas.draw_circle(center,radius,P.GOLD.lightened(.12))
	canvas.draw_circle(center,radius*.9,hue.lightened(.08))
	canvas.draw_arc(center,radius*.78,0,TAU,40,hue.darkened(.22),maxf(1.0,radius*.05),true)
	canvas.draw_arc(center,radius*.97,PI*1.1,PI*1.8,16,Color(1,.98,.9,.75),maxf(1.0,radius*.05),true)
	canvas.draw_texture_rect(icons[animal],Rect2(center-Vector2.ONE*radius*.74+Vector2(0,radius*.05),Vector2.ONE*radius*1.48),false,Color(0,0,0,.18))
	canvas.draw_texture_rect(icons[animal],Rect2(center-Vector2.ONE*radius*.74,Vector2.ONE*radius*1.48),false,Color("fff7df"))
