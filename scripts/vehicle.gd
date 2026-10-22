extends CharacterBody3D
## Arcade vehicle with improved silhouettes, wheel geometry and material variety.

var game
var kind = "car"
var vehicle_id = ""
var tint = Color("bc3030")
var speed = 0.0
var heading = 0.0
var driver = false
var damage = 0.0
var max_speed = 25.0
var steering = 1.5
var cargo: Node3D
var wheel_nodes: Array[MeshInstance3D] = []

func setup(id: String, type_name: String, color: Color) -> void:
	vehicle_id = id
	kind = type_name
	tint = color

func _ready() -> void:
	name = vehicle_id
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	var size = Vector3(2.2, 1.75, 4.3)
	if kind == "forklift":
		size = Vector3(1.8, 2.0, 2.8)
		max_speed = 11.0
		steering = 2.1
	elif kind == "truck":
		size = Vector3(3.1, 3.1, 7.8)
		max_speed = 17.0
		steering = 0.93
	var body = CollisionShape3D.new()
	var body_shape = BoxShape3D.new()
	body_shape.size = size
	body.shape = body_shape
	body.position.y = size.y * 0.5 + 0.25
	add_child(body)
	_build_visuals(size)
	heading = rotation.y

func _build_visuals(size: Vector3) -> void:
	var body_mat = _mat(tint, 0.24, 0.52)
	var glass = _mat(Color("93bdd8"), 0.0, 0.08, true)
	var dark = _mat(Color("1b232c"), 0.18, 0.48)
	var steel = _mat(Color("bac2c4"), 0.52, 0.34)
	if kind == "car":
		_add_box(Vector3(0, size.y * 0.42 + 0.25, 0.08), Vector3(size.x * 0.96, size.y * 0.62, size.z * 0.92), body_mat)
		_add_box(Vector3(0, 1.42, 0.1), Vector3(1.78, 0.72, 1.95), body_mat)
		_add_box(Vector3(0, 1.55, -0.3), Vector3(1.68, 0.46, 1.25), glass)
		_add_box(Vector3(0, 1.52, 0.9), Vector3(1.68, 0.42, 0.85), glass)
		_add_box(Vector3(0, 0.86, -1.78), Vector3(1.84, 0.26, 0.6), dark)
		_add_box(Vector3(0, 0.92, 1.82), Vector3(1.7, 0.32, 0.42), dark)
	elif kind == "forklift":
		_add_box(Vector3(0, 1.15, 0.2), Vector3(1.55, 1.35, 2.1), body_mat)
		_add_box(Vector3(0, 2.05, 0.45), Vector3(1.56, 0.12, 1.5), dark)
		_add_box(Vector3(0, 1.55, 0.58), Vector3(1.15, 0.7, 0.12), glass)
		for x in [-0.72, 0.72]:
			_add_box(Vector3(x, 1.35, 1.18), Vector3(0.12, 2.45, 0.12), steel)
			_add_box(Vector3(x, 1.35, -0.85), Vector3(0.12, 2.1, 0.12), steel)
			_add_box(Vector3(x, 2.1, 0.2), Vector3(0.12, 0.12, 2.1), steel)
		for x in [-0.25, 0.25]:
			_add_box(Vector3(x, 0.32, -1.82), Vector3(0.14, 0.12, 1.68), steel)
		_add_box(Vector3(0, 1.2, -1.25), Vector3(1.1, 0.18, 0.18), steel)
	else:
		_add_box(Vector3(0, 1.7, -1.35), Vector3(2.95, 2.35, 4.65), _mat(Color("d9d9d4"), 0.18, 0.62))
		_add_box(Vector3(0, 2.05, 2.05), Vector3(2.4, 1.45, 2.25), body_mat)
		_add_box(Vector3(0, 2.32, 2.25), Vector3(2.1, 0.8, 1.3), glass)
		_add_box(Vector3(0, 0.98, -3.7), Vector3(2.58, 0.28, 0.25), dark)
		_add_box(Vector3(0, 0.98, 3.68), Vector3(2.15, 0.28, 0.25), dark)
	_add_lights(size)
	_add_wheels(size)

