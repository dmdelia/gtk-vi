extends Node3D
## GTK: VI - Grand Theft Karton main coordinator.
const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const NPC = preload("res://scripts/npc.gd")
const Missions = preload("res://scripts/missions.gd")
const HUD = preload("res://scripts/hud.gd")
const Audio = preload("res://scripts/audio.gd")
const Updater = preload("res://scripts/updater.gd")

var world
var player
var missions
var hud
var updater
var audio: AudioStreamPlayer
var vehicles: Array = []
var npcs: Array = []
var current_vehicle
var camera: Camera3D
var camera_yaw = 0.0
var camera_pitch = -0.24
var mouse_sensitivity = 0.0025
var wanted = 0
var wanted_decay = 0.0
var mode = "menu"
var paused = false
var graphics_quality = "medium"
var time_of_day = 10.0
var clock_speed = 0.02
var sun: DirectionalLight3D
var env_node: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var inventory: Array[String] = []
var cheat_console: PanelContainer
var cheat_field: LineEdit
var game_world: Node3D
var sidequest_stage = -1
var sidequest_timer = 0.0
var sidequest_best = -1.0
var hit_delay = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random_seed()
	_migrate_legacy_user_data()
	load_options()
	_build_environment()
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 75.0
	camera.position = Vector3(5,16,36)
	add_child(camera)
	updater = Updater.new()
	updater.game = self
	updater.auto_update = bool(get_meta("preferred_updates",true))
	add_child(updater)
	hud = HUD.new()
	hud.game = self
	add_child(hud)
	audio = Audio.new()
	audio.game = self
	add_child(audio)
	_build_cheat_console()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# The updater is non-blocking; gameplay also works completely offline.
	if updater.auto_update:
		updater.check_now()

func _migrate_legacy_user_data() -> void:
	# Godot stores user:// under the project name. Preserve existing saves on rebrand.
	var new_dir = ProjectSettings.globalize_path("user://")
	var legacy_dir = new_dir.get_base_dir().path_join("KARTON EU IV")
	if not DirAccess.dir_exists_absolute(legacy_dir):
		return
	for name in ["options.json", "savegame.json"]:
		var old_path = legacy_dir.path_join(name)
		var new_path = new_dir.path_join(name)
		if FileAccess.file_exists(old_path) and not FileAccess.file_exists(new_path):
			DirAccess.copy_absolute(old_path, new_path)

func _random_seed() -> void:
	seed(791753)

func _build_environment() -> void:
	env_node = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_SKY
	var s = Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#283c59")
	sky_mat.sky_horizon_color = Color("#9ca8b3")
	sky_mat.ground_bottom_color = Color("#2d313a")
	sky_mat.ground_horizon_color = Color("#8c8890")
	s.sky_material = sky_mat
	e.sky = s
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = e
	add_child(env_node)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.light_color = Color("#ffe5b8")
	sun.rotation_degrees = Vector3(-48,25,0)
	sun.shadow_enabled = true
	add_child(sun)

func switch_quality() -> void:
	graphics_quality = "low" if graphics_quality == "high" else ("high" if graphics_quality == "medium" else "medium")
	_apply_quality()
	save_options()

func _apply_quality() -> void:
	sun.shadow_enabled = graphics_quality != "low"
	if graphics_quality == "low":
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	elif graphics_quality == "high":
		get_viewport().msaa_3d = Viewport.MSAA_4X
	else:
		get_viewport().msaa_3d = Viewport.MSAA_2X

