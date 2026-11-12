extends SceneTree

func _initialize() -> void:
	var file = FileAccess.open("res://build/windows/GODOT-LICENSES.txt",FileAccess.WRITE)
	file.store_string(Engine.get_license_text()+"\n\nThird-party license notices\n\n")
	for entry in Engine.get_copyright_info():
		file.store_string(str(entry)+"\n\n")
	var licenses = Engine.get_license_info()
	for name in licenses:
		file.store_string(name+"\n"+licenses[name]+"\n\n")
	file.close()
	quit()
