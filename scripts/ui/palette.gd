extends RefCounted

# Ink, shell paper, oxidised copper and deep coastal water.
const INK = Color("183c44")
const MUTED = Color("5c7071")
const PAPER = Color("f4efdf")
const CARD = Color("fbf6e9")   # matches the wildlife illustration ground
const PAPER_DEEP = Color("e6dfc8")
const LINE = Color("cec6a8")
const GOLD = Color("ba8651")
const GOLD_DEEP = Color("85572d")
const GOLD_LIGHT = Color("eac99b")
const DARK = Color("174551")
const SEA_DEEP = Color("10333e")
const SEA_MID = Color("28616a")
const MOSS = Color("39766d")
const CREAM = Color("f7e9cb")
const SAGE = Color("a9c3ad")
const RUST = Color("a04b39")
const SHADOW = Color(0.03,0.09,0.06,0.28)
const PLAYERS = [Color("80b7a7"),Color("e0aa4f"),Color("74a5cf"),Color("d98269")]
const TERRAIN = {"reef":Color("87939d"),"marsh":Color("83a778"),"shingle":Color("bdb1c0"),"mudflat":Color("c79e74"),"pool":Color("63aeb2")}
const ANIMALS = {"crab":Color("b76045"),"limpet":Color("8d7792"),"goby":Color("66885e"),"tern":Color("5d82a0"),"otter":Color("926341")}
static var fonts: Dictionary = {}

static func font(weight: int = 480, spacing: int = 0) -> FontVariation:
	var key = "%d:%d" % [weight,spacing]
	if not fonts.has(key):
		var variation = FontVariation.new()
		variation.base_font = load("res://assets/fonts/NotoSansSC.ttf")
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):float(weight)}
		variation.spacing_glyph = spacing
		fonts[key] = variation
	return fonts[key]

static func box(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.anti_aliasing = true
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

# A pressed-card button face: thicker lower lip plus a soft drop shadow, same content margins as box().
static func raised(color: Color, radius: int, border: Color, lip: int = 3, shadow: float = 0.16, width: int = 1) -> StyleBoxFlat:
	var style = box(color,radius,border)
	style.set_border_width_all(width)
	style.border_width_bottom = maxi(lip,width)
	if shadow > 0.0:
		style.shadow_color = Color(SHADOW.r,SHADOW.g,SHADOW.b,shadow)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0,2)
	return style

static func panel(color: Color = PAPER, radius: int = 18) -> StyleBoxFlat:
	var style = box(color,radius,Color(0.78,0.70,0.50,0.55))
	style.shadow_color = SHADOW
	style.shadow_size = 14
	style.shadow_offset = Vector2(0,6)
	return style

static func chip(fill: Color, border: Color, radius: int = 8, h: int = 10, v: int = 4) -> StyleBoxFlat:
	var style = box(fill,radius,border)
	style.content_margin_left = h
	style.content_margin_right = h
	style.content_margin_top = v
	style.content_margin_bottom = v
	return style

static func _buttons(theme: Theme, kind: String, styles: Array, colors: Array) -> void:
	var states = ["normal","hover","pressed","disabled"]
	for i in range(states.size()):
		theme.set_stylebox(states[i],kind,styles[i])
	var focus = box(Color(0,0,0,0),12,GOLD)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(3)
	theme.set_stylebox("focus",kind,focus)
	theme.set_color("font_color",kind,colors[0])
	theme.set_color("font_focus_color",kind,colors[0])
	theme.set_color("font_hover_color",kind,colors[1])
	theme.set_color("font_hover_pressed_color",kind,colors[1])
	theme.set_color("font_pressed_color",kind,colors[2])
	theme.set_color("font_disabled_color",kind,colors[3])