func _add_lights(size: Vector3) -> void:
	var front_z = -size.z * 0.5
	var rear_z = size.z * 0.5
	_add_box(Vector3(-size.x * 0.27, 0.8, front_z), Vector3(0.35, 0.2, 0.05), _mat(Color("f5e5a1"), 0.0, 0.2))
	_add_box(Vector3(size.x * 0.27, 0.8, front_z), Vector3(0.35, 0.2, 0.05), _mat(Color("f5e5a1"), 0.0, 0.2))
	_add_box(Vector3(-size.x * 0.25, 0.8, rear_z), Vector3(0.28, 0.18, 0.05), _mat(Color("d44848"), 0.0, 0.28))
	_add_box(Vector3(size.x * 0.25, 0.8, rear_z), Vector3(0.28, 0.18, 0.05), _mat(Color("d44848"), 0.0, 0.28))

func _add_wheels(size: Vector3) -> void:
	var wheel_radius = 0.43 if kind == "car" else (0.5 if kind == "forklift" else 0.62)
	var wheel_width = 0.22 if kind == "car" else (0.3 if kind == "forklift" else 0.36)
	for x in [-size.x * 0.47, size.x * 0.47]:
		for z in [-size.z * 0.33, size.z * 0.33]:
			var wheel = MeshInstance3D.new()
			var mesh = CylinderMesh.new()
			mesh.top_radius = wheel_radius
			mesh.bottom_radius = wheel_radius
			mesh.height = wheel_width
			mesh.radial_segments = 18
			wheel.mesh = mesh
			wheel.material_override = _mat(Color("111419"), 0.08, 0.92)
			wheel.position = Vector3(x, wheel_radius + 0.06, z)
			wheel.rotation.z = PI * 0.5
			add_child(wheel)
			wheel_nodes.append(wheel)
			var hub = MeshInstance3D.new()
			var hub_mesh = CylinderMesh.new()
			hub_mesh.top_radius = wheel_radius * 0.45
			hub_mesh.bottom_radius = wheel_radius * 0.45
			hub_mesh.height = wheel_width + 0.02
			hub_mesh.radial_segments = 16
			hub.mesh = hub_mesh
			hub.material_override = _mat(Color("bfc4c7"), 0.74, 0.24)
			hub.position = wheel.position
			hub.rotation.z = PI * 0.5
			add_child(hub)

func _mat(c: Color, metallic = 0.3, roughness = 0.55, transparent = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _add_box(p: Vector3, s: Vector3, mat: Material) -> MeshInstance3D:
	var a = MeshInstance3D.new()
	var b = BoxMesh.new()
	b.size = s
	a.mesh = b
	a.material_override = mat
	a.position = p
	add_child(a)
	return a

func _physics_process(delta: float) -> void:
	if driver:
		var accel = float(Input.is_action_pressed("move_forward")) - float(Input.is_action_pressed("move_back"))
		var steer = float(Input.is_action_pressed("move_left")) - float(Input.is_action_pressed("move_right"))
		var traction = maxf(0.4, 1.0 - damage / 140.0)
		speed = move_toward(speed, accel * max_speed * traction, delta * (12.0 if accel != 0 else 6.0))
		if Input.is_action_pressed("jump"):
			speed = move_toward(speed, 0, delta * 28.0)
		heading += steer * steering * delta * clampf(absf(speed) / 8.0, 0, 1.2) * signf(speed)
	else:
		speed = move_toward(speed, 0, delta * 7)
	rotation.y = heading
	var forward = -transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y -= 20 * delta
	move_and_slide()
	for wheel in wheel_nodes:
		wheel.rotation.x += speed * delta * 1.2
	for n in range(get_slide_collision_count()):
		var collision = get_slide_collision(n)
		if collision != null and absf(speed) > 6:
			var impact = absf(speed) * delta * 7
			damage = minf(100.0, damage + impact)
			speed *= 0.74
			if driver:
				game.vehicle_collision(self, collision.get_collider(), impact)
	if global_position.y < -12:
		global_position = Vector3(0, 2, 0)
		speed = 0
	if cargo != null and is_instance_valid(cargo):
		cargo.global_position = global_position - global_transform.basis.z * (3.8 if kind == "truck" else 2.25) + Vector3.UP * 0.85

func attach_cargo(body: Node3D) -> void:
	cargo = body
	if body is RigidBody3D:
		body.freeze = true
	if body is CollisionObject3D:
		body.collision_layer = 0
		body.collision_mask = 0

func release_cargo() -> Node3D:
	if cargo == null:
		return null
	var box = cargo
	cargo = null
	box.global_position = global_position - global_transform.basis.z * 3.7 + Vector3.UP * 1.3
	if box is RigidBody3D:
		box.freeze = false
	if box is CollisionObject3D:
		box.collision_layer = 8
		box.collision_mask = 1 | 2 | 4 | 8
	return box