func begin(which: String) -> void:
	if world != null:
		world.queue_free()
		world = null
		for v in vehicles:
			v.queue_free()
		for n in npcs:
			n.queue_free()
		if player != null:
			player.queue_free()
		if missions != null:
			missions.queue_free()
	vehicles.clear()
	npcs.clear()
	current_vehicle = null
	mode = which
	paused = false
	get_tree().paused = false
	wanted = 0
	inventory.clear()
	sidequest_stage = -1
	world = World.new()
	world.game = self
	add_child(world)
	world.setup_navigation()
	player = Player.new()
	player.game = self
	add_child(player)
	player.global_position = Vector3(106,1,92) if which == "story" else Vector3(84,1,88)
	for data in [
		["fork1","forklift",Vector3(-22,1,30),"#ecae35"],
		["fork2","forklift",Vector3(8,1,31),"#edb94d"],
		["truck1","truck",Vector3(109,1,89),"#ae4851"],
		["truck2","truck",Vector3(93,1,87),"#4c7c92"],
		["car1","car",Vector3(120,1,95),"#c45d65"],
		["car2","car",Vector3(111,1,95),"#557c9a"],
		["car3","car",Vector3(102,1,95),"#d3bb61"],
		["secret_car","car",Vector3(132,1,-95),"#d18ad9"],
		["car4","car",Vector3(82,1,88),"#7b858c"]]:
		spawn_vehicle(str(data[0]),str(data[1]),data[2],Color(str(data[3])))
	for data in [
		["boss","worker",Vector3(-109,1,-54)],
		["dispatcher","office",Vector3(82,1,18)],
		["mechanic","worker",Vector3(3,1,22)],
		["guard1","guard",Vector3(-44,1,-40)],
		["guard2","guard",Vector3(22,1,-44)],
		["guard3","guard",Vector3(96,1,15)],
		["guard4","guard",Vector3(102,1,82)]]:
		_spawn_npc(str(data[0]),str(data[1]),data[2])
	var rng = RandomNumberGenerator.new()
	rng.seed = 82361
	for i in 27:
		var site = [Vector3(-109,1,-54),Vector3(-44,1,-54),Vector3(28,1,-54),Vector3(-43,1,18),Vector3(34,1,25),Vector3(3,1,22),Vector3(82,1,18)][i%7]
		_spawn_npc("angestellter_%02d"%i,"office" if i%6==0 else "worker",site+Vector3(rng.randf_range(-12,12),0,rng.randf_range(-12,12)))
	missions = Missions.new()
	missions.game = self
	add_child(missions)
	if which == "story":
		missions.start(true)
	else:
		notify("FREE MODE\nDie Fabrik ist deine Spielwiese. Lass den Karton leben!",6)
	hud.set_menu(false)
	_apply_quality()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if which == "free":
		time_of_day = 13.0

func _spawn_npc(nid: String,job: String,at: Vector3) -> CharacterBody3D:
	var n = NPC.new()
	n.game = self
	n.setup(nid,job,at)
	add_child(n)
	npcs.append(n)
	return n

func spawn_vehicle(id: String,kind: String,at: Vector3,c: Color) -> CharacterBody3D:
	var v = Vehicle.new()
	v.game = self
	v.setup(id,kind,c)
	add_child(v)
	v.position = at
	vehicles.append(v)
	return v

func _process(delta: float) -> void:
	if mode == "menu" or player == null:
		if camera != null and mode == "menu":
			camera.rotation_degrees = Vector3(-17,0,0)
		return
	if paused:
		return
	time_of_day = fmod(time_of_day + delta*clock_speed,24.0)
	var elev = sin((time_of_day-6.0)/24.0*TAU)
	sun.rotation_degrees.x = -60*elev - 5
	sun.light_energy = clampf(elev*1.5+0.12,0.07,1.55)
	if int(time_of_day*2) != int((time_of_day-delta*clock_speed)*2):
		sky_mat.sky_top_color = Color("#142033").lerp(Color("#3f6684"),clampf(elev*0.85+0.2,0,1))
		sky_mat.sky_horizon_color = Color("#1d253d").lerp(Color("#e4b182"),clampf(elev*0.8+0.1,0,1))
	env_node.environment.ambient_light_energy = clampf(elev*0.6+0.24,0.15,0.95)
	hit_delay = maxf(0,hit_delay-delta)
	if wanted > 0:
		wanted_decay += delta
		if wanted_decay > 55:
			wanted -= 1
			wanted_decay = 0
	if player.in_car and current_vehicle != null:
		player.global_position = current_vehicle.global_position
	_camera_follow(delta)
	_sidequest_tick(delta)

func _camera_follow(delta: float) -> void:
	var following: Node3D = current_vehicle if current_vehicle != null else player
	var target: Vector3 = following.global_position + Vector3.UP * (2.7 if current_vehicle != null else 1.65)
	var dist = 10.0 if current_vehicle != null else 6.6
	var offset = Vector3(sin(camera_yaw)*cos(camera_pitch),-sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))*dist
	var desired = target + offset
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(target,desired,1)
	var hit = space.intersect_ray(q)
	if not hit.is_empty():
		desired = hit.position + (target-desired).normalized()*0.55
	camera.global_position = camera.global_position.lerp(desired,minf(1,delta*12))
	camera.look_at(target,Vector3.UP)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused:
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch = clampf(camera_pitch-event.relative.y*mouse_sensitivity,-1.12,0.55)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if cheat_console.visible:
				cheat_console.hide()
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			elif mode != "menu":
				toggle_pause()
		elif event.keycode == KEY_F1 or event.unicode == 126 or event.unicode == 96:
			if mode != "menu" and not paused:
				_toggle_cheats()

