extends SceneTree

const T = preload("res://scripts/core/tile_definition.gd")
var failures = 0

func expect(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ", message)
		failures += 1

func _initialize() -> void:
	var catalog = T.all()
	expect(catalog.size() == 100,"Five start trios and 85 draft tiles")
	var counts = {}
	var species = ["crab","limpet","goby","tern","otter"]
	var shores = ["reef","marsh","shingle","mudflat","pool"]
	for id in range(1,101):
		var tile = catalog[id]
		var pair = tile.habitats.duplicate()
		pair.sort()
		var legal_shores = tile.habitats.all(func(h): return h in shores)
		var legal_hosts = tile.wildlife.all(func(a): return a in species)
		expect(legal_shores and legal_hosts,"Coastal habitats and hosts on tile %d" % id)
		expect(tile.wildlife.size() in [1,2,3],"One to three hosts on tile %d" % id)
		if id >= 16:
			var key = "/".join(pair)
			counts[key] = counts.get(key,0)+1
	for i in range(shores.size()):
		expect(counts.get(shores[i],0) == 5,"Five single-shore tiles per coast")
		for j in range(i):
			var pair = [shores[i],shores[j]]
			pair.sort()
			expect(counts.get("/".join(pair),0) == 6,"Six transitions per habitat pair")
	for group in range(5):
		var available = {}
		for id in range(group*3+1,group*3+4):
			for animal in catalog[id].wildlife:
				available[animal] = true
		expect(available.size() == 5,"Each starting cove offers every species a home")
	print("TILE CATALOG: ", failures, " failures")
	quit(1 if failures else 0)
