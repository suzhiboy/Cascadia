extends SceneTree

func _initialize() -> void:
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		printerr("Could not load export presets")
		quit(1)
		return
	var expected := str(ProjectSettings.get_setting("application/config/version")) + ".0"
	var failures := 0
	var checked := 0
	for section in presets.get_sections():
		if presets.get_value(section, "platform", "") == "Windows Desktop":
			for field in ["file_version", "product_version"]:
				checked += 1
				var actual = presets.get_value(section + ".options", "application/" + field, "")
				if actual != expected:
					printerr("%s: expected %s, got %s" % [field, expected, actual])
					failures += 1
	print("EXPORT VERSIONS: %d checks, %d failures" % [checked, failures])
	quit(0 if checked >= 2 and failures == 0 else 1)