func _unhandled_input(event: InputEvent) -> void:
	if mode == "menu" or paused or cheat_console.visible or player == null:
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("vehicle_action"):
		vehicle_special()
	elif event.is_action_pressed("map"):
		hud.toggle_map()
	elif event.is_action_pressed("flashlight") and current_vehicle == null:
		player.toggle_flashlight()

func _nearest_npc(limit = 3.8):
	var answer
	for n in npcs:
		if is_instance_valid(n) and n.global_position.distance_to(player.global_position)<limit:
			limit = n.global_position.distance_to(player.global_position)
			answer = n
	return answer

func _nearest_vehicle(limit = 4.7):
	var result
	for v in vehicles:
		if is_instance_valid(v) and v.global_position.distance_to(player.global_position)<limit:
			limit = v.global_position.distance_to(player.global_position)
			result = v
	return result

func interact() -> void:
	if current_vehicle != null:
		exit_vehicle()
		return
	var npc = _nearest_npc()
	if npc != null:
		npc.conversation = 6.0
		notify(npc.talk(),6)
		missions.action(npc.npc_id)
		return
	var vehicle = _nearest_vehicle()
	if vehicle != null:
		enter_vehicle(vehicle)
		return
	var world_action = world.nearest_interactive(player.global_position,4.1)
	if not world_action.is_empty():
		activate_world(str(world_action.id))
		return
	if player.carried != null:
		player.drop_box()
		notify("Karton abgestellt.",2)
		return
	for b in world.pallets:
		if is_instance_valid(b) and b != world.special_pallet and b.global_position.distance_to(player.global_position) < 2.9:
			player.carry_box(b)
			notify("Karton aufgehoben. E zum Abstellen.",3)
			return

func activate_world(action: String) -> void:
	var accepted = missions.action(action)
	if accepted:
		return
	match action:
		"timeclock":
			notify("Eingestempelt! Die Zeiterfassung zählt jede Sekunde. Außer die Überstunden.",4)
		"line_a","line_b","line_c":
			notify("Hier darf nur die Schichtleitung den Not-Aus drücken.",3)
		"vending":
			if player.money >= 3:
				player.money -= 3
				player.health = minf(100,player.health+18)
				notify("Monster Karton Energy: +18 Gesundheit / -3 €",3)
			else:
				notify("Kleingeld vergessen.",2)
		"repair":
			var car = _nearest_vehicle(13.0)
			if car != null and player.money >= 45:
				car.damage = maxf(0,car.damage-70)
				player.money -= 45
				notify("Fahrzeug repariert (-45 €).",3)
			elif car == null:
				notify("Toni: Stell ein Fahrzeug vor die Werkstatt.",3)
			else:
				notify("Zu wenig Geld für die Reparatur.",3)
		"challenge":
			sidequest_stage = 0
			sidequest_timer = 90
			notify("STAPLER-SLALOM! 90 Sekunden. Fahre durch drei Kontrollpunkte!",5)
		"secret":
			if not inventory.has("Der verbotene Goldkarton"):
				player.money += 404
				inventory.append("Der verbotene Goldkarton")
				notify("EASTER EGG: Goldkarton 404 gefunden! +404 €",5)
			else:
				notify("Hier liegt nur noch die Erinnerung an den Goldkarton.",3)
		"ending_a","ending_b":
			notify("Dieser Ausgang ist Teil des großen Finales.",3)
		_:
			notify("Bedienfeld: "+action.to_upper()+" | Status: normal",2)

func enter_vehicle(v) -> void:
	if player.carried != null:
		player.drop_box()
	current_vehicle = v
	v.driver = true
	player.in_car = true
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0
	camera_yaw = v.rotation.y
	notify("%s gestartet. WASD fahren, LEERTASTE bremsen, E aussteigen%s" % [v.kind.to_upper(),", R Gabel benutzen" if v.kind == "forklift" else ""],5)

