extends Node

var repository := str(ProjectSettings.get_setting("updates/github_repository", "")).strip_edges()
const PACKAGE = "TidetraceIsles-Windows-x64.zip"

func _ready() -> void:
	if repository.is_empty() or OS.has_feature("web"):
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 8
	http.body_size_limit = 1048576
	if http.request("https://api.github.com/repos/%s/releases/latest" % repository, ["User-Agent: TidetraceIsles-Updater"]) != OK:
		return
	var reply: Array = await http.request_completed
	if reply[0] != HTTPRequest.RESULT_SUCCESS or reply[1] != 200:
		return
	var release = JSON.parse_string(reply[3].get_string_from_utf8())
	if not release is Dictionary:
		return
	var tag := str(release.get("tag_name", ""))
	var local := str(ProjectSettings.get_setting("application/config/version"))
	if not newer(tag.trim_prefix("v"), local):
		return
	if not OS.has_feature("windows"):
		_offer(tag, str(release.get("body", "")).left(500), "https://github.com/%s/releases/latest" % repository, "")
		return
	var url := "https://github.com/%s/releases/download/%s/%s" % [repository, tag, PACKAGE]
	for asset in release.get("assets", []):
		if asset.get("browser_download_url") == url:
			var digest := str(asset.get("digest", "")).trim_prefix("sha256:")
			if digest.length() == 64 and digest.is_valid_hex_number(false):
				_offer(tag, str(release.get("body", "")).left(500), url, digest)
			return

static func newer(candidate: String, current: String) -> bool:
	var a := candidate.split(".")
	var b := current.split(".")
	if a.size() != 3 or b.size() != 3:
		return false
	for part in a + b:
		if not part.is_valid_int() or str(part.to_int()) != part or part.to_int() < 0:
			return false
	for i in 3:
		if a[i].to_int() != b[i].to_int():
			return a[i].to_int() > b[i].to_int()
	return false

func _offer(tag: String, notes: String, url: String, digest: String) -> void:
	var dialog := ConfirmationDialog.new()
	add_child(dialog)
	dialog.title = GameLocale.text("发现新版本 ") + tag
	dialog.dialog_text = notes if notes else GameLocale.text("新版游戏已可下载。")
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.ok_button_text = GameLocale.text("更新并重启") if OS.has_feature("windows") else GameLocale.text("查看发布页")
	dialog.cancel_button_text = GameLocale.text("稍后")
	if OS.has_feature("windows"):
		dialog.confirmed.connect(_download.bind(url, digest), CONNECT_ONE_SHOT)
	else:
		dialog.confirmed.connect(func(): OS.shell_open(url), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(540, 300))

func _download(url: String, digest: String) -> void:
	var info := AcceptDialog.new()
	add_child(info)
	info.title = GameLocale.text("游戏更新")
	info.dialog_text = GameLocale.text("正在下载更新…")
	info.get_ok_button().hide()
	info.unresizable = true
	info.popup_centered(Vector2i(420, 150))
	var dir := ProjectSettings.globalize_path("user://").path_join("TidetraceIsles-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec()))
	var success := DirAccess.make_dir_absolute(dir) == OK
	var zip := dir.path_join("update.zip")
	var script := dir.path_join("install.ps1")
	if success:
		var http := HTTPRequest.new()
		add_child(http)
		http.timeout = 300
		http.download_file = zip
		success = http.request(url) == OK
		if success:
			var reply: Array = await http.request_completed
			success = reply[0] == HTTPRequest.RESULT_SUCCESS and reply[1] == 200 and FileAccess.get_sha256(zip) == digest
			if not info.visible:
				DirAccess.remove_absolute(zip)
				DirAccess.remove_absolute(dir)
				return
	if success:
		success = DirAccess.copy_absolute("res://scripts/update/install.ps1", script) == OK
	if success:
		var ps := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
		var pid := OS.create_process(ps, ["-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", script, "-GameExe", OS.get_executable_path(), "-GamePid", str(OS.get_process_id())])
		if pid > 0:
			get_tree().quit()
			return
	for path in [zip, script, dir]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
	info.dialog_text = GameLocale.text("更新失败，当前版本仍可游玩。请稍后重新启动游戏再试。")
	info.get_ok_button().show()
	info.popup_centered()
