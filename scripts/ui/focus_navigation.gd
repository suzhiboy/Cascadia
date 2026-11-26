extends RefCounted

const DIRECTIONS = [Vector2.LEFT,Vector2.UP,Vector2.RIGHT,Vector2.DOWN]
const NEIGHBORS = [&"focus_neighbor_left",&"focus_neighbor_top",&"focus_neighbor_right",&"focus_neighbor_bottom"]

static func update(scope: Control) -> void:
	var controls: Array[Control] = []
	for node in scope.find_children("*","Control",true,false):
		if node is ScrollContainer: node.follow_focus = true
		if node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree() and not (node is BaseButton and node.disabled):
			controls.append(node)
	if controls.is_empty(): return
	for i in range(controls.size()):
		var control = controls[i]
		var center = control.get_global_rect().get_center()
		var scores = [INF,INF,INF,INF]
		var neighbors = [control,control,control,control]
		for other in controls:
			if other == control: continue
			var offset = other.get_global_rect().get_center()-center
			for side in range(4):
				var forward = offset.dot(DIRECTIONS[side])
				if forward <= 1.0: continue
				var score = forward+absf(offset.cross(DIRECTIONS[side]))*3.0
				if score < scores[side]:
					scores[side] = score
					neighbors[side] = other
		for side in range(4):
			control.set(NEIGHBORS[side],control.get_path_to(neighbors[side]))
		control.focus_next = control.get_path_to(controls[(i+1)%controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(i-1,controls.size())])
	if scope.get_viewport().gui_get_focus_owner() not in controls:
		controls[0].grab_focus()
