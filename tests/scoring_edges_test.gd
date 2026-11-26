extends SceneTree

const S = preload("res://scripts/core/scorer.gd")
const Board = preload("res://scripts/ui/board.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func cell(tile: int, animal: String = "", rotation: int = 0) -> Dictionary:
	return {"tile":tile,"rotation":rotation,"animal":animal}

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ",message)
		failures += 1

func edges(cells: Dictionary, card: String, expected: Dictionary, label: String) -> void:
	check(S.wildlife_edges(cells,"0,0",card) == expected,label)

func run() -> void:
	var shells = {"0,0":cell(16,"limpet"),"1,0":cell(3,"",3),"0,1":cell(36)}
	edges(shells,"C",{"0,0":[0],"1,0":[3]},"Matching terrain lights both facing sides")
	shells["1,0"].rotation = 0
	edges(shells,"C",{},"Rotating the shared edge away removes the match, despite a shared terrain")
	shells["1,0"].rotation = 3
	edges(shells,"A",{},"Whole-tile reef bonuses do not depend on the joining edge")
	shells["-1,0"] = cell(17)
	edges(shells,"B",{"0,0":[0,3]},"Only the fully occupied opposite pair shines")
	shells.erase("-1,0")
	var crabs = {"0,0":cell(31,"crab"),"1,0":cell(33,"crab"),"2,0":cell(47),"0,1":cell(36)}
	edges(crabs,"D",{"0,1":[4,5],"2,0":[3]},"Crab sampling follows the entire colony and marks the neighbors' edges")
	edges(crabs,"B",{"0,0":[2,3,4,5]},"Crab openings exclude occupied directions")
	var crossing = {"0,0":cell(19,"goby"),"1,0":cell(31),"-1,0":cell(4),"0,1":cell(36)}
	edges(crossing,"D",{"0,0":[0,3]},"Opposite neighbors supply whole-tile terrain even if it faces away")
	var terns = {"0,0":cell(27,"tern"),"1,0":cell(16),"2,0":cell(21),"0,1":cell(17),"0,-2":cell(21)}
	edges(terns,"B",{},"Two neighbors 60 degrees apart do not form a fork")
	terns["-1,1"] = cell(17)
	edges(terns,"B",{"0,0":[0,2]},"A 120-degree fork marks its arms")
	edges(terns,"D",{"0,0":[0],"1,0":[0],"2,0":[3]},"Flight ends at the landing after a real intermediate tile")
	terns["2,0"].animal = "tern"
	edges(terns,"C",{"0,0":[0],"1,0":[0],"2,0":[3]},"Stepping-stone terns mark the link across the intermediate tile")
	terns.erase("1,0")
	edges(terns,"C",{},"A gap breaks the flock link")
	var row = {"0,0":cell(16,"limpet"),"1,0":cell(37,"limpet"),"2,0":cell(18,"limpet"),"0,1":cell(16,"limpet")}
	edges(row,"D",{"0,0":[0],"1,0":[0,3],"2,0":[3]},"Only the longest limpet line supplies the shape bonus")
	var takeoff = {"0,0":cell(27,"tern"),"0,1":cell(17),"-1,1":cell(17),"-1,0":cell(17),"0,-1":cell(17)}
	edges(takeoff,"A",{"0,0":[0,5]},"Open consecutive sides wrap from the last edge to the first")
	var otter = {"0,0":cell(38,"otter"),"1,0":cell(36),"2,0":cell(37),"0,1":cell(17),"1,-1":cell(17)}
	edges(otter,"B",{"0,0":[0,1,5]},"Three neighboring sides wrap across the start of the ring")
	edges(otter,"D",{"0,0":[0],"1,0":[0,3],"2,0":[3]},"A patrol lights the connected seams of the touched tide pool")

	var board = Board.new()
	board.animations = false
	board.interactive = false
	root.add_child(board)
	board.size = Vector2(800,600)
	board.cells = shells
	board.scoring_cards = {"limpet":"C"}
	var before = board.cells.duplicate(true)
	var motion = InputEventMouseMotion.new()
	motion.position = board.screen_position(Vector2i.ZERO)
	board._gui_input(motion)
	check(board.scoring_edge_marks == {"0,0":[0],"1,0":[3]},"Mouse hover shows static marks even on a read-only board")
	check(before == board.cells,"Inspecting wildlife leaves the board untouched")
	board.cells["1,0"].rotation = 0
	board.refresh_scoring_edges()
	check(board.scoring_edge_marks.is_empty(),"The edges follow board updates while the cursor stays put")
	board.cells["1,0"].rotation = 3
	board.refresh_scoring_edges()
	board.pan_by(Vector2(130,0))
	check(board.scoring_edge_marks.is_empty(),"Panning an animal away from the pointer clears its marks")
	board.pan_by(Vector2(-130,0))
	check(board.scoring_edge_marks == {"0,0":[0],"1,0":[3]},"Marks return when panning puts the animal under the pointer")
	board.notification(Control.NOTIFICATION_MOUSE_EXIT)
	check(board.scoring_edge_marks.is_empty(),"Leaving the board clears every mark")
	board.queue_free()
	await process_frame
	print("SCORING EDGES: %d failures" % failures)
	quit(1 if failures else 0)
