extends Control

const View = preload("res://scripts/ui/view_properties.gd")
const P = preload("res://scripts/ui/palette.gd")
const T = preload("res://scripts/core/tile_definition.gd")
const Cards = preload("res://scripts/core/scoring_card_definition.gd")
const Feedback = preload("res://scripts/ui/feedback.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")

var ui
var title_label: Label

func frame(controller, title: String, width: float, height: float) -> VBoxContainer:
	ui = controller
	var shade = ColorRect.new()
	shade.color = Color(.03,.1,.07,.72)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = PanelContainer.new()
	panel.theme_type_variation = "ModalPanel"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -width*.5
	panel.offset_right = width*.5
	panel.offset_top = -height*.5
	panel.offset_bottom = height*.5
	var body = ui._vbox(18)
	panel.add_child(ui._margin(body,30))
	var header = ui._hbox(12)
	header.add_child(Ornament.make("hex",Vector2(18,20),P.GOLD))
	title_label = ui._heading(title,30,P.DARK)
	header.add_child(title_label)
	ui._spacer(header)
	header.add_child(ui._styled(ui._button("关闭",ui._close_modal),"QuietButton"))
	body.add_child(header)
	return body

# Forms and reference text have no live game fields. Score dialogs override this.
func update(_state: Dictionary) -> void:
	pass
