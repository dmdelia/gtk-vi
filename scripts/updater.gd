extends Node
## GitHub Releases updater: validates digest, stages a ZIP and swaps files on quit.
## The remote repository and a published release are prerequisites.
const VersionInfo = preload("res://scripts/version_info.gd")
const CURRENT_VERSION = "0.1.2"
const CURRENT_VERSION_DISPLAY = "0.1.2-prealpha @ 1.102"
const REPO = "dmdelia/gtk-vi"
const API = "https://api.github.com/repos/%s/releases/latest" % REPO
var game
var auto_update = true
var request: HTTPRequest
var phase = "idle"
var zip_digest = ""
var new_version = ""
var staged = false
var downloaded_file = ""
var api_asset: Dictionary = {}

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 15
	add_child(request)
	request.request_completed.connect(_handle_response)

func check_now() -> void:
	if phase in ["checking","downloading"]:
		return
	phase = "checking"
	request.download_file = ""
	var headers = PackedStringArray(["User-Agent: KartonEU-IV-Updater", "Accept: application/vnd.github+json"])
	var result = request.request(API,headers)
	if result != OK:
		phase = "idle"
		_status("Updateprüfung nicht möglich: %s" % result)
	else:
		_status("GitHub-Releases werden geprüft ...")

func _newer(version: String) -> bool:
	return VersionInfo.is_newer(version, CURRENT_VERSION)

func _handle_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		phase = "idle"
		_status("Keine Release-Verbindung (%d). Weiterhin Version %s." % [code,CURRENT_VERSION_DISPLAY])
		return
	if phase == "checking":
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if not parsed is Dictionary:
			phase = "idle"
			return
		new_version = str(parsed.get("tag_name",""))
		if not _newer(new_version):
			phase = "idle"
			_status("KARTON EU IV ist aktuell (%s)." % CURRENT_VERSION_DISPLAY)
			return
		api_asset = {}
		for asset in parsed.get("assets",[]):
			if str(asset.get("name","")).ends_with("windows.zip"):
				api_asset = asset
				break
		if api_asset.is_empty():
			phase = "idle"
			_status("Neues Release vorhanden, aber kein Windows-Paket.")
			return
		var digest = str(api_asset.get("digest",""))
		if not digest.begins_with("sha256:"):
			phase = "idle"
			_status("Download gesperrt: Release enthält keinen SHA-256-Digest.")
			return
		zip_digest = digest.trim_prefix("sha256:").to_lower()
		if not auto_update:
			phase = "idle"
			_status("Version %s verfügbar. Auto-Updates sind deaktiviert." % new_version)
			return
		_start_download()
	elif phase == "downloading":
		phase = "idle"
		if FileAccess.get_sha256(downloaded_file).to_lower() != zip_digest:
			DirAccess.remove_absolute(downloaded_file)
			_status("Download-Prüfsumme ungültig. Update verworfen.")
			return
		if _extract_and_stage():
			staged = true
			_status("Update %s heruntergeladen und geprüft. Wird beim Beenden installiert." % new_version)
		else:
			_status("Update konnte nicht sicher vorbereitet werden.")

func _start_download() -> void:
	var url = str(api_asset.get("browser_download_url",""))
	if not url.begins_with("https://github.com/"):
		phase = "idle"
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://updates"))
	downloaded_file = ProjectSettings.globalize_path("user://updates/release.zip")
	request.download_file = downloaded_file
	phase = "downloading"
	if request.request(url,PackedStringArray(["User-Agent: KartonEU-IV-Updater"])) != OK:
		phase = "idle"
		_status("Download konnte nicht gestartet werden.")
	else:
		_status("Update %s wird im Hintergrund geladen ..." % new_version)

func _extract_and_stage() -> bool:
	var reader = ZIPReader.new()
	if reader.open(downloaded_file) != OK:
		return false
	var stage_dir = ProjectSettings.globalize_path("user://updates/staged")
	DirAccess.make_dir_recursive_absolute(stage_dir)
	var allowed = ["KARTON-EU-IV.exe", "KARTON-EU-IV.pck"]
	var count = 0
	for path in reader.get_files():
		if path not in allowed:
			continue
		var bytes = reader.read_file(path)
		if bytes.is_empty():
			continue
		var dst = FileAccess.open(stage_dir.path_join(path),FileAccess.WRITE)
		if dst == null:
			reader.close()
			return false
		dst.store_buffer(bytes)
		dst.close()
		count += 1
	reader.close()
	return count == 2

func install_on_exit() -> void:
	if not staged or OS.get_name() != "Windows":
		return
	var executable = OS.get_executable_path()
	if not executable.get_file().to_lower().ends_with(".exe"):
		return
	var dir = executable.get_base_dir()
	var source = ProjectSettings.globalize_path("user://updates/staged")
	var batch = ProjectSettings.globalize_path("user://updates/apply-update.cmd")
	var lines = "@echo off\r\ntimeout /t 3 /nobreak >nul\r\n"
	lines += "copy /Y \"%s\" \"%s\" >nul\r\n" % [source.path_join("KARTON-EU-IV.exe"),dir.path_join("KARTON-EU-IV.exe")]
	lines += "copy /Y \"%s\" \"%s\" >nul\r\n" % [source.path_join("KARTON-EU-IV.pck"),dir.path_join("KARTON-EU-IV.pck")]
	lines += "start \"\" \"%s\"\r\n" % dir.path_join("KARTON-EU-IV.exe")
	var f = FileAccess.open(batch,FileAccess.WRITE)
	if f == null:
		return
	f.store_string(lines)
	f.close()
	OS.create_process("cmd.exe",PackedStringArray(["/c",batch]))

func _status(message: String) -> void:
	if game != null:
		game.notify(message,5.0)
		if game.hud != null and game.hud.update_label != null:
			game.hud.update_label.text = message