func exit_vehicle() -> void:
	if current_vehicle == null:
		return
	var v = current_vehicle
	var emerge = v.global_position + v.global_transform.basis.x * (3.1 if v.kind == "truck" else 2.4) + Vector3.UP
	var q = PhysicsPointQueryParameters3D.new()
	q.position = emerge+Vector3.UP
	q.collision_mask = 1
	if not get_world_3d().direct_space_state.intersect_point(q).is_empty():
		emerge = v.global_position-v.global_transform.basis.x*3.0+Vector3.UP
	player.global_position = emerge
	player.in_car = false
	player.visible = true
	player.collision_layer = 2
	player.collision_mask = 1|4|8
	v.driver = false
	current_vehicle = null
	notify("Ausgestiegen",1.5)

func vehicle_special() -> void:
	if current_vehicle == null:
		if player.carried != null:
			player.drop_box()
		return
	var v = current_vehicle
	if v.cargo != null:
		var was_special = v.cargo == world.special_pallet
		v.release_cargo()
		if was_special:
			missions.action("pallet_dropped")
		notify("Palette abgeladen.",2)
		return
	if v.kind not in ["forklift","truck"]:
		return
	for crate in world.pallets:
		if is_instance_valid(crate) and crate.global_position.distance_to(v.global_position) < (8.0 if v.kind == "forklift" else 5.0):
			v.attach_cargo(crate)
			if crate == world.special_pallet:
				missions.action("pallet_picked")
			notify("Fracht aufgenommen. R zum Abstellen.",3)
			return
		notify("Keine Palette in Reichweite.",2)

func vehicle_collision(car, target: Object, impact: float) -> void:
	if hit_delay > 0:
		return
	hit_delay = 1.25
	if target in npcs:
		target.panic()
		raise_wanted(1)
		notify("WERKSCHUTZ: Gefährliches Fahren gemeldet!",3)
	elif impact > 2:
		if car.damage > 65:
			raise_wanted(1)
		if not player.godmode:
			player.hurt(impact*0.2)

func raise_wanted(level = 1) -> void:
	wanted = mini(5,wanted+level)
	wanted_decay = 0
	for npc in npcs:
		if npc.role != "guard" and npc.global_position.distance_to(player.global_position) < 30:
			npc.panic()

func respawn() -> void:
	if current_vehicle != null:
		exit_vehicle()
	player.health = 100
	player.global_position = Vector3(106,2,92)
	player.money = maxi(0,player.money-75)
	wanted = 0
	notify("WIEDERBELEBT: 75 € Werksarztgebühr. Schnäppchen.",5)

func _sidequest_tick(delta: float) -> void:
	if sidequest_stage < 0:
		return
	sidequest_timer -= delta
	if sidequest_timer <= 0:
		sidequest_stage = -1
		notify("STAPLER-SLALOM GESCHEITERT. Zu langsam!",5)
		return
	if current_vehicle == null or current_vehicle.kind != "forklift":
		return
	var gates = [Vector3(86,0,86),Vector3(106,0,88),Vector3(126,0,90)]
	if current_vehicle.global_position.distance_to(gates[sidequest_stage]) < 12:
		sidequest_stage += 1
		if sidequest_stage >= gates.size():
			var elapsed = 90-sidequest_timer
			player.money += 400
			if sidequest_best < 0 or elapsed < sidequest_best:
				sidequest_best = elapsed
			notify("STAPLER-SLALOM GESCHAFFT: %.1f s! +400 €" % elapsed,6)
			sidequest_stage = -1
		else:
			notify("CHECKPOINT %d/3!" % sidequest_stage,2)

func get_nearby_hint() -> String:
	if current_vehicle != null:
		return "[WASD] Fahren    [LEERTASTE] Bremse    [E] Aussteigen    [R] Fracht" if current_vehicle.kind == "forklift" else "[WASD] Fahren    [LEERTASTE] Bremse    [E] Aussteigen"
	var person = _nearest_npc(4)
	if person != null:
		return "[E] Reden: %s" % person.npc_id.capitalize()
	var v = _nearest_vehicle(4.7)
	if v != null:
		return "[E] In %s einsteigen" % v.kind.to_upper()
	var action = world.nearest_interactive(player.global_position,4.1)
	if not action.is_empty():
		return "[E] %s" % action.name
	if player.carried != null:
		return "[E] Karton abstellen"
	for p in world.pallets:
		if p != world.special_pallet and p.global_position.distance_to(player.global_position) < 3:
			return "[E] Karton tragen"
	return "[WASD] Gehen  [SHIFT] Sprinten  [F] Licht  [M] Karte  [F1] Cheats"

