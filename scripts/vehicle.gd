extends CharacterBody3D
## Arcade vehicle with inertia, collision impulses, cargo handling and persistent damage.

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
var exhaust = 0.0

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
	var box = BoxShape3D.new()
	box.size = size
	body.shape = box
	body.position.y = size.y * 0.5 + 0.25
	add_child(body)
	var mat = _mat(tint)
	_add_box(Vector3(0, size.y * 0.43 + 0.25, 0), Vector3(size.x * 0.96, size.y * 0.8, size.z * 0.96), mat)
	if kind == "car":
		_add_box(Vector3(0, 1.6, 0.1), Vector3(1.8, 0.75, 2.35), _mat(Color("1a2732")))
	elif kind == "forklift":
		_add_box(Vector3(0, 2.1, 0.57), Vector3(1.65, 0.13, 1.65), _mat(Color("262b2e")))
		for x in [-0.72, 0.72]:
			_add_box(Vector3(x, 1.35, 1.25), Vector3(0.12, 2.5, 0.12), _mat(Color("303239")))
			_add_box(Vector3(x, 0.25, -2.0), Vector3(0.2, 0.13, 1.65), _mat(Color("a6a9a3")))
	else:
		_add_box(Vector3(0, 2.28, -1.3), Vector3(2.92, 2.45, 4.4), _mat(Color("d9d9d3")))
		_add_box(Vector3(0, 2.65, 2.0), Vector3(2.7, 0.85, 1.9), _mat(Color("20313b")))
	for x in [-size.x * 0.47, size.x * 0.47]:
		for z in [-size.z * 0.33, size.z * 0.33]:
			var wheel = _add_box(Vector3(x, 0.48, z), Vector3(0.32, 0.83, 0.9), _mat(Color("101318")))
			wheel_nodes.append(wheel)
	_add_box(Vector3(-size.x * 0.27, 0.8, -size.z * 0.5), Vector3(0.35, 0.2, 0.05), _mat(Color("f5e5a1")))
	_add_box(Vector3(size.x * 0.27, 0.8, -size.z * 0.5), Vector3(0.35, 0.2, 0.05), _mat(Color("f5e5a1")))
	heading = rotation.y

func _mat(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.3
	m.roughness = 0.55
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
	for n in get_slide_collision_count():
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
