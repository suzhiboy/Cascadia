extends RefCounted

const JsonFile = preload("res://scripts/core/json_file.gd")
const VERSION := 3
var path: String

func _init(storage_path: String = "user://field_records.json") -> void:
	path = storage_path

static func empty() -> Dictionary:
	return {"version":VERSION, "completed":0, "best":{}, "last":{}, "daily":{}, "cards":{}, "recorded":{}}

func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return empty()
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return empty()
	var data = parser.data
	if not data is Dictionary or not _number(data.get("completed")):
		return empty()
	var version = data.get("version",1)
	if version == 1:
		data.last = {}
	elif version != 2 and version != VERSION:
		return empty()
	for key in ["best", "last", "daily", "cards", "recorded"]:
		if not data.get(key) is Dictionary:
			return empty()
	for section in [data.best, data.last, data.daily]:
		for value in section.values():
			if not _number(value):
				return empty()
	for value in data.cards.values():
		if not value is Dictionary or not _number(value.get("sum")) or not _number(value.get("count")):
			return empty()
		if value.count < 1:
			return empty()
	if version < VERSION:
		for key in data.cards.keys():
			data.cards["legacy/"+key] = data.cards[key]
			data.cards.erase(key)
		data.version = VERSION
	return data

static func _number(value) -> bool:
	return (value is float or value is int) and value >= 0 and value == floor(value)

static func _survey_id(game: GameState) -> String:
	var id := str(game.config.get("survey_id", ""))
	return JSON.stringify(game.snapshot()).sha256_text() if id.is_empty() else id

func result_context(game: GameState) -> Dictionary:
	var data := read()
	var seats := str(game.players.size())
	var entry = data.recorded.get(_survey_id(game))
	var previous = entry.get("previous") if entry is Dictionary else null
	var best_before = entry.get("best_before") if entry is Dictionary else null
	return {"best":data.best.get(seats), "daily":data.daily.get(str(game.config.get("daily",""))),
		"previous":previous if _number(previous) else null, "best_before":best_before if _number(best_before) else null}

func record(game: GameState, scores: Array) -> Error:
	if not game.finished or scores.size() != game.players.size():
		return ERR_INVALID_DATA
	var data := read()
	var id := _survey_id(game)
	if data.recorded.has(id):
		return OK
	var seats := str(game.players.size())
	var date := str(game.config.get("daily",""))
	data.recorded[id] = {"previous":data.last.get(seats), "best_before":data.best.get(seats)}
	var total = scores.map(func(score):return int(score.total)).max()
	data.last[seats] = total
	data.best[seats] = maxi(int(data.best.get(seats,0)),total)
	if not date.is_empty():
		data.daily[date] = maxi(int(data.daily.get(date,0)),total)
	for score in scores:
		for species in game.config.cards:
			var key: String = species + game.config.cards[species]
			var entry: Dictionary = data.cards.get(key, {"sum":0, "count":0})
			entry.sum += score.wildlife[species].points
			entry.count += 1
			data.cards[key] = entry
	data.completed += 1
	return JsonFile.write(path, data)