# Player tab: translucent on the ocean frame, parchment when it is the board on display.
static func apply_tab(button: Button, color: Color, selected: bool) -> void:
	var fills = [PAPER,CARD,PAPER_DEEP] if selected else [Color(1,1,1,.07),Color(1,1,1,.14),Color(0,0,0,.14)]
	var states = ["normal","hover","pressed"]
	for i in range(3):
		var style = box(fills[i],10,color)
		style.set_border_width_all(0)
		style.border_width_bottom = 4
		button.add_theme_stylebox_override(states[i],style)
	var text = INK if selected else CREAM
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,text)

# Anti-aliased pill toggle / round knob rasterised once, so the settings controls match the theme.
static func _pill(on: bool) -> ImageTexture:
	var w = 52
	var h = 28
	var image = Image.create(w,h,false,Image.FORMAT_RGBA8)
	var track = MOSS if on else Color("cfc5a6")
	var knob_x = w-h*.5 if on else h*.5
	for y in range(h):
		for x in range(w):
			var px = Vector2(x+.5,y+.5)
			var cx = clampf(px.x,h*.5,w-h*.5)
			var d_track = px.distance_to(Vector2(cx,h*.5))-(h*.5-1)
			var d_knob = px.distance_to(Vector2(knob_x,h*.5))-(h*.5-4)
			var color = Color(0,0,0,0)
			var a_track = clampf(.5-d_track,0,1)
			if a_track > 0:
				color = Color(track.r,track.g,track.b,a_track)
			var a_knob = clampf(.5-d_knob,0,1)
			if a_knob > 0:
				color = color.lerp(Color("fffaf0"),a_knob) if color.a > 0 else Color(1,.98,.94,a_knob)
			image.set_pixel(x,y,color)
	return ImageTexture.create_from_image(image)

static func _knob(fill: Color, size: int = 24) -> ImageTexture:
	var image = Image.create(size,size,false,Image.FORMAT_RGBA8)
	var c = Vector2(size,size)*.5
	for y in range(size):
		for x in range(size):
			var d = Vector2(x+.5,y+.5).distance_to(c)
			var outer = clampf(size*.5-1-d+.5,0,1)
			var inner = clampf(size*.5-5-d+.5,0,1)
			var color = Color(GOLD_DEEP.r,GOLD_DEEP.g,GOLD_DEEP.b,outer)
			if inner > 0:
				color = color.lerp(fill,inner)
			image.set_pixel(x,y,color)
	return ImageTexture.create_from_image(image)

