extends SceneTree

const PATH := "user://test-field-records.json"
var failures := 0

func expect(condition: bool, title: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", title)

func _initialize() -> void:
	var source := "res://scripts/core/field_records.gd"
	if not ResourceLoader.exists(source):
		expect(false, "Missing field records")
	else:
		var records = load(source).new(PATH)
		for bad in ["{", "[]", '{"completed":"bad"}', '{"completed":1,"best":{},"cards":{"gobyA":7}}']:
			FileAccess.open(PATH, FileAccess.WRITE).store_string(bad)
			expect(records.read().completed == 0, "Recover corrupt stats")
		var game := GameState.new()
		game.start({"count":1, "daily":"2026-11-25", "survey_id":"first"}, 18)
		game.finished = true
		var scores := Scorer.game_scores(game)
		expect(records.record(game, scores) == OK, "Record score")
		expect(records.record(game, scores) == OK, "Resume finished game")
		var data: Dictionary = records.read()
		expect(data.completed == 1 and data.best["1"] == scores[0].total, "Update best once")
		expect(data.daily["2026-11-25"] == scores[0].total, "Daily best")
		for species in TileDefinition.ANIMALS:
			expect(data.cards[species+"A"].count == 1, "One observation per selected card")
		DirAccess.remove_absolute(PATH)
	print("FIELD RECORDS: %d failures" % failures)
	quit(int(failures > 0))
