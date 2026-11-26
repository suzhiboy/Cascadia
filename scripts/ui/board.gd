extends Control

signal cell_clicked(cell: Vector2i)
signal rotation_requested(amount: int)
signal market_tile_dropped(data: Dictionary, cell: Vector2i)
const H = preload("res://scripts/core/hex.gd")
const Painter = preload("res://scripts/ui/tile_painter.gd")
const P = preload("res://scripts/ui/palette.gd")
const CHART_SEA = Color("cfe1d9")
const SHORE_FOAM = Color("e6f1ea")
const SHORE_SHALLOW = Color("b9d6cc")
const SHORE_WET = Color("d3caa4")
const SHORE_DRY = Color("e7dab4")
const Feedback = preload("res://scripts/ui/feedback.gd")
const CAMERA_MARGIN = 80.0
const CAMERA_DURATION = .35
const SEA_DRAG_THRESHOLD = 6.0
const NO_CELL = Vector2i(999,999)
var animations = true:
	set(enabled):
		animations = enabled
		if not enabled and _camera_moving():
			_camera_tween.kill()
			_set_camera(_target_pan,_target_zoom)
var show_names = true
var cells: Dictionary = {}
var frontier: Array = []
var camera_frontier: Array = []
var emphasize_frontier = false
var legal_animals: Array = []
var highlight: Array = []
var placement_points := {}
var landing_cell := Vector2i.ZERO
var landing_animal := false
var landing_progress := 1.0
var landing_tween: Tween
var preview_key = ""
var hovered = NO_CELL
var pan = Vector2.ZERO
var zoom = 1.0
var camera_adjusted = false
var _camera_tween: Tween
var _target_pan := Vector2.ZERO
var _target_zoom := 1.0
var _fit_queued = false
var _force_fit = false
var radius = 73.0
var dragging = false
var market_drop_enabled = false
var _sea_press = false
var _sea_dragging = false
var _sea_origin := Vector2.ZERO
var _keyboard_cursor = false
var _drag_tile = 0
var interactive = true
var rotation_enabled = false
var pulse = 0.0
var rotation_offset = 0.0
# Presentation only: what the pending component would look like under the cursor.
var ghost_tile = 0
var ghost_rotation = 0
var ghost_animal = ""
var accent = P.GOLD
var clock = 0.0
var _frame_wait = 0.0
var _ghost: GhostView
var _ghost_ring: GhostView

# The held piece floats above its landing spot: translucent body plus an opaque brass ring.
class GhostView extends Control:
	var tile_id = 0
	var tile_rotation = 0
	var animal = ""
	var hex_radius = 70.0
	var ring_only = false
	func _draw() -> void:
		var c = size*.5
		if ring_only:
			if tile_id > 0:
				var points = Painter.polygon(c,hex_radius+2)
				for i in range(6):
					var a = points[i]
					var b = points[(i+1)%6]
					for j in range(5):
						draw_line(a.lerp(b,j/5.0+.03),a.lerp(b,j/5.0+.15),P.GOLD,maxf(2.0,hex_radius*.04),true)
			elif animal != "":
				draw_arc(c,hex_radius*.45,0,TAU,40,P.GOLD,maxf(2.0,hex_radius*.04),true)
			return
		if tile_id > 0:
			Painter.tile(self,c,hex_radius,tile_id,tile_rotation)
		elif animal != "":
			Painter.token(self,c,hex_radius*.39,animal)

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)
	resized.connect(func(): request_fit(_camera_moving()))
	_ghost = GhostView.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.modulate.a = .58
	_ghost.visible = false
	add_child(_ghost)
	_ghost_ring = GhostView.new()
	_ghost_ring.ring_only = true
	_ghost_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_ring.visible = false
	add_child(_ghost_ring)
	if not animations:
		pulse = 1.0
		return
	var tween = create_tween()
	tween.tween_property(self,"pulse",1.0,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_redraw)
	set_process(true)

func _process(delta: float) -> void:
	if animations: clock += delta
	_update_ghost()
	if pulse < 1.0:
		queue_redraw()
	elif animations and (not legal_animals.is_empty() or not highlight.is_empty() or preview_key != ""):
		# Gentle breathing for legal spots, score highlights and the pending tile (~30 fps).
		_frame_wait += delta
		if _frame_wait >= .033:
			_frame_wait = 0.0
			queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		_drag_tile = 0
		if not _keyboard_cursor: _set_hover(NO_CELL)

