extends "res://scripts/ui/modals/modal.gd"

func open(controller) -> void:
	var body = controller._open_modal(GameLocale.text("潮间带调查手册"),1000,900,self)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var content = ui._vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(ui._heading(GameLocale.text("看图认识动物计分"),24,P.DARK))
	var links = ui._hbox(8)
	for animal in T.ANIMALS:
		var selected_card = str(ui.game.config.cards[animal]) if ui.game != null else "A"
		links.add_child(ui._button(GameLocale.text(T.ANIMAL_NAMES[animal])+" "+selected_card,func():ui.show_card(animal,selected_card)))
	content.add_child(links)
	content.add_child(ui._heading(GameLocale.text(T.ANIMAL_NAMES.limpet)+" C · "+Cards.title("limpet","C"),21,P.DARK))
	content.add_child(ui._wrap(GameLocale.text("金线标出符合计分条件的边。点击动物把它移走，再点原处放回，看看分数怎么变。"),20))
	var field_diagram = preload("res://scripts/ui/rule_diagram.gd").new()
	field_diagram.animal = "limpet"
	field_diagram.card = "C"
	content.add_child(ui._chip(field_diagram,"CardPanel"))
	content.add_child(ui._wrap(GameLocale.text("对局中，把鼠标停在动物所在的地块上，就能看到相关的计分边。符合条件的边都可能亮起，实际加分仍按卡上的上限算。"),18,P.MUTED))
	content.add_child(ui._heading(GameLocale.text("计分小词表"),24,P.DARK))
	for entry in [
		"相邻：两块地共用一条边。",
		"相接的两条边：两块地碰在一起的那一对边。",
		"正对的两侧：从动物往一边看一格，再往完全相反的方向看一格。",
		"空地块：已经铺好、但没有动物。没铺地块的位置叫未铺空位。",
		"地貌：地块上的地形。算同种地貌连片时，相接的两条边必须是同种地貌。"
	]:
		content.add_child(ui._wrap(GameLocale.text(entry),19))
	var sections = [
		[GameLocale.text("01  选一组，放两次"),GameLocale.text("挑一列，把岛块和动物一起取走。沿任意一条外缘扩建海岸。动物可以先安置，也可等新岛块落定后再安排。")],
		[GameLocale.text("02  为动物找到家"),GameLocale.text("寻找印有该物种图案的空地块。每格只容纳一只动物。选择放归会将动物送回袋中。在只有一种图案的地块安置动物，可领取一枚自然标记。")],
		[GameLocale.text("03  自然标记与动物过剩"),GameLocale.text("选取前可以花一枚自然标记，把不同列的两件组件配成一组，或重抽指定的动物。仍有标记就能再次使用。市集中若出现三只同种动物，这回合可免费换掉这三只一次。四只同种会自动重抽。")],
		[GameLocale.text("04  连接岛岸"),GameLocale.text("转动岛块，让同色生境沿边相接。每种颜色只测量最大的一片，面积每格记一分。动物的得分条件请翻阅右侧观察卡。")],
		[GameLocale.text("05  独行与同行"),GameLocale.text("独自调查时，每次交接后两列剩余组件的末项各随潮水离开，新组件由上方补入。多人同行时只填空缺。每位调查员各记录二十回合。")],
		[GameLocale.text("06  终局计分"),GameLocale.text("将观察卡分数、生境面积、面积奖励及手中的自然标记相加。独自调查的七格生境奖两分。两人比较同色面积，领先者奖两分，持平各一分。三至四人按名次奖三分、一分；两人同居首位各两分，更多人同居首位各一分，并列第二没有奖励。总分持平先比标记数，再持平便共享胜利。")],
		[GameLocale.text("操作与存档"),GameLocale.text("点击地图试摆，Q 和 E 可逐边转向。滚轮调节视野，按住中键平移。确认回合前可撤回摆放。重抽后结果立即生效。下次启动时可从主菜单接续本地调查。")]
	]
	for i in range(sections.size()):
		var section = sections[i]
		var title = ui._hbox(10)
		title.add_child(Ornament.make("hex",Vector2(16,18),P.GOLD))
		title.add_child(ui._heading(section[0],24,P.DARK))
		content.add_child(title)
		var text = ui._wrap(section[1],20,P.INK)
		text.add_theme_constant_override("line_spacing",6)
		content.add_child(text)
		if i < sections.size()-1:
			var gap = Control.new()
			gap.custom_minimum_size.y = 8
			content.add_child(gap)
