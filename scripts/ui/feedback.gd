extends RefCounted
static var enabled = true

# Bound tweens die with their controls; no timer touches gameplay state.
static func reveal(control: Control, duration: float = 0.22) -> void:
	if not enabled: return
	control.modulate.a = 0.35
	control.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(control,"modulate:a",1.0,duration)

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