func land(cell: Vector2i, animal: bool) -> void:
	if not animations: return
	if landing_tween: landing_tween.kill()
	landing_cell = cell
	landing_animal = animal
	landing_progress = 0.0
	landing_tween = create_tween()
	landing_tween.tween_method(func(t: float):
		landing_progress = t
		queue_redraw(),0.0,1.0,.20)

func stop_landing() -> void:
	if landing_tween: landing_tween.kill()
	landing_progress = 1.0
	queue_redraw()

func center_board() -> void:
	_fit_camera(true,false)

func restore_camera(camera: Array = []) -> void:
	if _camera_tween: _camera_tween.kill()
	camera_adjusted = not camera.is_empty()
	if camera_adjusted:
		_set_camera(camera[0],camera[1])

func request_fit(force: bool = false) -> void:
	if camera_adjusted or not is_inside_tree(): return
	_force_fit = _force_fit or force
	if not _fit_queued:
		_fit_queued = true
		get_tree().process_frame.connect(_fit_after_layout,CONNECT_ONE_SHOT)

func _fit_after_layout() -> void:
	var force = _force_fit
	_fit_queued = false
	_force_fit = false
	if not camera_adjusted and is_inside_tree():
		_fit_camera(force,animations and Feedback.enabled)

func _fit_camera(force: bool, animate: bool) -> void:
	if cells.is_empty() or size.x <= 0 or size.y <= 0: return
	var bounds = Rect2(H.to_pixel(H.coord(cells.keys()[0]),radius),Vector2.ZERO)
	for k in cells:
		bounds = bounds.expand(H.to_pixel(H.coord(k),radius))
	for p in frontier+camera_frontier:
		bounds = bounds.expand(H.to_pixel(p,radius))
	bounds = bounds.grow(radius)
	var margin = (size*.4).min(Vector2.ONE*CAMERA_MARGIN)
	var visible_area = Rect2(margin,size-margin*2)
	var moving = _camera_moving()
	var fit_pan = _target_pan if moving else pan
	var fit_zoom = _target_zoom if moving else zoom
	var projected = Rect2(size*.5+fit_pan+bounds.position*fit_zoom,bounds.size*fit_zoom)
	if not force and visible_area.grow(.01).encloses(projected): return
	var fit_scale = visible_area.size/bounds.size
	var next_zoom = minf(1.1,minf(fit_scale.x,fit_scale.y))
	var next_pan = -bounds.get_center()*next_zoom
	if moving and animate and next_pan.is_equal_approx(fit_pan) and is_equal_approx(next_zoom,fit_zoom): return
	if _camera_tween: _camera_tween.kill()
	_target_zoom = next_zoom
	_target_pan = next_pan
	if not animate or (pan.is_equal_approx(next_pan) and is_equal_approx(zoom,next_zoom)):
		_set_camera(next_pan,next_zoom)
		return
	var from_pan = pan
	var from_zoom = zoom
	_camera_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_method(func(t: float):
		_set_camera(from_pan.lerp(next_pan,t),lerpf(from_zoom,next_zoom,t)),0.0,1.0,CAMERA_DURATION)

func _camera_moving() -> bool:
	return _camera_tween != null and _camera_tween.is_running()

func _set_camera(next_pan: Vector2, next_zoom: float) -> void:
	pan = next_pan
	zoom = next_zoom
	queue_redraw()

func _adjust_camera() -> void:
	if _camera_tween: _camera_tween.kill()
	camera_adjusted = true

func screen_position(p: Vector2i) -> Vector2:
	return size*.5+pan+H.to_pixel(p,radius)*zoom

func pan_by(offset: Vector2) -> void:
	_adjust_camera()
	_set_camera(pan+offset,zoom)

func zoom_by(amount: int, anchor: Vector2) -> void:
	_adjust_camera()
	var next = clampf(zoom*(1.12 if amount > 0 else 1.0/1.12),minf(.25,zoom),2.3)
	var offset = anchor-size*.5
	_set_camera(offset-(offset-pan)*(next/zoom),next)

func _cell_at(point: Vector2) -> Vector2i:
	return H.from_pixel((point-size*.5-pan)/zoom,radius)

