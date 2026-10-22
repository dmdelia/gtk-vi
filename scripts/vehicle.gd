extends CharacterBody3D
## Detailed original hard-surface vehicle models using real texture maps and curved geometry.
const V = preload("res://scripts/visuals.gd")

var game
var kind = "car"
var vehicle_id = ""
var tint = Color("#bc3030")
var speed = 0.0
var heading = 0.0
var driver = false
var damage = 0.0
var max_speed = 25.0
var steering = 1.5
var cargo: Node3D
var wheel_nodes: Array[Node3D] = []
var model: Node3D

func setup(id: String, type_name: String, color: Color) -> void:
	vehicle_id = id
	kind = type_name
	tint = color

func _ready() -> void:
	name = vehicle_id
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	var hitbox_size = Vector3(2.2, 1.8, 4.5)
	if kind == "forklift":
		hitbox_size = Vector3(1.8, 2.2, 3.7)
		max_speed = 11.0
		steering = 2.1
	elif kind == "truck":
		hitbox_size = Vector3(3.05, 3.3, 8.0)
		max_speed = 17.0
		steering = .93
	var collider = CollisionShape3D.new()
	var collision = BoxShape3D.new()
	collision.size = hitbox_size
	collider.shape = collision
	collider.position = Vector3(0,hitbox_size.y*.5+.25,0)
	add_child(collider)
	model = Node3D.new()
	model.name = "DetailedVehicleModel"
	add_child(model)
	match kind:
		"forklift": _forklift()
		"truck": _truck()
		_: _car()
	heading = rotation.y

func _paint() -> StandardMaterial3D:
	return V.plain(tint,.36,.28)

func _glass() -> StandardMaterial3D:
	var glass = V.plain(Color("#93bdd8ae"),.12,.07)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return glass

func _metal() -> StandardMaterial3D:
	return V.material("steel",Color("#bbc2c9"),.65)

func _black() -> StandardMaterial3D:
	return V.material("rubber",Color("#424a50"))

func _headlights(front_z: float, rear_z: float, half_width: float) -> void:
	for side in [-1,1]:
		var x = float(side) * half_width
		V.cuboid(model,Vector3(x,.87,front_z),Vector3(.45,.22,.06),V.plain(Color("#f7e3a6"),.0,.24,true))
		V.cuboid(model,Vector3(x,.88,rear_z),Vector3(.4,.19,.07),V.plain(Color("#de454b"),.0,.3,true))

func _wheels(positions: Array[Vector3], radius: float, width: float) -> void:
	for p in positions:
		wheel_nodes.append(V.wheel(model,p,radius,width,_metal()))

func _car() -> void:
	var paint = _paint()
	var glass = _glass()
	var metal = _metal()
	var black = _black()
	# Wedge front and rear, angled windshield, distinct sedan roof rather than toy blocks.
	V.wedge(model,Vector3(0,.58,-1.15),2.06,1.87,.52,.73,paint)
	V.wedge(model,Vector3(0,.59,1.23),2.05,1.85,.74,.52,paint)
	V.cuboid(model,Vector3(0,.53,0),Vector3(2.08,.53,3.8),paint)
	V.wedge(model,Vector3(0,1.15,-.15),1.76,2.12,1.22,1.18,paint)
	# Sloped windshield and rear pane: trapezoid meshes, side glass.
	V.wedge(model,Vector3(0,1.23,-.63),1.6,.56,.76,.16,glass)
	V.wedge(model,Vector3(0,1.23,.63),1.6,.57,.16,.75,glass)
	for side in [-1,1]:
		var sx = float(side)
		V.cuboid(model,Vector3(sx*.93,1.48,-.26),Vector3(.06,.52,.65),glass)
		V.cuboid(model,Vector3(sx*.93,1.48,.48),Vector3(.06,.48,.53),glass)
		V.cuboid(model,Vector3(sx*1.044,.79,0),Vector3(.035,.04,1.63),metal)
		V.cuboid(model,Vector3(sx*1.045,.84,.06),Vector3(.065,.06,.2),metal)
		V.sphere(model,Vector3(sx*1.14,1.16,-.83),Vector3(.45,.18,.28),paint)
		V.cuboid(model,Vector3(sx*1.03,1.02,-.83),Vector3(.11,.19,.1),black)
		# Wheel-arch trims curve around the wheel.
		for zz in [-1.28,1.29]:
			V.sphere(model,Vector3(sx*1.05,.69,zz),Vector3(.19,.98,1.05),paint,20)
			V.sphere(model,Vector3(sx*1.15,.54,zz),Vector3(.12,.87,.90),black)
	V.cuboid(model,Vector3(0,.62,-2.11),Vector3(1.78,.24,.2),metal)
	V.cuboid(model,Vector3(0,.59,2.09),Vector3(1.85,.24,.2),metal)
	V.cuboid(model,Vector3(0,.84,-2.065),Vector3(.94,.22,.06),black)
	V.cuboid(model,Vector3(0,.75,2.155),Vector3(.48,.14,.025),V.plain(Color("#e8e6d3")))
	_headlights(-2.12,2.10,.75)
	var places: Array[Vector3] = []
	for x in [-.98,.98]:
		for z in [-1.26,1.31]:
			places.append(Vector3(x,.49,z))
	_wheels(places,.46,.25)

