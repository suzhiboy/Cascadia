class_name GameConfig
extends RefCounted

static func normalize(raw: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var result = {"count":clampi(int(raw.get("count",1)),1,4),"names":[],"seats":[],"cards":{}}
	for key in ["survey_id", "daily"]:
		if raw.has(key): result[key] = str(raw[key])
	for i in range(result.count):
		var seats = raw.get("seats",[])
		var seat = str(seats[i]) if seats is Array and i < seats.size() else "human"
		result.seats.append(seat if seat in ["ai_easy","ai_standard"] else "human")
		var names = raw.get("names",[])
		var name = str(names[i]).strip_edges() if i < names.size() else ""
		result.names.append(name if not name.is_empty() else "旅行者 %d" % (i+1))
	for animal in TileDefinition.ANIMALS:
		var card = str(raw.get("cards",{}).get(animal,"A"))
		result.cards[animal] = ["A","B","C","D"][rng.randi_range(0,3)] if card == "random" else card
	return result