func _set_hover(cell: Vector2i) -> void:
	hovered = cell
	_update_ghost()
	queue_redraw()

func clear_cursor() -> void:
	_keyboard_cursor = false
	_drag_tile = 0
	_set_hover(NO_CELL)

func update_cursor() -> void:
	if _keyboard_cursor: move_cursor(Vector2.ZERO)

func move_cursor(direction: Vector2) -> bool:
	var targets = frontier if not frontier.is_empty() else legal_animals
	if not interactive or targets.is_empty():
		if _keyboard_cursor: _set_hover(NO_CELL)
		return false
	var origin = H.to_pixel(hovered,radius) if hovered != NO_CELL else -pan/zoom
	var selected = hovered if hovered in targets else NO_CELL
	var best = INF
	if selected == NO_CELL or direction != Vector2.ZERO:
		for cell in targets:
			var offset = H.to_pixel(cell,radius)-origin
			var alignment = 1.0 if hovered not in targets else offset.normalized().dot(direction)
			if alignment < .1: continue
			var distance = offset.length_squared()/alignment
			if distance < best:
				best = distance
				selected = cell
	_keyboard_cursor = true
	_set_hover(selected)
	if direction != Vector2.ZERO:
		var point = screen_position(selected)
		var inset = Vector2.ONE*48
		var visible_point = point.clamp(inset,size-inset)
		if not visible_point.is_equal_approx(point): pan_by(visible_point-point)
	return true

func place_cursor() -> bool:
	if not move_cursor(Vector2.ZERO): return false
	cell_clicked.emit(hovered)
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var cell = _cell_at(event.position)
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
		elif rotation_enabled and (event.is_action_pressed("board_rotate_right",false,true) or event.is_action_pressed("board_rotate_left",false,true)):
			rotation_requested.emit(-1 if event.is_action_pressed("board_rotate_left",false,true) else 1)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1,event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_keyboard_cursor = false
			if event.pressed:
				_sea_origin = event.position
				_sea_press = not cells.has(H.key(cell)) and cell not in frontier
				_sea_dragging = false
				if not _sea_press and interactive: cell_clicked.emit(cell)
			else:
				var click = _sea_press and not _sea_dragging
				_sea_press = false
				_sea_dragging = false
				if click and interactive: cell_clicked.emit(_cell_at(_sea_origin))
	if event is InputEventMouseMotion:
		_keyboard_cursor = false
		if dragging and event.relative != Vector2.ZERO:
			pan_by(event.relative)
		elif _sea_press:
			if _sea_dragging: pan_by(event.relative)
			elif event.position.distance_to(_sea_origin) > SEA_DRAG_THRESHOLD:
				_sea_dragging = true
				pan_by(event.position-_sea_origin)
		_set_hover(_cell_at(event.position))

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if not market_drop_enabled or not data is Dictionary or not data.has("market_row"): return false
	_drag_tile = data.tile
	_keyboard_cursor = false
	var cell = _cell_at(position)
	_set_hover(cell)
	return Rect2(Vector2.ZERO,size).has_point(position) and cell in camera_frontier

func _drop_data(position: Vector2, data: Variant) -> void:
	if _can_drop_data(position,data):
		market_tile_dropped.emit(data,_cell_at(position))
	_drag_tile = 0
	_update_ghost()
	queue_redraw()

func _update_ghost() -> void:
	if not is_instance_valid(_ghost):
		return
	var dragging_tile = _drag_tile > 0 and market_drop_enabled
	var show_tile = interactive and (hovered in camera_frontier if dragging_tile else ghost_tile > 0 and hovered in frontier)
	var show_animal = interactive and not dragging_tile and ghost_animal != "" and hovered in legal_animals and not cells.get(H.key(hovered),{}).get("animal","") == ghost_animal
	_ghost.visible = show_tile or show_animal
	_ghost_ring.visible = _ghost.visible
	if not _ghost.visible:
		return
	var span = radius*2.4*zoom
	var tile_id = (_drag_tile if dragging_tile else ghost_tile) if show_tile else 0
	var animal = "" if show_tile else ghost_animal
	var rotation = 0 if dragging_tile else ghost_rotation
	if _ghost.tile_id != tile_id or _ghost.tile_rotation != rotation or _ghost.animal != animal or not is_equal_approx(_ghost.hex_radius,(radius-2)*zoom):
		_ghost.tile_id = tile_id
		_ghost.tile_rotation = rotation
		_ghost.animal = animal
		_ghost.hex_radius = (radius-2)*zoom
		_ghost.queue_redraw()
		_ghost_ring.tile_id = tile_id
		_ghost_ring.tile_rotation = rotation
		_ghost_ring.animal = animal
		_ghost_ring.hex_radius = _ghost.hex_radius
		_ghost_ring.queue_redraw()
	var lift = Vector2(0,-(7.0+2.5*sin(clock*4.0))*zoom)
	_ghost.size = Vector2(span,span)
	_ghost.position = screen_position(hovered)-_ghost.size*.5+lift
	_ghost_ring.size = _ghost.size
	_ghost_ring.position = screen_position(hovered)-_ghost.size*.5

