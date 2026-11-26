extends RefCounted
static var enabled = true

# Bound tweens die with their controls; no timer touches gameplay state.
static func reveal(control: Control, duration: float = 0.22) -> void:
	if not enabled: return
	control.modulate.a = 0.35
	control.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(control,"modulate:a",1.0,duration)

static func count_score(label: Label, points: int) -> void:
	if not enabled:
		label.text = str(points)
		return
	label.custom_minimum_size.x = 100
	label.text = "0"
	var tween = label.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float): label.text = str(roundi(value)),0.0,float(points),0.45)
	tween.tween_callback(func(): label.text = str(points))

static func toast(label: Label, finished: Callable, animated: bool = true) -> Tween:
	var tween = label.create_tween()
	if not enabled or not animated:
		label.modulate.a = 1.0
		tween.tween_interval(.8)
	else:
		label.modulate.a = 0.0
		tween.set_parallel(true)
		tween.tween_property(label,"modulate:a",1.0,.16)
		tween.tween_property(label,"position:y",label.position.y-10.0,.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_interval(.45)
		tween.chain().tween_property(label,"modulate:a",0.0,.25)
	tween.chain().tween_callback(finished)
	return tween
