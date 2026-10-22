extends Node
## GTK: VI automatic Windows updater.
## Discover all releases (including pre-alphas), download, verify SHA-256, stage, exit and restart.
const VersionInfo = preload("res://scripts/version_info.gd")
const CURRENT_VERSION = "0.1.4"
const CURRENT_VERSION_DISPLAY = "0.1.4-prealpha @ 1.104"
const REPO = "dmdelia/gtk-vi"
const API = "https://api.github.com/repos/%s/releases?per_page=30" % REPO
const EXE_NAME = "GTK-VI.exe"
const PCK_NAME = "GTK-VI.pck"
const ASSET_NAME = "GTK-VI-windows.zip"
const INSTALLER_RESOURCE = "res://tools/install_update.ps1"

var game
var auto_update = true
var request: HTTPRequest
var phase = "idle"
var zip_digest = ""
var new_version = ""
var downloaded_file = ""
var stage_dir = ""
var api_asset: Dictionary = {}
var restart_queued = false

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 120
	request.max_redirects = 8
	add_child(request)
	request.request_completed.connect(_handle_response)

func check_now() -> void:
	if phase in ["checking", "downloading", "staging", "restarting"]:
		_status("Das Update wird bereits vorbereitet.")
		return
	phase = "checking"
	request.download_file = ""
	var headers = PackedStringArray(["User-Agent: GTK-VI-Updater", "Accept: application/vnd.github+json", "Cache-Control: no-cache"])
	var result = request.request(API, headers)
	if result != OK:
		phase = "idle"
		_status("Updateprüfung nicht möglich (%d)." % result)
	else:
		_status("GTK: VI sucht nach Updates ...")

func _newer(version: String) -> bool:
	return VersionInfo.is_newer(version, CURRENT_VERSION)

func _find_newest(releases: Variant) -> Dictionary:
	var newest: Dictionary = {}
	if not releases is Array:
		return newest
	for entry in releases:
		if not entry is Dictionary or bool(entry.get("draft", false)):
			continue
		var tag: String = str(entry.get("tag_name", ""))
		if not _newer(tag):
			continue
		var chosen_asset: Dictionary = {}
		for asset in entry.get("assets", []):
			if asset is Dictionary and str(asset.get("name", "")) == ASSET_NAME:
				chosen_asset = asset
				break
		if chosen_asset.is_empty():
			continue
		if newest.is_empty() or VersionInfo.is_newer(tag, str(newest.get("tag_name", ""))):
			newest = {"tag_name": tag, "asset": chosen_asset}
	return newest

func _handle_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		phase = "idle"
		_status("Update fehlgeschlagen (Netzwerk/HTTP %d)." % code)
		return
	if phase == "checking":
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if not parsed is Array:
			phase = "idle"
			_status("Ungültige GitHub-Antwort bei der Updateprüfung.")
			return
		var release = _find_newest(parsed)
		if release.is_empty():
			phase = "idle"
			_status("GTK: VI ist aktuell (%s)." % CURRENT_VERSION_DISPLAY)
			return
		new_version = str(release.get("tag_name", ""))
		api_asset = release.get("asset", {})
		var digest = str(api_asset.get("digest", ""))
		if not digest.begins_with("sha256:") or digest.length() != 71:
			phase = "idle"
			_status("Download gesperrt: gültiger SHA-256-Digest fehlt.")
			return
		zip_digest = digest.trim_prefix("sha256:").to_lower()
		if not auto_update:
			phase = "idle"
			_status("Update %s verfügbar. Auto-Updates sind deaktiviert." % new_version)
			return
		_start_download()
	elif phase == "downloading":
		phase = "staging"
		if not FileAccess.file_exists(downloaded_file) or FileAccess.get_sha256(downloaded_file).to_lower() != zip_digest:
			phase = "idle"
			_status("Update verworfen: SHA-256-Prüfsumme stimmt nicht.")
			return
		if not _extract_and_stage():
			phase = "idle"
			_status("Update-Dateien konnten nicht vorbereitet werden.")
			return
		_status("Update %s geprüft. Spiel wird neu gestartet ..." % new_version)
		# Defer so HTTPRequest finishes its callback before the scene tree closes.
		call_deferred("_install_and_restart")