# The footprint of a thick tile: top face plus the cardboard edge below it.
func _footprint(c: Vector2, r: float) -> PackedVector2Array:
	var top = Painter.polygon(c,r)
	var drop = Vector2(0,r*.085)
	return PackedVector2Array([top[0],top[1]+drop,top[2]+drop,top[3]+drop,top[4],top[5]])

func _draw() -> void:
	_draw_backdrop()
	var breathe = .5+.5*sin(clock*3.2)
	draw_set_transform(size*.5+pan,0,Vector2.ONE*zoom)
	_draw_shore()
	_draw_grid()
	for p in (camera_frontier if _drag_tile > 0 and market_drop_enabled else frontier):
		var c = H.to_pixel(p,radius)
		var selected = p == hovered and interactive
		draw_colored_polygon(Painter.polygon(c,radius-4),Color(1,.98,.9,.34 if not selected else .7))
		if selected and ghost_tile > 0:
			draw_colored_polygon(Painter.polygon(c+Vector2(0,4),radius-8),Color(.1,.14,.08,.2))
		_dashed_hex(c,radius-4,Color(.33,.43,.33,.5) if not selected else P.GOLD_DEEP,1.8 if not selected else 3.0)
		if emphasize_frontier:
			Painter.outline(self,c,radius-4,P.GOLD_DEEP,3.5)
		if not selected:
			draw_line(c-Vector2(6,0),c+Vector2(6,0),Color(.33,.43,.33,.45),2.0,true)
			draw_line(c-Vector2(0,6),c+Vector2(0,6),Color(.33,.43,.33,.45),2.0,true)
	# Paint back-to-front so each tile's cardboard edge sits under the tile below it.
	var order = cells.keys()
	order.sort_custom(func(a,b):
		var pa = H.to_pixel(H.coord(a),radius)
		var pb = H.to_pixel(H.coord(b),radius)
		return pa.y < pb.y or (is_equal_approx(pa.y,pb.y) and pa.x < pb.x))
	for k in order:
		var cell = cells[k]
		var c = H.to_pixel(H.coord(k),radius)
		if landing_progress < 1.0 and H.coord(k) == landing_cell:
			var bounce = sin(landing_progress*PI)*.12
			if landing_animal:
				Painter.tile(self,c,radius-2,int(cell.tile),int(cell.rotation))
				if cell.animal != "":
					Painter.token(self,c-Vector2(0,12*(1.0-landing_progress)),(radius-2)*.39*(1.0+bounce),cell.animal)
			else:
				draw_set_transform(size*.5+pan+c*zoom-Vector2(0,12*(1.0-landing_progress)),0,Vector2.ONE*zoom*(1.0+bounce))
				Painter.tile(self,Vector2.ZERO,radius-2,int(cell.tile),int(cell.rotation),cell.animal)
				draw_set_transform(size*.5+pan,0,Vector2.ONE*zoom)
		elif k == preview_key:
			draw_set_transform(size*.5+pan+c*zoom,rotation_offset*(1.0-pulse),Vector2.ONE*zoom*(.88+.12*pulse))
			Painter.tile(self,Vector2.ZERO,radius-2,int(cell.tile),int(cell.rotation),cell.animal)
			draw_set_transform(size*.5+pan,0,Vector2.ONE*zoom)
		else:
			Painter.tile(self,c,radius-2,int(cell.tile),int(cell.rotation),cell.animal)
	# Overlays sit above every tile so rings and outlines are never covered.
	var choosing = not legal_animals.is_empty()
	var scoring = not highlight.is_empty()
	var scores = placement_points.values()
	var low = float(scores.min()) if not scores.is_empty() else 0.0
	var high = float(scores.max()) if not scores.is_empty() else 0.0
	for k in order:
		var c = H.to_pixel(H.coord(k),radius)
		var p = H.coord(k)
		if choosing and p not in legal_animals:
			draw_colored_polygon(_footprint(c,radius-2),Color(.12,.16,.1,.34))
		if scoring and k not in highlight:
			draw_colored_polygon(_footprint(c,radius-2),Color(.12,.16,.1,.42))
	for k in order:
		var c = H.to_pixel(H.coord(k),radius)
		var p = H.coord(k)
		if k in highlight:
			Painter.outline(self,c,radius-1,Color(1,.86,.42,.25+.2*breathe),9.0)
			Painter.outline(self,c,radius-4,Color(1,.95,.63,.55+.45*pulse),3.0+1.5*pulse)
		if p in legal_animals:
			var points = placement_points.get(p,0)
			var strength = inverse_lerp(low,high,float(points)) if high > low else .5
			var heat = P.MOSS.lerp(P.GOLD_LIGHT,strength)
			heat.a = .18+.40*strength
			draw_colored_polygon(Painter.polygon(c,radius-5),heat)
			var ring = radius*(.43+.03*breathe)
			draw_arc(c,ring,0,TAU,44,Color(.08,.16,.11,.32),6.0,true)
			draw_arc(c,ring,0,TAU,44,Color("fff8d9"),2.8,true)
			draw_arc(c,ring+5,0,TAU,44,Color(P.GOLD.r,P.GOLD.g,P.GOLD.b,.25+.45*breathe),2.0,true)
		if k == preview_key:
			_marching_hex(c,radius+1,P.GOLD,3.0)
		elif p == hovered and interactive and not choosing:
			Painter.outline(self,c,radius,Color(P.GOLD_DEEP.r,P.GOLD_DEEP.g,P.GOLD_DEEP.b,.8),2.5)
		if p == hovered and interactive and choosing and p in legal_animals:
			Painter.outline(self,c,radius,P.GOLD,3.0)
	draw_set_transform(Vector2.ZERO)
	if placement_points.has(hovered):
		var value = "%+d" % placement_points[hovered]
		var label_size = Vector2(58,30)
		var pos = (screen_position(hovered)+Vector2(-29,-radius*zoom-24)).clamp(Vector2.ZERO,size-label_size)
		draw_style_box(P.chip(P.DARK,P.GOLD_LIGHT,8,0,0),Rect2(pos,label_size))
		draw_string(P.font(700),pos+Vector2(0,22),value,HORIZONTAL_ALIGNMENT_CENTER,label_size.x,21,P.CREAM)