func _forklift() -> void:
	var yellow = _paint()
	var metal = _metal()
	var black = _black()
	var glass = _glass()
	V.wedge(model,Vector3(0,.42,.3),1.48,2.16,1.05,.72,yellow)
	V.cuboid(model,Vector3(0,.69,.28),Vector3(1.62,.45,1.88),yellow)
	V.sphere(model,Vector3(0,.9,1.1),Vector3(1.45,.64,.76),black)
	V.cuboid(model,Vector3(0,.88,.41),Vector3(.83,.16,.67),black)
	V.cuboid(model,Vector3(0,1.45,.54),Vector3(.72,1.0,.16),black)
	# Four real tubular pillars, roof guard and braces.
	for x in [-.75,.75]:
		for z in [-.8,1.07]:
			V.pipe_between(model,Vector3(x,.68,z),Vector3(x,2.38,z),.08,metal)
		for z in [-.8,1.07]:
			V.pipe_between(model,Vector3(-.75,2.38,z),Vector3(.75,2.38,z),.08,metal)
		V.pipe_between(model,Vector3(x,2.38,-.8),Vector3(x,2.38,1.07),.09,metal)
	# Fork carriage and hydraulic lift mechanism.
	for x in [-.64,.64]:
		V.cuboid(model,Vector3(x,1.35,-1.37),Vector3(.17,2.72,.16),metal)
		V.cylinder(model,Vector3(x*.5,1.25,-1.12),.092,2.03,V.plain(Color("#e0e3e5"),.9,.19))
		V.cuboid(model,Vector3(x*.43,.35,-1.55),Vector3(.14,.18,1.7),metal)
	V.cuboid(model,Vector3(0,1.25,-1.4),Vector3(1.34,.14,.17),black)
	V.cuboid(model,Vector3(0,1.8,-1.41),Vector3(1.23,.14,.17),black)
	# Operator steering wheel and beacon.
	V.cylinder(model,Vector3(-.27,1.37,-.41),.32,.08,black,22,Vector3(PI*.5,0,0))
	V.cylinder(model,Vector3(0,2.5,.43),.12,.21,V.plain(Color("#f7b44e"),0,.25,true))
	V.cuboid(model,Vector3(0,2.27,.43),Vector3(.32,.1,.36),metal)
	_headlights(-1.5,1.39,.57)
	var places: Array[Vector3] = []
	for x in [-.76,.76]:
		for z in [-.67,.95]:
			places.append(Vector3(x,.43,z))
	_wheels(places,.43,.28)