func toggle_pause() -> void:
	if mode == "menu":
		return
	paused = not paused
	get_tree().paused = paused
	hud.show_pause(paused)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)

func exit_to_menu() -> void:
	if mode != "menu":
		save_game()
	if current_vehicle != null:
		current_vehicle.driver = false
	get_tree().paused = false
	paused = false
	mode = "menu"
	if world != null:
		world.queue_free()
		world = null
	if player != null:
		player.queue_free()
		player = null
	for v in vehicles:
		v.queue_free()
	for n in npcs:
		n.queue_free()
	vehicles.clear()
	npcs.clear()
	if missions != null:
		missions.queue_free()
		missions = null
	current_vehicle = null
	hud.set_menu(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _build_cheat_console() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	cheat_console = PanelContainer.new()
	cheat_console.anchor_left = 0.29
	cheat_console.anchor_right = 0.71
	cheat_console.anchor_top = 0.67
	cheat_console.anchor_bottom = 0.75
	var skin = StyleBoxFlat.new()
	skin.bg_color = Color("#102127f5")
	skin.border_color = Color("#dbb476")
	skin.set_border_width_all(2)
	skin.set_content_margin_all(12)
	cheat_console.add_theme_stylebox_override("panel",skin)
	layer.add_child(cheat_console)
	cheat_field = LineEdit.new()
	cheat_field.placeholder_text = "CHEAT CODE ..."
	cheat_field.add_theme_font_size_override("font_size",24)
	cheat_console.add_child(cheat_field)
	cheat_field.text_submitted.connect(func(text: String): _execute_cheat(text))
	cheat_console.hide()

func _toggle_cheats() -> void:
	cheat_console.visible = not cheat_console.visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if cheat_console.visible else Input.MOUSE_MODE_CAPTURED)
	if cheat_console.visible:
		cheat_field.clear()
		cheat_field.grab_focus()

func _execute_cheat(code: String) -> void:
	var word = code.strip_edges().to_upper()
	cheat_console.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	match word:
		"GODMODE":
			player.godmode = not player.godmode
			notify("GODMODE " + ("AN" if player.godmode else "AUS"),3)
		"RICHKARTON":
			player.money += 1000000
			notify("+1.000.000 € KARTON-DOLLARS!",3)
		"FORKLIFT":
			var p = player.global_position - Vector3(sin(camera_yaw),0,cos(camera_yaw))*7
			spawn_vehicle("cheat_fork%d"%vehicles.size(),"forklift",p,Color("#edb941"))
			notify("Stapler aufgetaucht!",3)
		"SUPERSPEED":
			player.speed_boost = not player.speed_boost
			notify("SUPERSPEED %s"%("AN" if player.speed_boost else "AUS"),3)
		"LOWGRAVITY":
			player.low_gravity = not player.low_gravity
			notify("LOWGRAVITY %s"%("AN" if player.low_gravity else "AUS"),3)
		"NIGHTSHIFT":
			time_of_day = 1.0
			notify("NACHTSCHICHT!",3)
		"DAYSHIFT":
			time_of_day = 12.0
			notify("TAG-SCHICHT!",3)
		"CHAOS":
			for n in npcs:
				n.panic()
			raise_wanted(2)
			notify("CHAOS! Die Belegschaft ist komplett durch!",5)
		"CLEARWANTED":
			wanted = 0
			wanted_decay = 0
			notify("Werkschutzfahndung gelöscht.",3)
		"FLYKARTON":
			player.fly = not player.fly
			notify("FLYKARTON %s: SPRINGEN steigt, STRG sinkt" % ("AN" if player.fly else "AUS"),4)
		"HEALKARTON":
			player.health = 100
			notify("100% Karton-Gesundheit!",3)
		_:
			notify("UNBEKANNTER CHEAT: "+word,3)

func notify(message: String, duration = 4.0) -> void:
	if hud != null:
		hud.notify(message,duration)