# A faint printed hex grid around the player's land: where the map could still grow.
func _draw_grid() -> void:
	if cells.is_empty():
		return
	var printed = {}
	for k in cells:
		var origin = H.coord(k)
		for q in range(-2,3):
			for r in range(maxi(-2,-q-2),mini(2,-q+2)+1):
				var p = origin+Vector2i(q,r)
				var key = H.key(p)
				if not cells.has(key):
					printed[key] = p
	var ink = Color(.36,.4,.26,.12)
	for key in printed:
		var p = printed[key]
		if p in frontier:
			continue
		var c = H.to_pixel(p,radius)
		var points = Painter.polygon(c,radius-3)
		for i in range(6):
			var a = points[i]
			var b = points[(i+1)%6]
			draw_line(a.lerp(b,.12),a.lerp(b,.88),ink,1.2,true)

# The island rises out of shallow water: foam, wet sand and dry sand ring every placed tile.
# Same-colour opaque discs merge, so neighbouring tiles share one continuous beach.
func _draw_shore() -> void:
	if cells.is_empty():
		return
	for layer in [[1.62,SHORE_FOAM],[1.45,SHORE_SHALLOW],[1.33,SHORE_WET],[1.22,SHORE_DRY]]:
		for k in cells:
			draw_circle(H.to_pixel(H.coord(k),radius),radius*float(layer[0]),layer[1],true,-1,true)

