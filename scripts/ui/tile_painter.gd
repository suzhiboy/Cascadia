extends RefCounted

const H = preload("res://scripts/core/hex.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const P = preload("res://scripts/ui/palette.gd")
const TERRAIN_ATLAS = preload("res://assets/art/terrain_atlas.png")
const ATLAS_GRID = Vector2(3,2)
const TERRAIN_SWATCHES = {"reef":Vector2(0,0),"marsh":Vector2(1,0),"shingle":Vector2(2,0),
	"mudflat":Vector2(0,1),"pool":Vector2(1,1)}
const PAPER_SWATCH = Vector2(2,1)
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
	var face = polygon(center,radius)
	var print_angle = -(rotation+id%6)*PI/3.0
	canvas.draw_colored_polygon(face,EDGE_TOP)
	_print(canvas,face,center,radius,print_angle,PAPER_SWATCH,.65)
	var corners = polygon(center,radius-3)
	var terrains = []
	for d in range(6):
		terrains.append(H.edge(definition,rotation,d))
	for d in range(6):
		var base = P.TERRAIN[terrains[d]]
		var wedge = PackedVector2Array([center,corners[d],corners[(d+1)%6]])
		# Light falls from the upper left: brighter centre, cooler rim.
		canvas.draw_polygon(wedge,PackedColorArray([base.lightened(.1),base.darkened(.05),base.darkened(.05)]))
		_print(canvas,wedge,center,radius,print_angle,TERRAIN_SWATCHES[terrains[d]],.8)
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

# Inset UVs keep neighboring swatches out of filtered terrain edges.
static func _print(canvas: CanvasItem, points: PackedVector2Array, center: Vector2, radius: float, angle: float, swatch: Vector2, opacity: float) -> void:
	var uv = PackedVector2Array()
	for p in points:
		var local = (p-center).rotated(angle)*(.4/radius)+Vector2(.5,.5)
		uv.append((swatch+local)/ATLAS_GRID)
	canvas.draw_polygon(points,PackedColorArray([Color(1,1,1,opacity)]),uv,TERRAIN_ATLAS)

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
