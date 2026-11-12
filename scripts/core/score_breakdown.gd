class_name ScoreBreakdown
extends RefCounted

static func empty() -> Dictionary:
	return {"points":0,"groups":[]}

static func add(result: Dictionary, cells: Array, points: int, label: String = "") -> void:
	if points <= 0:
		return
	result.points += points
	result.groups.append({"cells":cells.duplicate(),"points":points,"label":label})
