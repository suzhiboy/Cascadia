extends SceneTree

var H
var G
var S
var Catalog
var checks = 0
var failures = 0

class OrderedBagState extends GameState:
	var exhausted = false
	func _draw() -> String:
		if bag.is_empty():
			exhausted = true
			return ""
		return bag.pop_front()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/core/game_state.gd"):
		check(false, "Rules module has not been implemented")
		quit(1)
		return
	H = load("res://scripts/core/hex.gd")
	G = load("res://scripts/core/game_state.gd")
	S = load("res://scripts/core/scorer.gd")
	Catalog = load("res://scripts/core/tile_definition.gd")
	test_hex()
	test_scoring()
	test_diagram_examples()
	test_turns()
	test_refresh_and_solo()
	test_habitat_rotation()
	test_full_games()
	test_save_write_failure()
	print("CHECKS: %d  FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)

# Each entry specifies q,r:habitat[+habitat][:resident]. An asterisk is the focal species.
func habitat_tile(terrains: Array, resident: String = "") -> int:
	for tile in Catalog.all().values():
		if tile.habitats.size() == terrains.size() and terrains.all(func(h): return h in tile.habitats):
			if resident.is_empty() or resident in tile.wildlife:
				return tile.id
	assert(false, "Missing test tile for %s / %s" % [terrains, resident])
	return -1

func hand_board(layout: String, species: String) -> Dictionary:
	var board = {}
	for entry in layout.split(" "):
		var fields = entry.split(":")
		var resident = fields[2] if fields.size() > 2 else ""
		if resident == "*":
			resident = species
		var p = H.coord(fields[0])
		board[fields[0]] = {"q":p.x,"r":p.y,"tile":habitat_tile(Array(fields[1].split("+")),resident),"rotation":0,"animal":resident}
	return board

func points(b: Dictionary, animal: String, card: String) -> int:
	return S.wildlife(b, animal, card).points

func test_hex() -> void:
	check(H.neighbors(Vector2i.ZERO).size() == 6, "six neighbors")
	for d in range(6):
		var p = H.DIRS[d]
		check(H.DIRS[(d + 3) % 6] + p == Vector2i.ZERO, "opposite edge")
		check(H.from_pixel(H.to_pixel(p, 70.0), 70.0) == p, "pixel coordinate roundtrip")
	var tile = {"habitats":["reef","pool"]}
	check(H.edge(tile, 0, 3) == "reef", "first habitat is left half")
	check(H.edge(tile, 0, 0) == "pool", "second habitat is right half")
	check(H.edge(tile, 1, 2) == "pool", "rotation moves habitat edges clockwise")
	check(H.edge(tile, 6, 3) == "reef", "six rotations restore tile")

func test_scoring() -> void:
	var cases = [
		["crab","A","0,0:mudflat:*",3],
		["crab","A","0,0:reef:*",2],
		["crab","A","0,0:reef:* 1,0:mudflat",2],
		["crab","B","0,0:mudflat:*",4],
		["crab","B","0,0:mudflat:* 1,0:reef",4],
		["crab","B","0,0:mudflat:* 1,0:reef 0,1:reef -1,1:reef -1,0:reef 0,-1:reef 1,-1:reef",1],
		["crab","C","0,0:mudflat:* 1,0:mudflat:* 0,1:reef:*",11],
		["crab","C","0,0:mudflat:* 1,0:reef:tern",2],
		["crab","C","0,0:mudflat:* 1,0:mudflat:* 2,0:mudflat:*",8],
		["crab","D","0,0:mudflat:* 1,0:reef 0,1:pool",3],
		["crab","D","0,0:mudflat:* 1,0:reef 0,1:reef",2],
		["crab","D","0,0:mudflat:* 1,0:mudflat:* 0,1:reef",3],
		["limpet","A","0,0:reef:* 1,0:reef",3],
		["limpet","A","0,0:pool:*",1],
		["limpet","A","0,0:reef:* 1,0:reef 0,1:reef",3],
		["limpet","B","0,0:reef:* 1,0:reef -1,0:pool",3],
		["limpet","B","0,0:reef:* 1,0:reef 0,1:pool",2],
		["limpet","B","0,0:reef:* 1,0:reef 0,1:reef -1,1:reef -1,0:reef 0,-1:reef 1,-1:reef",3],
		["limpet","C","0,0:reef:* 1,0:reef",2],
		["limpet","C","0,0:reef:* 1,0:pool",1],
		["limpet","C","0,0:reef:* 1,0:reef 0,1:reef",2],
		["limpet","D","0,0:reef:* 1,0:reef:* 2,0:reef:*",11],
		["limpet","D","0,0:reef:* 1,0:reef:* 0,1:reef:*",8],
		["limpet","D","0,0:reef:* 1,-1:reef:* 2,-2:reef:* 3,-3:reef:*",17],
		["tern","A","0,0:shingle:*",3],
		["tern","A","0,0:shingle:* 1,0:reef -1,1:reef 0,-1:reef",1],
		["tern","A","0,0:shingle:* 1,0:reef 0,1:reef -1,1:reef -1,0:reef",2],
		["tern","B","0,0:shingle:* 1,0:reef 0,1:reef",1],
		["tern","B","0,0:shingle:* 1,0:reef 2,0:pool",1],
		["tern","B","0,0:shingle:* 1,0:reef 0,1:reef -1,1:reef",2],
		["tern","C","0,0:shingle:* 1,0:reef 2,0:shingle:*",5],
		["tern","C","0,0:shingle:* 2,0:shingle:*",4],
		["tern","C","0,0:shingle:* 1,0:reef 2,0:shingle:* 2,1:reef 2,2:shingle:*",9],
		["tern","D","0,0:shingle:* 1,0:reef 2,0:marsh",2],
		["tern","D","0,0:shingle:* 2,0:marsh",1],
		["tern","D","0,0:shingle:* 1,0:reef 2,0:marsh 3,0:reef 4,0:shingle:*",3],
		["goby","A","0,0:mudflat:*",3],
		["goby","A","0,0:reef:*",1],
		["goby","A","0,0:mudflat+pool:*",3],
		["goby","B","0,0:mudflat:* 1,0:reef 0,1:shingle",3],
		["goby","B","0,0:mudflat+pool:* 1,0:pool",2],
		["goby","B","0,0:mudflat:* 1,0:reef 0,1:shingle -1,1:marsh",3],
		["goby","C","0,0:reef:* 1,0:mudflat:* 2,0:pool:*",8],
		["goby","C","0,0:reef:* 1,0:reef:*",5],
		["goby","C","0,0:mudflat+pool:* 1,0:pool:*",5],
		["goby","D","0,0:reef:* 1,0:mudflat -1,0:pool",4],
		["goby","D","0,0:reef:* 1,0:mudflat 0,1:pool",2],
		["goby","D","0,0:reef:* 1,0:mudflat+pool -1,0:mudflat+pool",4],
		["otter","A","0,0:pool:* 1,0:reef:crab 0,1:reef:limpet",3],
		["otter","A","0,0:pool:* 1,0:reef:tern",1],
		["otter","A","0,0:pool:* 1,0:reef:crab 0,1:reef:crab",2],
		["otter","B","0,0:pool:* 1,-1:reef 1,0:reef 0,1:reef",3],
		["otter","B","0,0:pool:* 1,0:reef -1,1:reef 0,-1:reef",1],
		["otter","B","0,0:pool:* 1,0:reef 0,1:reef -1,1:reef -1,0:reef",3],
		["otter","C","0,0:pool:* 1,0:shingle:*",7],
		["otter","C","0,0:pool:* 1,0:shingle:* 2,0:reef:*",6],
		["otter","C","0,0:pool:* 1,0:shingle:* 2,0:reef 3,0:pool:* 4,0:reef:*",15],
		["otter","D","0,0:pool:* 1,0:pool 2,0:pool 3,0:pool",5],
		["otter","D","0,0:reef:* 2,0:pool",1],
		["otter","D","0,0:reef:* 1,0:pool 2,0:reef:*",4]
	]
	for item in cases:
		var board = hand_board(item[2],item[0])
		var report = S.wildlife(board,item[0],item[1])
		check(report.points == item[3], "%s %s expected %d, got %d on %s" % [item[0],item[1],item[3],report.points,item[2]])
		var sum = 0
		for group in report.groups:
			sum += group.points
			check(group.cells.all(func(k): return board.has(k)), "highlighted tile exists")
		check(sum == report.points, "explanation adds up")
	check(S.majority([8,8,6,4]) == [2,2,0,0], "tied first majority")
	check(S.majority([8,6,6,4]) == [3,0,0,0], "tied second majority")
	check(S.majority([8,8]) == [1,1], "two-player tie")
	check(S.majority([7]) == [2], "solo corridor threshold")
	check(S.majority([6]) == [0], "solo below threshold")

func test_diagram_examples() -> void:
	var diagram = load("res://scripts/ui/rule_diagram.gd").new()
	for species in Catalog.ANIMALS:
		diagram.animal = species
		for letter in ["A","B","C","D"]:
			diagram.card = letter
			var scores = []
			for side in [false,true]:
				var layout = diagram.example(side)
				for cell in layout.values():
					check(cell.animal == "" or cell.animal in Catalog.get_tile(cell.tile).wildlife, "Diagram token fits its habitat")
				scores.append(points(layout,species,letter))
			check(scores[0] != scores[1], "Diagram illustrates a scoring change for "+species+letter)
	check("compact" in diagram,"Rule diagrams provide compact thumbnails")
	if "compact" in diagram:
		diagram.compact = true
		diagram._ready()
		check(diagram.custom_minimum_size == Vector2(146,90),"Thumbnail reserves room for tiles and the example score")
		check(diagram.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Thumbnail leaves clicks to the card")
	diagram.free()

func test_turns() -> void:
	var g = G.new()
	g.start({"count":1,"names":["测试"],"cards":{}}, 42)
	check(g.deck.size() == 39 and g.market_tiles.size() == 4, "solo 43 tiles including market")
	check(g.players[0].board.size() == 3, "three starter hexes")
	check(g.draft(0,0).is_empty(), "draft pair")
	check(not g.place_tile(Vector2i(100,100),0).is_empty(), "reject detached tile")
	check(not g.place_tile(Vector2i.ZERO,0).is_empty(), "reject occupied tile")
	var edge = g.frontier()[0]
	check(g.place_tile(edge,0).is_empty(), "place adjacent tile")
	check(g.discard_animal().is_empty(), "voluntary token return")
	var copy = G.new()
	copy.restore(g.snapshot())
	check(copy.snapshot() == g.snapshot(), "pending turn save restores exactly")
	check(g.commit_turn().is_empty(), "commit resolved turn")
	copy.commit_turn()
	check(g.snapshot() == copy.snapshot(), "save preserves next draw")
	check(g.players[0].turns == 1 and g.players[0].board.size() == 4, "turn committed once")
	check(not g.commit_turn().is_empty(), "cannot double commit")
	g.players[0].nature = 2
	check(g.refresh([0],true).is_empty(), "nature refresh")
	check(g.refresh([1],true).is_empty(), "second nature action allowed")
	check(not g.refresh([2],true).is_empty(), "nature cannot go negative")
	var saved = g.snapshot()
	var restored = G.new()
	restored.restore(JSON.parse_string(JSON.stringify(saved)))
	g.draft(0,0)
	restored.draft(0,0)
	g.place_tile(g.frontier()[0],2)
	restored.place_tile(restored.frontier()[0],2)
	g.discard_animal()
	restored.discard_animal()
	g.commit_turn()
	restored.commit_turn()
	check(restored.snapshot() == g.snapshot(), "JSON roundtrip preserves RNG and gameplay")
	if restored.snapshot() != g.snapshot():
		for field in g.snapshot():
			if restored.snapshot()[field] != g.snapshot()[field]:
				print("ROUNDTRIP DIFF ",field," ",restored.snapshot()[field]," EXPECT ",g.snapshot()[field])

func test_refresh_and_solo() -> void:
	# A reachable four-player late-game supply: 21 tokens remain off-board.
	# Fixed draw order forces four successive all-limpet replacements.
	var late = OrderedBagState.new()
	late.market_animals = ["crab","crab","crab","crab"]
	for _i in range(16): late.bag.append("limpet")
	late.bag.append("otter")
	late._resolve_four()
	check(not late.exhausted,"Consecutive forced refresh cannot exhaust the bag")
	check("" not in late.market_animals,"Forced refresh never creates empty animal")
	check(late.bag.size()+late.held.size()+late.market_animals.size()==21,"Late refresh preserves 21 tokens")
	var g = G.new()
	g.start({"count":1,"names":[],"cards":{}},3)
	g.market_animals = ["crab","crab","crab","crab"]
	g.bag = ["limpet","limpet","limpet","limpet","limpet","limpet","limpet","limpet","tern","otter","goby"]
	g._resolve_four()
	check(g.market_animals.count(g.market_animals[0]) < 4, "forced wipes repeat until market not all identical")
	check(g.bag.size()+g.market_animals.size()+g.held.size() == 15, "refresh preserves every token")
	g.market_animals = ["crab","crab","crab","otter"]
	g.bag = ["limpet","tern","goby","otter","limpet","tern","goby","otter"]
	g.held.clear()
	g.optional_used = false
	check(g.refresh([0,1,2],false).is_empty(), "free triple wipe")
	check(g.optional_used, "free wipe usage recorded")
	check(not g.refresh([0,1,2],false).is_empty(), "free wipe cannot repeat")
	g = G.new()
	g.start({"count":1,"names":[],"cards":{}},9)
	g.market_tiles = [16,17,18,19]
	g.market_animals = ["crab","limpet","goby","otter"]
	g.players[0].nature = 2
	check(g.draft(1,3).is_empty(), "cross-column draft")
	check(g.players[0].nature == 1, "cross-column draft spends exactly one")
	g.place_tile(g.frontier()[0],0)
	g.discard_animal()
	g.commit_turn()
	check(g.market_tiles.slice(2) == [16,18], "solo tile row slides independently")
	check(g.market_animals.slice(2) == ["crab","limpet"], "solo animal row slides independently")
	check(g.removed_tiles == [19] and g.removed_animals == ["goby"], "solo removes farthest remaining item in each row")
	var before = JSON.stringify(g.snapshot())
	check(not g.refresh([0,0],true).is_empty(), "duplicate refresh index rejected")
	check(JSON.stringify(g.snapshot()) == before, "invalid refresh does not spend or draw")
	g.draft(0,0)
	var legal = g.legal_animal_cells()
	if not legal.is_empty():
		check(g.place_animal(legal[0]).is_empty(), "animal can be placed before tile")
		check(g.pending.tile_pos == null, "animal-first does not force tile")
		g.place_tile(g.frontier()[0],0)
		check(g.ready_to_commit(), "animal-first turn can finish")

func test_habitat_rotation() -> void:
	var b = hand_board("0,0:reef+pool -1,0:reef+pool","")
	var habitat = H.edge(Catalog.get_tile(b["0,0"].tile),0,3)
	check(S.habitats(b)[habitat].points == 1, "opposite terrains do not connect")
	b["-1,0"].rotation = 3
	check(S.habitats(b)[habitat].points == 2, "rotation connects matching edges")
	var colony = hand_board("0,0:reef+pool:* -1,0:reef+pool","limpet")
	check(points(colony,"limpet","C") == 1, "home scar requires facing edges")
	colony["-1,0"].rotation = 3
	check(points(colony,"limpet","C") == 2, "rotation opens home scar")
	var empty = {}
	for animal in ["crab","limpet","goby","tern","otter"]:
		for card in ["A","B","C","D"]:
			check(points(empty,animal,card) == 0, "empty animal scores zero "+animal+card)

func test_full_games() -> void:
	for count in range(1,5):
		var g = G.new()
		g.start({"count":count,"names":[],"cards":{}},100 + count)
		var turns = 0
		while not g.finished and turns < 81:
			var error = g.draft(0,0)
			check(error.is_empty(), "full game draft %d" % count)
			g.place_tile(g.frontier()[0],turns % 6)
			var legal = g.legal_animal_cells()
			if legal.is_empty():
				g.discard_animal()
			else:
				g.place_animal(legal[0])
			check(g.commit_turn().is_empty(), "full game commit")
			var tokens = g.bag.size()+g.held.size()+g.removed_animals.size()+g.market_animals.filter(func(a):return a!="").size()
			for player in g.players:
				for cell in player.board.values():
					if cell.animal != "": tokens += 1
			check(tokens == 100, "token conservation during complete game")
			turns += 1
		check(g.finished and turns == count * 20, "exactly 20 turns per player")
		for player in g.players:
			check(player.board.size() == 23 and player.turns == 20, "final board 23 hexes")
		var report = S.game_scores(g)
		check(report.size() == count, "all players scored")

func test_save_write_failure() -> void:
	var path = "user://tidetrace-test-save.json"
	var g = G.new()
	g.start({"count":1},517)
	check(g.save_game(path)==OK,"Initial save succeeds")
	var original = FileAccess.get_file_as_string(path)
	# Deny the replacement write without changing the existing valid save.
	DirAccess.make_dir_absolute(path+".tmp")
	g.draft(0,0)
	check(g.save_game(path)!=OK,"Unwritable replacement is reported")
	check(FileAccess.get_file_as_string(path)==original,"Failed replacement preserves previous save")
	DirAccess.remove_absolute(path+".tmp")
	check(g.save_game(path)==OK,"Second save replaces first")
	var restored = G.new()
	check(restored.load_game(path) and restored.snapshot()==g.snapshot(),"Replacement save roundtrip")
	DirAccess.remove_absolute(path)
