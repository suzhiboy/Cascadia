extends Node
var scene
var session
var role = ""
var acted = {}
var began = false
var ready_sent = false
var elapsed = 0.0
var count = 2
func _ready() -> void:
	role = OS.get_cmdline_user_args()[-1]
	call_deferred("run")
func run() -> void:
	count = maxi(2,int(OS.get_environment("TIDETRACE_TEST_COUNT")))
	scene = get_parent()
	session = scene.lan_session
	session.lobby_changed.connect(lobby)
	session.state_changed.connect(state)
	if role == "host":
		session.host_lobby({"count":count,"host_name":"房主","port":36721})
	else:
		session.join_lobby("127.0.0.1",36721,"客人"+role,int(role.trim_prefix("client")))
func lobby(data: Dictionary) -> void:
	if role != "host" and not ready_sent:
		ready_sent = true
		session.set_ready(true)
	if role == "host" and not began and data.slots.all(func(slot):return slot.connected and slot.ready):
		began = true
		session.host_start_game.call_deferred()
func state(snapshot: Dictionary, revision: int) -> void:
	if snapshot.finished:
		print("STATE HASH ",JSON.stringify(snapshot).sha256_text())
		print("LAN PASS ",role," revision=",revision," turns=",snapshot.players.map(func(p):return p.turns))
		# Give reliable packets time to reach the other process.
		get_tree_finish.call_deferred()
		return
	if session.local_seat() != snapshot.active or acted.has(revision): return
	acted[revision] = true
	step.call_deferred()
func get_tree_finish() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)
func step() -> void:
	var g = session.game
	if g.pending.is_empty(): session.request("draft",{"tile_index":0,"animal_index":0})
	elif g.pending.tile_pos == null:
		var p = g.frontier()[0]
		session.request("place_tile",{"q":p.x,"r":p.y,"rotation":0})
	elif not g.pending.discarded: session.request("discard_animal")
	else: session.request("commit_turn")
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 25:
		printerr("LAN FAIL timeout ",role)
		get_tree().quit(1)