func _start_download() -> void:
	var url = str(api_asset.get("browser_download_url", ""))
	if not url.begins_with("https://github.com/dmdelia/gtk-vi/releases/download/"):
		phase = "idle"
		_status("Download-URL ist ungültig.")
		return
	var update_root = ProjectSettings.globalize_path("user://updates")
	if DirAccess.make_dir_recursive_absolute(update_root) != OK:
		phase = "idle"
		_status("Update-Ordner kann nicht erstellt werden.")
		return
	downloaded_file = update_root.path_join("GTK-VI-release.zip")
	request.download_file = downloaded_file
	phase = "downloading"
	var started = request.request(url, PackedStringArray(["User-Agent: GTK-VI-Updater"]))
	if started != OK:
		phase = "idle"
		_status("Download konnte nicht gestartet werden (%d)." % started)
	else:
		_status("Update %s wird heruntergeladen ..." % new_version)

func _extract_and_stage() -> bool:
	var zip = ZIPReader.new()
	if zip.open(downloaded_file) != OK:
		return false
	var files = zip.get_files()
	if not files.has(EXE_NAME) or not files.has(PCK_NAME):
		zip.close()
		return false
	stage_dir = ProjectSettings.globalize_path("user://updates/staged")
	if DirAccess.make_dir_recursive_absolute(stage_dir) != OK:
		zip.close()
		return false
	for item in [EXE_NAME, PCK_NAME]:
		var bytes = zip.read_file(item)
		if bytes.size() < 4096:
			zip.close()
			return false
		var output = FileAccess.open(stage_dir.path_join(item), FileAccess.WRITE)
		if output == null:
			zip.close()
			return false
		output.store_buffer(bytes)
		output.close()
	zip.close()
	return true

func _install_and_restart() -> void:
	if restart_queued or phase != "staging":
		return
	if OS.get_name() != "Windows":
		phase = "idle"
		_status("Automatische Installation wird nur unter Windows unterstützt.")
		return
	var original_executable = OS.get_executable_path()
	var original_name = original_executable.get_file()
	if original_name.to_lower() not in ["gtk-vi.exe", "karton-eu-iv.exe"]:
		phase = "idle"
		_status("Bitte Update aus der installierten Windows-EXE starten.")
		return
	var installer_text = FileAccess.get_file_as_string(INSTALLER_RESOURCE)
	if installer_text.is_empty():
		phase = "idle"
		_status("Update-Installationsprogramm fehlt.")
		return
	var installer_path = ProjectSettings.globalize_path("user://updates/install_update.ps1")
	var writer = FileAccess.open(installer_path, FileAccess.WRITE)
	if writer == null:
		phase = "idle"
		_status("Update-Installationsprogramm kann nicht gespeichert werden.")
		return
	writer.store_string(installer_text)
	writer.close()
	# Fail fast on portable folders without write permission rather than closing the game.
	var install_dir = original_executable.get_base_dir()
	var probe_path = install_dir.path_join(".gtk-vi-write-check")
	var probe = FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		phase = "idle"
		_status("Installationsordner ist schreibgeschützt. Bitte manuell aktualisieren.")
		return
	probe.close()
	DirAccess.remove_absolute(probe_path)
	var parameters = PackedStringArray([
		"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
		"-File", installer_path,
		"-ParentProcessId", str(OS.get_process_id()),
		"-InstallDirectory", install_dir,
		"-StageDirectory", stage_dir,
		"-OldExecutable", original_name
	])
	var child_pid = OS.create_process("powershell.exe", parameters)
	if child_pid <= 0:
		phase = "idle"
		_status("Windows-Updater konnte nicht gestartet werden.")
		return
	restart_queued = true
	phase = "restarting"
	if game != null:
		game.save_game()
	get_tree().quit()

func install_on_exit() -> void:
	# Legacy entry point retained for compatibility with menu/close handlers.
	# Installation is triggered by download completion, never by an unrelated quit.
	pass

func _status(message: String) -> void:
	if game != null:
		game.notify(message, 5.0)
		if game.hud != null and game.hud.update_label != null:
			game.hud.update_label.text = message
