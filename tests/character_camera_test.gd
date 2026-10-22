extends SceneTree
## Automated visual-rig and camera-interpolation regression smoke test.
const Humanoid = preload("res://scripts/humanoid.gd")

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, label: String) -> bool:
	if not condition:
		push_error("CHARACTER/CAMERA TEST FAILED: " + label)
		return false
	print("PASS: " + label)
	return true

func _run() -> void:
	var ok = true
	var rig = Humanoid.new()
	rig.configure("worker", 42)
	root.add_child(rig)
	await process_frame
	var mesh_count = 0
	var loft_count = 0
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		mesh_count += 1
		if node.mesh is ArrayMesh:
			loft_count += 1
	ok = _assert(mesh_count >= 20,"humanoid contains detailed textured geometry") and ok
	ok = _assert(loft_count >= 12,"anatomical loft surfaces replace block/sphere body") and ok
	ok = _assert(rig.hip_l != null and rig.knee_l != null and rig.shoulder_l != null and rig.elbow_l != null,"articulated major joints exist") and ok
	rig.set_pose(8.0,true,false,false,false,0.13)
	ok = _assert(absf(rig.hip_l.rotation.x) > 0.02,"thigh swings during movement") and ok
	ok = _assert(rig.torso_root != null and rig.head_pivot != null,"torso and head have distinct geometry") and ok
	ok = _assert(bool(ProjectSettings.get_setting("physics/common/physics_interpolation",false)),"physics interpolation enabled") and ok
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	ok = _assert(game.camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,"camera avoids double interpolation") and ok
	game.begin("free")
	await physics_frame
	await process_frame
	ok = _assert(game.player.human != null and game.player.human.hip_r != null,"player rig is integrated") and ok
	ok = _assert(game.npcs.size() >= 20 and game.npcs[0].human != null,"NPCs use new rig") and ok
	ok = _assert(not game.camera_snap_next_frame,"camera follow has initialized") and ok
	game.queue_free()
	rig.queue_free()
	print("CHARACTER CAMERA TEST PASS" if ok else "CHARACTER CAMERA TEST FAIL")
	quit(0 if ok else 1)
