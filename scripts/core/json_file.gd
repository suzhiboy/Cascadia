extends RefCounted

static func write(path: String, value: Dictionary) -> Error:
	var temporary = path+".tmp"
	var file = FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written = file.store_string(JSON.stringify(value))
	file.flush()
	var error = file.get_error()
	file.close()
	if not written or error != OK:
		DirAccess.remove_absolute(temporary)
		return ERR_FILE_CANT_WRITE
	return DirAccess.rename_absolute(temporary,path)