static func theme() -> Theme:
	var theme = Theme.new()
	theme.default_font = font(480)
	theme.default_font_size = 21
	theme.set_color("font_color","Label",INK)
	var disabled = raised(Color(0.91,0.88,0.80,0.55),10,Color(0.80,0.76,0.64,0.45),1,0.0)
	var faded = Color("aaa791")
	# Secondary (default) buttons and drop-downs.
	for kind in ["Button","OptionButton"]:
		_buttons(theme,kind,[
			raised(Color("f2ead2"),10,Color("c9ba8e")),
			raised(Color("fbf6e6"),10,GOLD_DEEP),
			raised(Color("e2d8b6"),10,Color("b9a97c"),1,0.0),
			disabled],[INK,DARK,INK,faded])
	# Main call to action.
	theme.set_type_variation("PrimaryButton","Button")
	_buttons(theme,"PrimaryButton",[
		raised(DARK,10,Color("092b34"),3,0.24),
		raised(SEA_MID,10,GOLD,3,0.26),
		raised(SEA_DEEP,10,SEA_DEEP,1,0.0),
		disabled],[CREAM,Color("fff6dc"),CREAM,faded])
	# Chosen option within a group (current mode, selected market slot).
	theme.set_type_variation("ActiveButton","Button")
	var active = raised(GOLD_LIGHT,10,GOLD_DEEP,4,0.18,2)
	var active_hover = raised(Color("f1dfae"),10,GOLD_DEEP,4,0.2,2)
	_buttons(theme,"ActiveButton",[active,active_hover,raised(Color("dcc283"),10,GOLD_DEEP,2,0.0,2),disabled],[INK,INK,INK,faded])
	# Animal marked for replacement during a refresh.
	theme.set_type_variation("MarkedButton","Button")
	_buttons(theme,"MarkedButton",[
		raised(Color("f5ddcf"),10,RUST,4,0.18,2),
		raised(Color("f9e7dc"),10,RUST,4,0.2,2),
		raised(Color("eccab8"),10,RUST,2,0.0,2),
		disabled],[INK,INK,INK,faded])
	# Low-emphasis actions (undo, release, close).
	theme.set_type_variation("QuietButton","Button")
	_buttons(theme,"QuietButton",[
		box(Color(1,1,1,0.25),10,LINE),
		box(Color(GOLD_LIGHT.r,GOLD_LIGHT.g,GOLD_LIGHT.b,0.45),10,GOLD),
		box(PAPER_DEEP,10,GOLD_DEEP),
		box(Color(1,1,1,0.1),10,Color(LINE.r,LINE.g,LINE.b,0.5))],[INK,DARK,INK,faded])
	# Buttons sitting on the dark ocean frame.
	theme.set_type_variation("GhostButton","Button")
	var ghost_line = Color(CREAM.r,CREAM.g,CREAM.b,0.24)
	_buttons(theme,"GhostButton",[
		box(Color(1,1,1,0.07),10,ghost_line),
		box(Color(1,1,1,0.15),10,GOLD),
		box(Color(0,0,0,0.16),10,GOLD),
		box(Color(1,1,1,0.03),10,Color(1,1,1,0.08))],[CREAM,Color("fff6dc"),CREAM,Color(CREAM.r,CREAM.g,CREAM.b,0.35)])
	# Wildlife cards share the illustration ground so the art blends in.
	theme.set_type_variation("CardButton","Button")
	_buttons(theme,"CardButton",[
		raised(CARD,12,Color("ddd0aa"),3,0.14),
		raised(Color("fffaf0"),12,GOLD,3,0.22),
		raised(Color("f1e8d0"),12,GOLD_DEEP,1,0.0),
		disabled],[INK,INK,INK,faded])
	# Compact score cells in the results table.
	theme.set_type_variation("ScoreButton","Button")
	var score_styles = [
		raised(Color("f6efda"),8,Color("d3c59c"),2,0.0),
		raised(Color("fff8e4"),8,GOLD_DEEP,2,0.12),
		raised(GOLD_LIGHT,8,GOLD_DEEP,1,0.0),
		disabled]
	for style in score_styles:
		style.content_margin_top = 3
		style.content_margin_bottom = 3
	_buttons(theme,"ScoreButton",score_styles,[INK,DARK,INK,faded])
	theme.set_stylebox("normal","LineEdit",box(Color("fffaf0"),8,LINE))
	var edit_focus = box(Color(0,0,0,0),9,GOLD)
	edit_focus.set_border_width_all(2)
	theme.set_stylebox("focus","LineEdit",edit_focus)
	theme.set_color("font_color","LineEdit",INK)
	theme.set_color("font_placeholder_color","LineEdit",Color("a7a690"))
	theme.set_color("caret_color","LineEdit",INK)
	theme.set_color("selection_color","LineEdit",Color(GOLD.r,GOLD.g,GOLD.b,0.35))
	theme.set_color("font_color","PopupMenu",INK)
	theme.set_color("font_hover_color","PopupMenu",DARK)
	theme.set_stylebox("panel","PopupMenu",panel(PAPER,12))
	theme.set_stylebox("hover","PopupMenu",box(Color("e4dcbd"),8))
	theme.set_color("font_color","CheckButton",INK)
	theme.set_color("font_hover_color","CheckButton",DARK)
	theme.set_color("font_pressed_color","CheckButton",INK)
	theme.set_color("font_focus_color","CheckButton",INK)
	for state in ["normal","hover","pressed","hover_pressed","focus"]:
		theme.set_stylebox(state,"CheckButton",chip(Color(1,1,1,0) if state != "hover" and state != "hover_pressed" else Color(GOLD_LIGHT.r,GOLD_LIGHT.g,GOLD_LIGHT.b,.3),Color(0,0,0,0) if state != "focus" else GOLD,10,12,8))
	theme.set_icon("checked","CheckButton",_pill(true))
	theme.set_icon("unchecked","CheckButton",_pill(false))
	theme.set_icon("grabber","HSlider",_knob(CREAM))
	theme.set_icon("grabber_highlight","HSlider",_knob(Color("fffaf0"),26))
	# Panels: framed sections, the sunken tray, chips and modal sheets.
	theme.set_stylebox("panel","PanelContainer",panel())
	theme.set_type_variation("BarPanel","PanelContainer")
	var bar = panel(PAPER,16)
	bar.content_margin_left = 20
	bar.content_margin_right = 14
	bar.content_margin_top = 8
	bar.content_margin_bottom = 8
	theme.set_stylebox("panel","BarPanel",bar)
	theme.set_type_variation("SunkenPanel","PanelContainer")
	theme.set_stylebox("panel","SunkenPanel",chip(Color(0.86,0.81,0.66,0.38),Color(0.72,0.65,0.46,0.45),12,6,3))
	theme.set_type_variation("CardPanel","PanelContainer")
	theme.set_stylebox("panel","CardPanel",chip(CARD,Color("e2d7b8"),12,8,6))
	theme.set_type_variation("ModalPanel","PanelContainer")
	var sheet = panel(PAPER,22)
	sheet.set_border_width_all(2)
	sheet.border_color = GOLD
	sheet.shadow_size = 30
	sheet.shadow_offset = Vector2(0,12)
	theme.set_stylebox("panel","ModalPanel",sheet)
	theme.set_type_variation("MenuPanel","PanelContainer")
	var menu = panel(Color(0.97,0.95,0.88,0.95),24)
	menu.set_border_width_all(2)
	menu.border_color = Color(GOLD.r,GOLD.g,GOLD.b,0.7)
	menu.shadow_size = 26
	theme.set_stylebox("panel","MenuPanel",menu)
	var tip = box(DARK,8,GOLD)
	tip.content_margin_left = 12
	tip.content_margin_right = 12
	tip.content_margin_top = 8
	tip.content_margin_bottom = 8
	tip.shadow_color = SHADOW
	tip.shadow_size = 8
	theme.set_stylebox("panel","TooltipPanel",tip)
	theme.set_color("font_color","TooltipLabel",PAPER)
	theme.set_font_size("font_size","TooltipLabel",17)
	var rule = StyleBoxLine.new()
	rule.color = Color(GOLD.r,GOLD.g,GOLD.b,0.55)
	rule.thickness = 2
	theme.set_stylebox("separator","HSeparator",rule)
	var upright = StyleBoxLine.new()
	upright.color = Color(LINE.r,LINE.g,LINE.b,0.9)
	upright.thickness = 1
	upright.vertical = true
	upright.grow_begin = -12
	upright.grow_end = -12
	theme.set_stylebox("separator","VSeparator",upright)
	theme.set_constant("separation","VSeparator",14)
	var track = box(PAPER_DEEP,4,LINE)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	theme.set_stylebox("slider","HSlider",track)
	theme.set_stylebox("grabber_area","HSlider",box(GOLD,4))
	theme.set_stylebox("grabber_area_highlight","HSlider",box(GOLD_DEEP,4))
	var scroll = StyleBoxEmpty.new()
	scroll.content_margin_left = 6
	scroll.content_margin_right = 6
	theme.set_stylebox("scroll","VScrollBar",scroll)
	theme.set_stylebox("grabber","VScrollBar",box(Color(GOLD.r,GOLD.g,GOLD.b,0.55),5))
	theme.set_stylebox("grabber_highlight","VScrollBar",box(GOLD,5))
	theme.set_stylebox("grabber_pressed","VScrollBar",box(GOLD_DEEP,5))
	return theme
