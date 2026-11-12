class_name TileDefinition
extends RefCounted

const ANIMALS = ["bear","elk","salmon","hawk","fox"]
const HABITATS = ["mountain","forest","prairie","wetland","river"]
const ANIMAL_NAMES = {"bear":"棕熊","elk":"麋鹿","salmon":"鲑鱼","hawk":"红尾鵟","fox":"赤狐"}
const HABITAT_NAMES = {"mountain":"山地","forest":"森林","prairie":"草原","wetland":"湿地","river":"河流"}
static var records: Dictionary = {}

static func all() -> Dictionary:
	if records.is_empty():
		var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/tiles.json"))
		for tile in raw:
			tile.id = int(tile.id)
			tile.rotation = int(tile.rotation)
			records[tile.id] = tile
	return records

static func get_tile(id: int) -> Dictionary:
	return all()[id]

static func keystone(id: int) -> bool:
	return get_tile(id).wildlife.size() == 1
