class_name Hex
extends RefCounted

const DIRS = [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1)]

static func key(p: Vector2i) -> String:
	return "%d,%d" % [p.x,p.y]

static func coord(k: String) -> Vector2i:
	var parts = k.split(",")
	return Vector2i(int(parts[0]),int(parts[1]))

static func neighbors(p: Vector2i) -> Array:
	var result = []
	for d in DIRS:
		result.append(p+d)
	return result

static func to_pixel(p: Vector2i, radius: float) -> Vector2:
	return Vector2(sqrt(3.0)*(p.x+p.y*0.5),1.5*p.y)*radius

static func from_pixel(p: Vector2, radius: float) -> Vector2i:
	var q = (sqrt(3.0)/3.0*p.x-p.y/3.0)/radius
	var r = 2.0/3.0*p.y/radius
	var x = round(q)
	var z = round(r)
	var y = round(-q-r)
	var dx = abs(x-q)
	var dz = abs(z-r)
	var dy = abs(y+q+r)
	if dx > dy and dx > dz:
		x = -y-z
	elif dz > dy:
		z = -x-y
	return Vector2i(int(x),int(z))

static func edge(tile: Dictionary, rotation: int, direction: int) -> String:
	var habitats = tile.habitats
	if habitats.size() == 1:
		return habitats[0]
	# The reference tiles put habitat 0 on the left at zero rotation.
	return habitats[0] if posmod(direction-rotation-2,6) < 3 else habitats[1]

static func rotate(p: Vector2i, steps: int) -> Vector2i:
	for _i in range(posmod(steps,6)):
		p = Vector2i(-p.y,p.x+p.y)
	return p
