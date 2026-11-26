extends "res://scripts/ui/modals/modal.gd"

func open(controller) -> void:
	controller.lan_modal_body = controller._open_modal(GameLocale.text("局域网联机"),900,980,self)
	ui.lan_modal_body.add_child(ui._wrap(GameLocale.text("房主创建 2–4 人房间；可从局域网列表加入，也可输入主机 IP。联机局使用独立状态，不覆盖离线存档。"),20,P.MUTED))
	ui.lan_room_list = ui._vbox(6)
	ui.lan_room_list.add_child(ui._label(GameLocale.text("正在搜索局域网房间……"),17,P.MUTED))
	ui.lan_modal_body.add_child(ui.lan_room_list)
	ui.lan_discovery.start_scan()
	var host_name = LineEdit.new()
	host_name.placeholder_text = GameLocale.text("房主名字")
	host_name.text = GameLocale.text("房主")
	host_name.custom_minimum_size.y = 50
	ui.lan_modal_body.add_child(host_name)
	var count = OptionButton.new()
	count.custom_minimum_size.y = 50
	for i in range(2,5):
		count.add_item(GameLocale.text("%d 人联机") % i)
	ui.lan_modal_body.add_child(count)
	var host_row = ui._hbox(10)
	var host_button = ui._button(GameLocale.text("创建房间"),func():
		var error = ui.lan_session.host_lobby({"count":count.selected+2,"host_name":host_name.text,"cards":{},"port":ui.LanProtocol.DEFAULT_GAME_PORT})
		if error != OK:
			ui.status = GameLocale.text("创建房间失败：端口 %d 不可用。") % ui.LanProtocol.DEFAULT_GAME_PORT
		else:
			ui.status = GameLocale.text("房间已创建，等待另一位旅行者加入。")
			render_lobby(), true)
	host_row.add_child(host_button)
	ui.lan_modal_body.add_child(host_row)
	ui.lan_modal_body.add_child(HSeparator.new())
	var address = LineEdit.new()
	address.placeholder_text = GameLocale.text("主机 IP，例如 192.168.1.20")
	address.text = ""
	address.custom_minimum_size.y = 50
	ui.lan_modal_body.add_child(address)
	var join_name = LineEdit.new()
	join_name.placeholder_text = GameLocale.text("你的名字")
	join_name.text = GameLocale.text("旅行者")
	join_name.custom_minimum_size.y = 50
	ui.lan_modal_body.add_child(join_name)
	var seat = OptionButton.new()
	seat.custom_minimum_size.y = 50
	for i in range(2,5):
		seat.add_item(GameLocale.text("申请第 %d 个座位") % i)
	ui.lan_modal_body.add_child(seat)
	ui.lan_modal_body.add_child(ui._button(GameLocale.text("加入房间"),func():
		var error = ui.lan_session.join_lobby(address.text.strip_edges(),ui.LanProtocol.DEFAULT_GAME_PORT,join_name.text,seat.selected+1)
		ui.status = GameLocale.text("正在连接房主……") if error == OK else GameLocale.text("无法连接到房间。")
		render_lobby()))
	ui.lan_modal_body.add_child(ui._wrap(GameLocale.text("默认端口 35721。Windows 首次联网时，请允许应用访问专用网络。"),16,P.MUTED))

func render_lobby() -> void:
	if not is_instance_valid(ui.lan_modal_body):
		return
	for child in ui.lan_modal_body.get_children():
		if child != ui.lan_modal_body.get_child(0) and child != ui.lan_modal_body.get_child(1):
			ui.lan_modal_body.remove_child(child)
			child.queue_free()
	ui.lan_modal_body.add_child(ui._wrap(ui.status,20,P.RUST))
	var lobby = ui.lan_session._lobby
	if lobby.has("slots"):
		for slot in lobby.slots:
			ui.lan_modal_body.add_child(ui._label(GameLocale.text("座位 %d · %s · %s") % [int(slot.seat)+1,str(slot.name) if not str(slot.name).is_empty() else GameLocale.text("空位"),GameLocale.text("已准备") if slot.ready else (GameLocale.text("未准备") if slot.connected else GameLocale.text("未连接"))],20))
		var name_row = ui._hbox(8)
		var name_input = LineEdit.new()
		name_input.max_length = 12
		name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_input.text = lobby.slots[ui.lan_session.local_seat()].name
		name_row.add_child(name_input)
		name_row.add_child(ui._button(GameLocale.text("修改名字"),func():ui.lan_session.set_local_name(name_input.text)))
		ui.lan_modal_body.add_child(name_row)
		if not ui.lan_session.is_host():
			var ready = bool(lobby.slots[ui.lan_session.local_seat()].ready)
			ui.lan_modal_body.add_child(ui._button(GameLocale.text("取消准备") if ready else GameLocale.text("准备好了"),func():ui.lan_session.set_ready(not ready),true))
		var card_row = ui._hbox(8)
		for animal in T.ANIMALS:
			var column = ui._vbox(5)
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_child(ui._label(GameLocale.text(T.ANIMAL_NAMES[animal]),18))
			var choice = OptionButton.new()
			var values = ["A","B","C","D","random"]
			for value in values: choice.add_item(GameLocale.text("随机") if value == "random" else value)
			choice.select(maxi(0,values.find(str(lobby.cards.get(animal,"A")))))
			choice.disabled = not ui.lan_session.is_host()
			choice.item_selected.connect(func(index):
				var cards = ui.lan_session._lobby.cards.duplicate()
				cards[animal] = values[index]
				ui.lan_session.host_set_cards(cards))
			column.add_child(choice)
			card_row.add_child(column)
		ui.lan_modal_body.add_child(card_row)
	if ui.lan_session.is_host():
		var addresses = []
		for ip in IP.get_local_addresses():
			if str(ip).contains(".") and not str(ip).begins_with("127."):
				addresses.append(str(ip))
		ui.lan_modal_body.add_child(ui._wrap(GameLocale.text("房主 IPv4：")+ " / ".join(addresses)+GameLocale.text("\n端口 35721 · 请朋友选择热点网卡对应地址。"),18,P.MUTED))
		var start_button = ui._button(GameLocale.text("开始联机对局"),func():
			var error = ui.lan_session.host_start_game()
			if not error.is_empty():
				ui.status = error
				render_lobby())
		start_button.disabled = not lobby.slots.all(func(slot):return slot.connected and slot.ready and not str(slot.name).is_empty())
		ui.lan_modal_body.add_child(start_button)
	ui.lan_modal_body.add_child(ui._button(GameLocale.text("离开房间 / 重试"),func():
		ui.lan_session.shutdown()
		ui.lan_discovery.stop()
		ui.show_lan_lobby()))