func save_game() -> void:
	if mode == "menu" or player == null:
		return
	var state = {
		"version":1,"mode":mode,"player_position":[player.global_position.x,player.global_position.y,player.global_position.z],
		"money":player.money,"health":player.health,"wanted":wanted,"time":time_of_day,
		"mission_index":missions.index,"mission_stage":missions.stage,"mission_active":missions.active,
		"mission_completed":missions.completed,"mission_timer":missions.timer,"machine_running":world.machine_running,
		"inventory":inventory,"sidequest_best":sidequest_best,"vehicle":[],
		"special_pallet_position":[world.special_pallet.global_position.x,world.special_pallet.global_position.y,world.special_pallet.global_position.z],
		"special_pallet_vehicle":"","cheats":{
			"godmode":player.godmode,"superspeed":player.speed_boost,"lowgravity":player.low_gravity,"fly":player.fly
		}
	}
	if current_vehicle != null:
		state.vehicle = [current_vehicle.vehicle_id,current_vehicle.global_position.x,current_vehicle.global_position.y,current_vehicle.global_position.z,current_vehicle.heading]
	for v in vehicles:
		if v.cargo == world.special_pallet:
			state.special_pallet_vehicle = v.vehicle_id
			break
	var file = FileAccess.open("user://savegame.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state,"\t"))
		file.close()
		notify("Spielstand gespeichert.",3)

func load_game() -> void:
	if not FileAccess.file_exists("user://savegame.json"):
		notify("Noch kein Spielstand vorhanden.",3)
		return
	var file = FileAccess.open("user://savegame.json",FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		notify("Speicherdatei beschädigt.",4)
		return
	begin(str(data.get("mode","story")))
	var coord: Array = data.get("player_position",[-93,2,95])
	if coord.size() == 3:
		player.global_position = Vector3(float(coord[0]),maxf(1,float(coord[1])),float(coord[2]))
	player.money = int(data.get("money",120))
	player.health = float(data.get("health",100))
	wanted = int(data.get("wanted",0))
	time_of_day = float(data.get("time",10))
	world.machine_running = bool(data.get("machine_running",true))
	inventory.clear()
	for item in data.get("inventory",[]):
		inventory.append(str(item))
	sidequest_best = float(data.get("sidequest_best",-1))
	missions.index = clampi(int(data.get("mission_index",0)),0,6)
	missions.stage = clampi(int(data.get("mission_stage",0)),0,missions.stage_count()-1)
	missions.active = bool(data.get("mission_active",false))
	missions.completed = bool(data.get("mission_completed",false))
	missions.timer = float(data.get("mission_timer",-1))
	var special_pos: Array = data.get("special_pallet_position",[77,1.05,-47])
	if special_pos.size() == 3:
		world.special_pallet.global_position = Vector3(float(special_pos[0]),float(special_pos[1]),float(special_pos[2]))
	var owner_id = str(data.get("special_pallet_vehicle",""))
	for v in vehicles:
		if v.vehicle_id == owner_id:
			v.attach_cargo(world.special_pallet)
			break
	var opts: Dictionary = data.get("cheats",{})
	player.godmode = bool(opts.get("godmode",false))
	player.speed_boost = bool(opts.get("superspeed",false))
	player.low_gravity = bool(opts.get("lowgravity",false))
	player.fly = bool(opts.get("fly",false))
	var saved_car: Array = data.get("vehicle",[])
	if saved_car.size() == 5:
		for v in vehicles:
			if v.vehicle_id == str(saved_car[0]):
				v.global_position = Vector3(float(saved_car[1]),float(saved_car[2]),float(saved_car[3]))
				v.heading = float(saved_car[4])
				enter_vehicle(v)
				break
	notify("Spielstand geladen. Willkommen zurück im Karton!",6)

func save_options() -> void:
	var file = FileAccess.open("user://options.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"quality":graphics_quality,"sensitivity":mouse_sensitivity,"auto_updates":updater.auto_update if updater != null else true}))
		file.close()

func load_options() -> void:
	if not FileAccess.file_exists("user://options.json"):
		return
	var f = FileAccess.open("user://options.json",FileAccess.READ)
	if f == null:
		return
	var opts = JSON.parse_string(f.get_as_text())
	f.close()
	if opts is Dictionary:
		graphics_quality = str(opts.get("quality","medium"))
		mouse_sensitivity = float(opts.get("sensitivity",0.0025))
		# The updater reads the setting once it exists (created after this call).
		set_meta("preferred_updates",bool(opts.get("auto_updates",true)))

func quit_game() -> void:
	if updater != null:
		updater.install_on_exit()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if updater != null:
			updater.install_on_exit()
		get_tree().quit()