# Survey chart of the shallows: pale sea, depth contours, soundings and a compass rose.
func _draw_backdrop() -> void:
	var rect = Rect2(Vector2.ZERO,size)
	draw_style_box(P.box(CHART_SEA,20,Color("9fb9b1")),rect)
	for i in range(10):
		var t = float(i+1)/10.0
		var grow = Vector2(size.x*.36*t,size.y*.34*t)
		var inner = P.box(Color(.94,.98,.94,.045),int(lerpf(40,minf(size.x,size.y)*.32,t)))
		inner.set_border_width_all(0)
		draw_style_box(inner,Rect2(grow,size-grow*2))
	for i in range(11):
		var points = PackedVector2Array()
		for step in range(72):
			var x = float(step)*size.x/71.0
			points.append(Vector2(x,30+i*96+sin(x*.0055+i*.9)*24+sin(x*.013+i*2.1)*7))
		draw_polyline(points,Color(.16,.36,.38,.09 if i%3 else .15),1.2 if i%3 else 1.6,true)
	# Depth soundings, printed in the chart's small italic-free numerals.
	for i in range(26):
		var at = Vector2(Painter._rand(7,i,1)*size.x,Painter._rand(7,i,2)*size.y)
		draw_string(P.font(500),at,str(2+int(Painter._rand(7,i,3)*17)),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(.16,.34,.36,.26))
	if size.x > 400 and size.y > 300:
		var rose = Vector2(size.x-74,size.y-74)
		var ink = Color(.17,.33,.35,.38)
		draw_arc(rose,34,0,TAU,48,ink,1.2,true)
		draw_arc(rose,27,0,TAU,48,Color(ink.r,ink.g,ink.b,.18),1.0,true)
		for a in range(8):
			var dir = Vector2.from_angle(a*PI*.25-PI*.5)
			var side = dir.orthogonal()*(6 if a%2 == 0 else 3.5)
			var reach = 42.0 if a%2 == 0 else 24.0
			draw_colored_polygon(PackedVector2Array([rose+dir*reach,rose+side,rose-side]),Color(ink.r,ink.g,ink.b,.55 if a == 0 else .26))
		draw_string(P.font(700),rose+Vector2(-6,-50),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	# Double inner frame, like a printed survey sheet.
	var frame = P.box(Color(0,0,0,0),14,Color(.2,.38,.38,.32))
	draw_style_box(frame,rect.grow(-9))
	var hairline = P.box(Color(0,0,0,0),11,Color(.2,.38,.38,.18))
	draw_style_box(hairline,rect.grow(-14))

func _dashed_hex(center: Vector2, hex_radius: float, color: Color, width: float) -> void:
	var points = Painter.polygon(center,hex_radius)
	for i in range(6):
		var a = points[i]
		var b = points[(i+1)%6]
		for j in range(4):
			draw_line(a.lerp(b,j/4.0+.04),a.lerp(b,j/4.0+.18),color,width,true)

# A slowly travelling dashed outline marks the pending, not-yet-confirmed tile.
func _marching_hex(center: Vector2, hex_radius: float, color: Color, width: float) -> void:
	var points = Painter.polygon(center,hex_radius)
	var shift = fmod(clock*.6,1.0)/5.0
	for i in range(6):
		var a = points[i]
		var b = points[(i+1)%6]
		for j in range(5):
			var t0 = j/5.0+shift
			draw_line(a.lerp(b,clampf(t0,0,1)),a.lerp(b,clampf(t0+.12,0,1)),color,width,true)

func _get_tooltip(at_position: Vector2) -> String:
	if not show_names: return ""
	var cell_key = H.key(H.from_pixel((at_position-size*.5-pan)/zoom,radius))
	if not cells.has(cell_key): return ""
	var cell = cells[cell_key]
	var tile = TileDefinition.get_tile(int(cell.tile))
	return " / ".join(tile.habitats.map(func(h):return GameLocale.text(TileDefinition.HABITAT_NAMES[h])))+"\n"+(GameLocale.text("入住：")+GameLocale.text(TileDefinition.ANIMAL_NAMES[cell.animal]) if cell.animal != "" else GameLocale.text("可入住：")+ GameLocale.text("、").join(tile.wildlife.map(func(a):return GameLocale.text(TileDefinition.ANIMAL_NAMES[a]))))
