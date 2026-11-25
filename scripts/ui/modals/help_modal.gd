extends "res://scripts/ui/modals/modal.gd"

func open(controller) -> void:
	var body = controller._open_modal("潮间带调查手册",1000,900,self)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var content = ui._vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(ui._heading("看图认识动物计分",24,P.DARK))
	var links = ui._hbox(8)
	for animal in T.ANIMALS:
		var selected_card = str(ui.game.config.cards[animal]) if ui.game != null else "A"
		links.add_child(ui._button(T.ANIMAL_NAMES[animal]+" "+selected_card,func():ui.show_card(animal,selected_card)))
	content.add_child(links)
	var field_diagram = load("res://scripts/ui/rule_diagram.gd").new()
	content.add_child(ui._chip(field_diagram,"CardPanel"))
	content.add_child(ui._wrap("试着在图例中移走一枚动物，再放回原处。上方按钮可翻阅本局采用的五张观察卡。",20))
	var sections = [
		["01  选一组，放两次","挑一列，把岛块和动物一起取走。沿任意一条外缘扩建海岸。动物可以先安置，也可等新岛块落定后再安排。"],
		["02  为动物找到家","寻找印有该物种图案的空地块。每格只容纳一只动物。选择放归会将动物送回袋中。在只有一种图案的地块安置动物，可领取一枚自然标记。"],
		["03  自然标记与动物过剩","选取前可以花一枚自然标记，把不同列的两件组件配成一组，或重抽指定的动物。仍有标记就能再次使用。市集中若出现三只同种动物，这回合可免费换掉这三只一次。四只同种会自动重抽。"],
		["04  连接岛岸","转动岛块，让同色生境沿边相接。每种颜色只测量最大的一片，面积每格记一分。动物的得分条件请翻阅右侧观察卡。"],
		["05  独行与同行","独自调查时，每次交接后两列剩余组件的末项各随潮水离开，新组件由上方补入。多人同行时只填空缺。每位调查员各记录二十回合。"],
		["06  终局计分","将观察卡分数、生境面积、面积奖励及手中的自然标记相加。独自调查的七格生境奖两分。两人比较同色面积，领先者奖两分，持平各一分。三至四人按名次奖三分、一分；两人同居首位各两分，更多人同居首位各一分，并列第二没有奖励。总分持平先比标记数，再持平便共享胜利。"],
		["操作与存档","点击地图试摆，Q 和 E 可逐边转向。滚轮调节视野，按住中键平移。确认回合前可撤回摆放。重抽后结果立即生效。下次启动时可从主菜单接续本地调查。"]
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
