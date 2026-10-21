extends CharacterBody3D
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
	var outfit = _mat(Color("28394b"))
	hoodie = _part(Vector3(0.0, 1.37, 0.0), Vector3(0.82, 0.98, 0.43), outfit)
	_part(Vector3(0, 2.08, 0), Vector3(0.42, 0.48, 0.43), _mat(Color("efc7a1")))
	_part(Vector3(0, 2.32, -0.015), Vector3(0.47, 0.18, 0.44), _mat(Color("231e26")))
	left_leg = _part(Vector3(-0.22, 0.49, 0), Vector3(0.29, 0.95, 0.32), _mat(Color("151922")))
	right_leg = _part(Vector3(0.22, 0.49, 0), Vector3(0.29, 0.95, 0.32), _mat(Color("151922")))
	_part(Vector3(-0.57, 1.38, 0), Vector3(0.29, 0.85, 0.29), outfit)
	_part(Vector3(0.57, 1.38, 0), Vector3(0.29, 0.85, 0.29), outfit)
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
