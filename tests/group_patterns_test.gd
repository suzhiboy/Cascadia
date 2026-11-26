extends SceneTree

const H = preload("res://scripts/core/hex.gd")
const Cards = preload("res://scripts/core/scoring_card_definition.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ",message)
		failures += 1

func run_shape(animal: String, card: String, positions: Array, bridges: Array, expected: int) -> void:
	for turn in range(6):
		var board = {}
		for point in positions+bridges:
			var rotated = H.rotate(point,turn)+Vector2i(-3,2)
			board[H.key(rotated)] = {"q":rotated.x,"r":rotated.y,"tile":19,"rotation":turn,"animal":animal if point in positions else ""}
		var result = Scorer.wildlife(board,animal,card)
		var seen = []
		var points = 0
		for group in result.groups:
			for key in group.cells:
				check(key not in seen and board[key].animal == animal,"Only unique residents are recorded")
				seen.append(key)
			points += group.points
		check(seen.size() == positions.size() and points == result.points,"Every resident and point is accounted for")
		check(result.points == expected,"%s%s rotated %d expected %d got %d" % [animal,card,turn,expected,result.points])

func _initialize() -> void:
	var o = Vector2i.ZERO
	var e = Vector2i(1,0)
	var s = Vector2i(0,1)
	run_shape("crab","C",[o,e,s,e+s],[],13)
	run_shape("limpet","D",[-e,o,e,-s,s],[],15)
	run_shape("goby","C",[o,e,e+s,e-s,2*e,5*e],[],18)
	run_shape("tern","C",[o,2*e,2*s],[e,s,e+s],9)
	run_shape("tern","C",[o,2*e,2*s],[e],7)
	run_shape("otter","C",[o,e,3*e,4*e,6*e,7*e,8*e],[],21)
	run_shape("otter","C",[o,e,2*e],[],6)
	for id in Cards.PATTERNS:
		var shape = Cards.PATTERNS[id]
		var last = shape.curve.size()
		check(Cards.pattern_points(shape,0) == 0,"Empty pattern scores zero")
		check(Cards.pattern_points(shape,last+1) == 2*shape.curve[-1]-shape.curve[-2],"Long patterns use the final increment")
		var text = Cards.description(id.left(-1),id.right(1))
		check("{" not in text and " / ".join(shape.curve) in text,"Displayed progression matches the scorer")
	print("GROUP PATTERNS: %d failures" % failures)
	quit(int(failures > 0))
