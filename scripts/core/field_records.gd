extends RefCounted

const JsonFile = preload("res://scripts/core/json_file.gd")
var path: String

func _init(storage_path: String = "user://field_records.json") -> void:
	path = storage_path

static func empty() -> Dictionary:
	return {"completed":0, "best":{}, "daily":{}, "cards":{}, "recorded":{}}

func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return empty()
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return empty()
	var data = parser.data
	if not data is Dictionary or not _number(data.get("completed")):
		return empty()
	for key in ["best", "daily", "cards", "recorded"]:
		if not data.get(key) is Dictionary:
			return empty()
	for section in [data.best, data.daily]:
		for value in section.values():
			if not _number(value):
				return empty()
	for value in data.cards.values():
		if not value is Dictionary or not _number(value.get("sum")) or not _number(value.get("count")):
			return empty()
		if value.count < 1:
			return empty()
	return data

static func _number(value) -> bool:
	return (value is float or value is int) and value >= 0 and value == floor(value)

func record(game: GameState, scores: Array) -> Error:
	if not game.finished or scores.size() != game.players.size():
		return ERR_INVALID_DATA
	var data := read()
	var id := str(game.config.get("survey_id", ""))
	if id.is_empty():
		id = JSON.stringify(game.snapshot()).sha256_text()
	if data.recorded.has(id):
		return OK
	var seats := str(game.players.size())
	var date := str(game.config.get("daily",""))
	for score in scores:
		data.best[seats] = maxi(int(data.best.get(seats,0)), int(score.total))
		if not date.is_empty():
			data.daily[date] = maxi(int(data.daily.get(date,0)), int(score.total))
		for species in game.config.cards:
			var key: String = species + game.config.cards[species]
			var entry: Dictionary = data.cards.get(key, {"sum":0, "count":0})
			entry.sum += score.wildlife[species].points
			entry.count += 1
			data.cards[key] = entry
	data.completed += 1
	data.recorded[id] = true
	return JsonFile.write(path, data)
