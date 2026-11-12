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
	test_turns()
	test_refresh_and_solo()
	test_habitats_and_optimum()
	test_full_games()
	test_save_write_failure()
	print("CHECKS: %d  FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func board_for(animal: String, coords: Array) -> Dictionary:
	var b = {}
	for c in coords:
		b[H.key(c)] = {"q":c.x,"r":c.y,"tile":16,"rotation":0,"animal":animal}
	return b

func points(b: Dictionary, animal: String, card: String) -> int:
	return S.wildlife(b, animal, card).points

func test_hex() -> void:
	check(H.neighbors(Vector2i.ZERO).size() == 6, "six neighbors")
	for d in range(6):
		var p = H.DIRS[d]
		check(H.DIRS[(d + 3) % 6] + p == Vector2i.ZERO, "opposite edge")
		check(H.from_pixel(H.to_pixel(p, 70.0), 70.0) == p, "pixel coordinate roundtrip")
	var tile = {"habitats":["forest","river"]}
	check(H.edge(tile, 0, 3) == "forest", "source artwork first habitat is left half")
	check(H.edge(tile, 0, 0) == "river", "source artwork second habitat is right half")
	check(H.edge(tile, 1, 2) == "river", "rotation moves habitat edges clockwise")
	check(H.edge(tile, 6, 3) == "forest", "six rotations restore tile")

func test_scoring() -> void:
	var pair = [Vector2i(0,0),Vector2i(1,0)]
	var triple = pair + [Vector2i(2,0)]
	var four = triple + [Vector2i(3,0)]
	check(points(board_for("bear",pair),"bear","A") == 4, "bear A pair")
	check(points(board_for("bear",triple),"bear","A") == 0, "bear A rejects oversized group")
	check(points(board_for("bear",triple),"bear","B") == 10, "bear B triple")
	check(points(board_for("bear",pair),"bear","B") == 0, "bear B rejects pair")
	var mixed = board_for("bear",[Vector2i(0,0),Vector2i(4,0),Vector2i(5,0),Vector2i(9,0),Vector2i(10,0),Vector2i(11,0)])
	check(points(mixed,"bear","C") == 18, "bear C once-only diversity bonus")
	check(points(board_for("bear",four),"bear","D") == 13, "bear D four")
	check(points(board_for("bear",[Vector2i.ZERO]),"bear","D") == 0, "bear D isolated")
	check(points(board_for("elk",four),"elk","A") == 13, "elk A line")
	var diamond = [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]
	check(points(board_for("elk",diamond),"elk","B") == 13, "elk B diamond")
	check(points(board_for("elk",four),"elk","B") == 10, "elk B straight four splits into pairs")
	check(points(board_for("elk",diamond),"elk","C") == 10, "elk C connected arbitrary shape")
	check(points(board_for("elk",H.neighbors(Vector2i.ZERO)),"elk","D") == 21, "elk D complete ring")
	check(points(board_for("elk",[Vector2i.ZERO]),"elk","D") == 2, "elk D single")
	check(points(board_for("salmon",four),"salmon","A") == 12, "salmon A four")
	check(points(board_for("salmon",triple),"salmon","B") == 9, "salmon B three")
	check(points(board_for("salmon",triple),"salmon","C") == 10, "salmon C three")
	check(points(board_for("salmon",pair),"salmon","C") == 0, "salmon C short run")
	var run = board_for("salmon",triple)
	run["0,-1"] = {"q":0,"r":-1,"animal":"fox","tile":16,"rotation":0}
	check(points(run,"salmon","D") == 4, "salmon D unique adjacent token")
	check(points(board_for("salmon",pair),"salmon","D") == 0, "salmon D minimum three")
	check(points(board_for("salmon",diamond),"salmon","A") == 0, "salmon rejects branching component")
	var birds = board_for("hawk",[Vector2i(0,0),Vector2i(2,0),Vector2i(4,0)])
	check(points(birds,"hawk","A") == 8, "hawk A isolated")
	check(points(birds,"hawk","B") == 9, "hawk B visible isolated")
	check(points(birds,"hawk","C") == 6, "hawk C nearest visible pair only")
	check(points(board_for("hawk",pair),"hawk","A") == 0, "hawk A adjacent invalid")
	check(points(board_for("hawk",pair),"hawk","C") == 0, "hawk C requires one intervening hex")
	check(points(board_for("hawk",pair),"hawk","D") == 0, "hawk D no intervening animals")
	birds["1,0"] = {"q":1,"r":0,"animal":"bear","tile":16,"rotation":0}
	birds["3,0"] = {"q":3,"r":0,"animal":"elk","tile":16,"rotation":0}
	check(points(birds,"hawk","D") == 4, "hawk D no repeated hawk")
	var fox = board_for("fox",[Vector2i.ZERO])
	for i in range(6):
		var p = H.DIRS[i]
		fox[H.key(p)] = {"q":p.x,"r":p.y,"animal":["bear","bear","elk","elk","salmon","salmon"][i],"tile":16,"rotation":0}
	check(points(fox,"fox","A") == 3, "fox A variety")
	check(points(fox,"fox","B") == 7, "fox B three distinct pairs")
	check(points(fox,"fox","C") == 2, "fox C most abundant")
	var fox_pair = board_for("fox",pair)
	fox_pair["0,-1"] = {"q":0,"r":-1,"animal":"bear","tile":16,"rotation":0}
	fox_pair["1,-1"] = {"q":1,"r":-1,"animal":"bear","tile":16,"rotation":0}
	check(points(fox_pair,"fox","D") == 5, "fox D union counts shared neighbor once")
	check(points(board_for("fox",pair),"fox","D") == 0, "fox D empty surroundings")
	check(S.majority([8,8,6,4]) == [2,2,0,0], "tied first majority")
	check(S.majority([8,6,6,4]) == [3,0,0,0], "tied second majority")
	check(S.majority([8,8]) == [1,1], "two-player tie")
	check(S.majority([7]) == [2], "solo corridor threshold")
	check(S.majority([6]) == [0], "solo below threshold")

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
	# Fixed draw order forces four successive all-elk replacements.
	var late = OrderedBagState.new()
	late.market_animals = ["bear","bear","bear","bear"]
	for _i in range(16): late.bag.append("elk")
	late.bag.append("fox")
	late._resolve_four()
	check(not late.exhausted,"Consecutive forced refresh cannot exhaust the bag")
	check("" not in late.market_animals,"Forced refresh never creates empty animal")
	check(late.bag.size()+late.held.size()+late.market_animals.size()==21,"Late refresh preserves 21 tokens")
	var g = G.new()
	g.start({"count":1,"names":[],"cards":{}},3)
	g.market_animals = ["bear","bear","bear","bear"]
	g.bag = ["elk","elk","elk","elk","elk","elk","elk","elk","hawk","fox","salmon"]
	g._resolve_four()
	check(g.market_animals.count(g.market_animals[0]) < 4, "forced wipes repeat until market not all identical")
	check(g.bag.size()+g.market_animals.size()+g.held.size() == 15, "refresh preserves every token")
	g.market_animals = ["bear","bear","bear","fox"]
	g.bag = ["elk","hawk","salmon","fox","elk","hawk","salmon","fox"]
	g.held.clear()
	g.optional_used = false
	check(g.refresh([0,1,2],false).is_empty(), "free triple wipe")
	check(g.optional_used, "free wipe usage recorded")
	check(not g.refresh([0,1,2],false).is_empty(), "free wipe cannot repeat")
	g = G.new()
	g.start({"count":1,"names":[],"cards":{}},9)
	g.market_tiles = [16,17,18,19]
	g.market_animals = ["bear","elk","salmon","fox"]
	g.players[0].nature = 2
	check(g.draft(1,3).is_empty(), "cross-column draft")
	check(g.players[0].nature == 1, "cross-column draft spends exactly one")
	g.place_tile(g.frontier()[0],0)
	g.discard_animal()
	g.commit_turn()
	check(g.market_tiles.slice(2) == [16,18], "solo tile row slides independently")
	check(g.market_animals.slice(2) == ["bear","elk"], "solo animal row slides independently")
	check(g.removed_tiles == [19] and g.removed_animals == ["salmon"], "solo removes farthest remaining item in each row")
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

func test_habitats_and_optimum() -> void:
	var b = {"0,0":{"tile":41,"rotation":0,"animal":"","q":0,"r":0},"-1,0":{"tile":41,"rotation":0,"animal":"","q":-1,"r":0}}
	check(S.habitats(b).mountain.points == 1, "same tile types with wrong edges do not connect")
	b["-1,0"].rotation = 3
	check(S.habitats(b).mountain.points == 2, "rotation connects correct mountain edges")
	# A greedy 4-line leaves two singles (17); two crossing 3-lines yield 18.
	var elk = board_for("elk",[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(0,1),Vector2i(0,2)])
	check(points(elk,"elk","A") == 18, "elk uses globally best disjoint lines, not longest first")
	var empty = {}
	for animal in ["bear","elk","salmon","hawk","fox"]:
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
	var path = "user://cascadia-test-save.json"
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
