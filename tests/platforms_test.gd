extends SceneTree

func _initialize() -> void:
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var found := []
	for section in presets.get_sections():
		if presets.has_section_key(section, "platform"):
			found.append(presets.get_value(section, "platform"))
	var ok := true
	for platform in ["Web","Linux","macOS","Windows Desktop"]:
		if platform not in found:
			printerr("Missing preset: ", platform)
			ok = false
	print("EXPORT PLATFORMS: ", found)
	quit(0 if ok else 1)
