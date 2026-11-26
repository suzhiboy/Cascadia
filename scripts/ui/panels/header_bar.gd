extends HBoxContainer

const View = preload("res://scripts/ui/view_properties.gd")
const P = preload("res://scripts/ui/palette.gd")
const Ornament = preload("res://scripts/ui/ornament.gd")

var tabs: Array[Button] = []
var last_view := -1

func build(ui) -> void:
	name = "HeaderBar"
	add_theme_constant_override("separation",14)
	var brand = ui._hbox(12)
	brand.custom_minimum_size.x = 300
	brand.add_child(Ornament.make("logo",Vector2(44,48)))
	var wordmark = ui._vbox(0)
	var title = ui._label("TIDETRACE ISLES",24,P.CREAM)
	title.add_theme_font_override("font",P.font(640,4))
	wordmark.add_child(title)
	wordmark.add_child(ui._label(GameLocale.text("潮痕群岛"),15,P.GOLD_LIGHT))
	brand.add_child(wordmark)
	add_child(brand)
	for i in range(ui.game.players.size()):
		var tab = ui._button("",ui._view.bind(i))
		tab.custom_minimum_size = Vector2(210,50)
		tab.clip_text = true
		tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tabs.append(tab)
		add_child(tab)
	ui._spacer(self)
	add_child(ui._styled(ui._button(GameLocale.text("规则"),ui.show_help),"GhostButton"))
	add_child(ui._styled(ui._button(GameLocale.text("设置"),ui.show_settings),"GhostButton"))
	add_child(ui._styled(ui._button(GameLocale.text("退出练习") if ui._practicing else GameLocale.text("主菜单"),func():
		ui._save()
		ui.show_menu()),"GhostButton"))

func update(state: Dictionary) -> void:
	var game = state.game
	for i in range(tabs.size()):
		var tab = tabs[i]
		var player = game.players[i]
		View.apply(tab,&"text",("● " if i == game.active and not game.finished else "")+GameLocale.player_name(player.name))
		View.apply(tab,&"tooltip_text",GameLocale.text("查看 %s 的生态版图") % GameLocale.player_name(player.name))
		if last_view < 0 or (state.view != last_view and i in [last_view,state.view]):
			P.apply_tab(tab,P.PLAYERS[i%P.PLAYERS.size()],i == state.view)
			if i == state.view: tab.add_theme_font_override("font",P.font(640))
			else: tab.remove_theme_font_override("font")
	last_view = state.view
