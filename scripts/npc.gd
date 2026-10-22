extends CharacterBody3D
const Humanoid = preload("res://scripts/humanoid.gd")
## Local workers, receptionists and security patrol using the shared AStar graph.

var game
var npc_id = ""
var role = "worker"
var home = Vector3.ZERO
var destination = Vector3.ZERO
var route = PackedVector3Array()
var waypoint = 0
var goal_timer = 0.0
var panic_timer = 0.0
var leg_clock = 0.0
var conversation = 0.0
var human: Node3D
var service_badge = false

func setup(id: String, job: String, p: Vector3) -> void:
	npc_id = id
	role = job
	home = p
	position = p

func _ready() -> void:
	name = npc_id
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	var shape = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.height = 2.1
	cap.radius = 0.4
	shape.position.y = 1.05
	shape.shape = cap
	add_child(shape)
	human = Humanoid.new()
	human.name = "AnatomicalHuman"
	var avatar_seed = 0
	for i in npc_id.length():
		avatar_seed += npc_id.unicode_at(i) * (i + 1)
	human.configure(role, avatar_seed)
	add_child(human)
	goal_timer = randf_range(1,4)

func talk() -> String:
	conversation = 7.0
	if role == "guard":
		return "Werkschutz: Keine Rennen, keine Explosionen und VOR ALLEM keine unbezahlten Überstunden."
	if npc_id == "boss":
		return "Vorarbeiter Rüdiger: Willkommen bei Karton EU! Hier arbeitet sogar die Kaffeemaschine im Schichtsystem."
	if npc_id == "dispatcher":
		return "Disposition: Eine ganze Palette fehlt. Im System steht nur: 'Ist schon irgendwie weg'."
	if npc_id == "mechanic":
		return "Mechanikerin Toni: Nimm meinen Schlüssel. Und sag niemandem, dass die Werkstatt nach Pizza riecht."
	if role == "office":
		return ["Ich habe das Excel geschlossen. Damit ist das Problem jetzt weg.","Meeting in fünf Minuten! Wie jeden Tag seit 1998.","Das ist keine Krise, das ist Prozessoptimierung."][randi()%3]
	return ["Der Karton hat heute mehr Urlaubstage als ich.","Wenn du den Chef siehst: Ich war die ganze Zeit am Band.","Das Paket war eben noch da...", "Diese Schicht dauert gefühlt bis GTA VII."][randi()%4]

func panic() -> void:
	panic_timer = 12
	goal_timer = 0

func set_goal(to: Vector3) -> void:
	destination = to
	route = game.world.path(global_position,to)
	waypoint = 0
	goal_timer = randf_range(12,23)

func _physics_process(delta: float) -> void:
	if game == null or game.world == null:
		return
	panic_timer = maxf(0,panic_timer-delta)
	conversation = maxf(0,conversation-delta)
	goal_timer -= delta
	if role == "guard" and game.wanted > 0:
		if global_position.distance_to(game.player.global_position) < 72:
			if goal_timer <= 0.1:
				set_goal(game.player.global_position)
				goal_timer = 0.8
			if global_position.distance_to(game.player.global_position) < 2.4 and not game.player.in_car:
				game.player.hurt(7.0*delta)
				if game.missions.active and game.missions.index == 3:
					game.missions.fail("Vom Werkschutz erwischt!")
	elif role == "guard" and game.missions != null and game.missions.active and game.missions.index == 3:
		if global_position.distance_to(game.player.global_position) < 7 and game.missions.stage <= 1:
			var eye = global_position + Vector3.UP * 1.8
			var target_eye = game.player.global_position + Vector3.UP * 1.6
			var ray = PhysicsRayQueryParameters3D.create(eye,target_eye,1)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				game.missions.fail("Sichtkontakt! Die Halle war gesperrt.")
	if goal_timer <= 0:
		var c = game.time_of_day
		if panic_timer > 0:
			set_goal(global_position + Vector3(randf_range(-38,38),0,randf_range(-36,36)))
		elif c > 12.5 and c < 13.2 and role != "guard":
			set_goal(Vector3(randf_range(-51,-25),0,randf_range(35,55)))
		elif role == "guard":
			set_goal(home + Vector3(randf_range(-24,24),0,randf_range(-12,12)))
		else:
			set_goal(home + Vector3(randf_range(-8,8),0,randf_range(-9,9)))
	var direction = Vector3.ZERO
	if conversation <= 0 and waypoint < route.size():
		var next = route[waypoint]
		var planar = Vector3(next.x-global_position.x,0,next.z-global_position.z)
		if planar.length() < 1.8:
			waypoint += 1
		else:
			direction = planar.normalized()
	if direction.length() > 0.01:
		rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta*6)
	var motion = (6.7 if panic_timer > 0 else (5.5 if role == "guard" and game.wanted > 0 else 2.4))
	velocity.x = move_toward(velocity.x,direction.x*motion,delta*11)
	velocity.z = move_toward(velocity.z,direction.z*motion,delta*11)
	if not is_on_floor():
		velocity.y -= 20*delta
	else:
		velocity.y = -0.05
	move_and_slide()
	if human != null:
		human.set_pose(Vector2(velocity.x,velocity.z).length(),direction.length()>0.05,panic_timer>0,false,false,delta)
