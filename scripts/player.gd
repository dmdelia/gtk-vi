extends CharacterBody3D
const V = preload("res://scripts/visuals.gd")
## Third-person avatar. All geometry is generated at runtime.

var game
var speed_boost = false
var low_gravity = false
var godmode = false
var fly = false
var health = 100.0
var money = 120
var in_car = false
var carried: RigidBody3D
var step_clock = 0.0
var hoodie: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var light: SpotLight3D
var sneak = false

func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.43
	capsule.height = 2.3
	shape.shape = capsule
	shape.position.y = 1.15
	add_child(shape)
	var outfit = V.material("fabric", Color("#354c69"))
	var denim = V.material("fabric", Color("#343e4b"))
	var skin = V.plain(Color("#d4ad8b"),0,.8)
	var shoes = V.material("rubber",Color("#272a31"))
	# Rounded cloth silhouette with 3D sleeves, seam piping and articulated legs.
	hoodie = V.capsule(self,Vector3(0,1.43,0),.39,.94,outfit,18)
	V.sphere(self,Vector3(0,2.08,0),Vector3(.46,.53,.41),skin,20)
	V.sphere(self,Vector3(0,2.36,.02),Vector3(.5,.22,.46),V.material("fabric",Color("#302c38")),20)
	V.cuboid(self,Vector3(0,1.11,-.30),Vector3(.6,.055,.025),V.material("steel",Color("#606e7b")))
	V.capsule(self,Vector3(-.58,1.4,-.01),.15,.88,outfit)
	V.capsule(self,Vector3(.58,1.4,-.01),.15,.88,outfit)
	V.sphere(self,Vector3(-.57,.98,-.04),Vector3(.29,.27,.25),skin)
	V.sphere(self,Vector3(.57,.98,-.04),Vector3(.29,.27,.25),skin)
	left_leg=V.capsule(self,Vector3(-.20,.56,0),.17,.95,denim)
	right_leg=V.capsule(self,Vector3(.20,.56,0),.17,.95,denim)
	V.sphere(self,Vector3(-.20,.12,-.12),Vector3(.36,.21,.57),shoes)
	V.sphere(self,Vector3(.20,.12,-.12),Vector3(.36,.21,.57),shoes)
	# Face detail rather than an untextured block.
	for side in [-1,1]:
		V.sphere(self,Vector3(float(side)*.13,2.12,-.20),Vector3(.065,.055,.035),V.plain(Color("#252323")))
	V.sphere(self,Vector3(0,2.01,-.224),Vector3(.065,.09,.11),skin)
	V.cuboid(self,Vector3(0,1.9,-.207),Vector3(.17,.025,.021),V.plain(Color("#83544d")))
	light = SpotLight3D.new()
	light.position = Vector3(0, 2.08, -0.2)
	light.rotation_degrees.x = -18
	light.spot_range = 28
	light.light_energy = 3
	light.visible = false
	add_child(light)

func _mat(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m

func _part(pos: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var part = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = dimensions
	part.mesh = cube
	part.material_override = material
	part.position = pos
	add_child(part)
	return part

func _physics_process(delta: float) -> void:
	if in_car:
		return
	var controls = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = Vector3.ZERO
	if controls.length() > 0.05:
		var forward = Vector3(-sin(game.camera_yaw), 0, -cos(game.camera_yaw))
		var right = Vector3(cos(game.camera_yaw), 0, -sin(game.camera_yaw))
		direction = (right * controls.x - forward * controls.y).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 13.0))
	sneak = Input.is_action_pressed("sneak")
	var top_speed = 4.6 if sneak else (12.5 if Input.is_action_pressed("sprint") else 7.5)
	if speed_boost:
		top_speed *= 2.3
	if fly:
		var vertical = float(Input.is_action_pressed("jump")) - float(Input.is_action_pressed("sneak"))
		velocity = direction * top_speed * 1.7 + Vector3.UP * vertical * top_speed
	else:
		velocity.x = move_toward(velocity.x, direction.x * top_speed, delta * 32)
		velocity.z = move_toward(velocity.z, direction.z * top_speed, delta * 32)
		if not is_on_floor():
			velocity.y -= (5.0 if low_gravity else 20.0) * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = 8.4 if not low_gravity else 11.0
	move_and_slide()
	if position.y < -12:
		game.respawn()
	step_clock += direction.length() * delta * top_speed
	left_leg.rotation.x = sin(step_clock * 2.9) * 0.42 if direction.length() > 0.1 else 0.0
	right_leg.rotation.x = -left_leg.rotation.x
	if carried != null and is_instance_valid(carried):
		carried.global_position = global_position + Vector3.UP * 1.5 - global_transform.basis.z * 1.15
		carried.linear_velocity = Vector3.ZERO

func hurt(amount: float) -> void:
	if godmode:
		return
	health = maxf(0, health - amount)
	if health <= 0:
		game.respawn()

func toggle_flashlight() -> void:
	light.visible = not light.visible

func carry_box(body: RigidBody3D) -> void:
	if carried == body:
		drop_box()
		return
	if carried != null:
		drop_box()
	carried = body
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0

func drop_box() -> void:
	if carried == null or not is_instance_valid(carried):
		carried = null
		return
	var box = carried
	carried = null
	box.global_position = global_position + Vector3.UP * 2 - global_transform.basis.z * 1.8
	box.freeze = false
	box.collision_layer = 8
	box.collision_mask = 1 | 2 | 4 | 8
	box.apply_central_impulse(-global_transform.basis.z * 3.0)
