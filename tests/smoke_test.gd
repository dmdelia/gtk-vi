extends SceneTree
## Non-interactive smoke test for GitHub Actions (Godot 4.4.1).

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, description: String) -> bool:
	if not ok:
		push_error("SMOKE TEST FAIL: " + description)
		quit(1)
		return false
	print("PASS: " + description)
	return true

func run_test() -> void:
	var scene = load("res://main.tscn")
	if not check(scene != null, "main scene loads"):
		return
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	if not check(main.hud != null and main.mode == "menu", "main menu initialized"):
		return
	main.begin("story")
	await process_frame
	await physics_frame
	if not check(main.player != null and main.world != null and main.missions.active, "story with interactive 3D world"):
		return
	if not check(main.vehicles.size() >= 8 and main.npcs.size() >= 30, "vehicles and factory NPCs spawned"):
		return
	if not check(main.world.special_pallet != null and main.world.objects.size() >= 10, "cargo and interactables spawned"):
		return
	main._execute_cheat("GODMODE")
	if not check(main.player.godmode, "Godmode cheat applies"):
		return
	main._execute_cheat("RICHKARTON")
	if not check(main.player.money >= 1000000, "money cheat applies"):
		return
	main.save_game()
	if not check(FileAccess.file_exists("user://savegame.json"), "savegame written"):
		return
	main.exit_to_menu()
	await process_frame
	main.load_game()
	await process_frame
	if not check(main.mode == "story" and main.player.money >= 1000000, "savegame loads and restores progress"):
		return
	main.exit_to_menu()
	await process_frame
	main.begin("free")
	await process_frame
	if not check(main.mode == "free" and main.world != null, "Free Mode initialized"):
		return
	print("SMOKE TEST PASS: KARTON EU IV")
	quit(0)
