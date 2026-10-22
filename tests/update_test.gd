extends SceneTree
const Version = preload("res://scripts/version_info.gd")
const Updater = preload("res://scripts/updater.gd")

func _initialize() -> void:
	if Version.display() != "0.1.3-prealpha @ 1.103":
		_fail("incorrect version label")
		return
	if not Version.is_newer("v0.1.3-prealpha", "0.1.2"):
		_fail("prerelease comparison broken")
		return
	if Version.is_newer("v0.1.2-prealpha", "0.1.3"):
		_fail("downgrade accepted")
		return
	var updater = Updater.new()
	var releases = [
		{"tag_name":"v0.1.0", "draft":false, "assets":[{"name":"GTK-VI-windows.zip"}]},
		{"tag_name":"v0.1.4-prealpha", "draft":true, "assets":[{"name":"GTK-VI-windows.zip"}]},
		{"tag_name":"v0.1.5-prealpha", "draft":false, "assets":[{"name":"irrelevant.zip"}]},
		{"tag_name":"v0.1.3-prealpha", "draft":false, "assets":[{"name":"GTK-VI-windows.zip"}]},
		{"tag_name":"v0.1.4-prealpha", "draft":false, "assets":[{"name":"GTK-VI-windows.zip"}]}
	]
	var newest = updater._find_newest(releases)
	if str(newest.get("tag_name", "")) != "v0.1.4-prealpha":
		_fail("prerelease discovery broken")
		return
	print("UPDATER SMOKE TEST PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
