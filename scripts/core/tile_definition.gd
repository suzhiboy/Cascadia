class_name TileDefinition
extends RefCounted

const ANIMALS = ["crab","limpet","goby","tern","otter"]
const HABITATS = ["reef","marsh","shingle","mudflat","pool"]
const ANIMAL_NAMES = {"crab":"招潮蟹","limpet":"帽贝","goby":"弹涂鱼","tern":"燕鸥","otter":"水獭"}
const HABITAT_NAMES = {"reef":"岩礁","marsh":"盐沼","shingle":"砾滩","mudflat":"泥滩","pool":"潮池"}
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