func _truck() -> void:
	var paint = _paint()
	var metal = _metal()
	var black = _black()
	var glass = _glass()
	# Chassis with separate cab and box trailer profile.
	V.cuboid(model,Vector3(0,.76,0),Vector3(2.55,.36,7.15),black)
	V.cuboid(model,Vector3(0,2.02,-1.24),Vector3(2.79,2.63,4.48),V.material("sheetmetal",Color("#e6e6e2")))
	V.wedge(model,Vector3(0,.79,2.3),2.47,2.12,1.26,1.66,paint)
	V.cuboid(model,Vector3(0,1.87,2.27),Vector3(2.45,1.18,1.93),paint)
	V.wedge(model,Vector3(0,2.47,2.25),2.13,1.26,.55,.84,glass)
	V.cuboid(model,Vector3(0,3.0,2.35),Vector3(2.48,.28,1.9),paint)
	for side in [-1,1]:
		var sx=float(side)
		V.cuboid(model,Vector3(sx*1.25,2.07,2.18),Vector3(.05,.73,1.16),glass)
		V.cuboid(model,Vector3(sx*1.42,2.1,2.73),Vector3(.12,.25,.33),black)
		V.cuboid(model,Vector3(sx*1.31,.93,2.38),Vector3(.06,.07,.21),metal)
		# Trailer rivet rails.
		for z in [-3,-2.2,-1.4,-.6,.2,.9]:
			V.sphere(model,Vector3(sx*1.414,2.58,z),Vector3(.055,.055,.055),black)
		V.cuboid(model,Vector3(sx*1.41,1.3,-1.1),Vector3(.08,.13,4.3),metal)
	# Lower under-run guard, grille, rear door hinges.
	V.cuboid(model,Vector3(0,.84,3.46),Vector3(2.2,.32,.19),metal)
	for i in range(7):
		V.cuboid(model,Vector3(-.75+i*.25,1.13,3.49),Vector3(.09,.42,.04),black)
	V.cuboid(model,Vector3(0,.87,-3.56),Vector3(2.69,.28,.12),metal)
	for side in [-1,1]:
		for z in [-3.53,-2.4]:
			V.cuboid(model,Vector3(float(side)*1.15,1.55,z),Vector3(.12,1.6,.11),metal)
	V.cylinder(model,Vector3(-.86,1.82,1.2),.08,2.45,metal)
	_headlights(3.47,-3.56,1.02)
	var places: Array[Vector3] = []
	for x in [-1.38,1.38]:
		for z in [-2.65,-1.63,2.55]:
			places.append(Vector3(x,.63,z))
	_wheels(places,.61,.33)

func _physics_process(delta: float) -> void:
	if driver:
		var accel = float(Input.is_action_pressed("move_forward")) - float(Input.is_action_pressed("move_back"))
		var steer = float(Input.is_action_pressed("move_left")) - float(Input.is_action_pressed("move_right"))
		var traction = maxf(.4,1.0-damage/140.0)
		speed = move_toward(speed,accel*max_speed*traction,delta*(12.0 if accel != 0 else 6.0))
		if Input.is_action_pressed("jump"):
			speed = move_toward(speed,0,delta*28.0)
		heading += steer*steering*delta*clampf(absf(speed)/8.0,0,1.2)*signf(speed)
	else:
		speed = move_toward(speed,0,delta*7)
	rotation.y = heading
	var forward = -transform.basis.z
	velocity.x = forward.x*speed
	velocity.z = forward.z*speed
	velocity.y -= 20*delta
	move_and_slide()
	for wheel in wheel_nodes:
		wheel.rotation.x += speed*delta*1.2
	for n in range(get_slide_collision_count()):
		var col = get_slide_collision(n)
		if col != null and absf(speed) > 6:
			var impact = absf(speed)*delta*7
			damage = minf(100,damage+impact)
			speed *= .74
			if driver and game != null:
				game.vehicle_collision(self,col.get_collider(),impact)
	if global_position.y < -12:
		global_position = Vector3(0,2,0)
		speed=0
	if cargo != null and is_instance_valid(cargo):
		cargo.global_position = global_position-global_transform.basis.z*(3.8 if kind == "truck" else 2.25)+Vector3.UP*.85

func attach_cargo(body: Node3D) -> void:
	cargo=body
	if body is RigidBody3D:
		body.freeze=true
	if body is CollisionObject3D:
		body.collision_layer=0
		body.collision_mask=0

func release_cargo() -> Node3D:
	if cargo == null:
		return null
	var box = cargo
	cargo = null
	box.global_position=global_position-global_transform.basis.z*3.7+Vector3.UP*1.3
	if box is RigidBody3D:
		box.freeze=false
	if box is CollisionObject3D:
		box.collision_layer=8
		box.collision_mask=1|2|4|8
	return box
