extends Node3D
## Self-contained original industrial map. World coordinates are deliberately data-driven.

const BLOCKS = [
	{"name":"KARTONHALLE A", "x":-86.0, "z":-48.0, "w":62.0, "d":55.0, "color":"#314552"},
	{"name":"KARTONHALLE B", "x":-15.0, "z":-48.0, "w":62.0, "d":55.0, "color":"#455055"},
	{"name":"HOCHREGALLAGER", "x":63.0, "z":-48.0, "w":69.0, "d":55.0, "color":"#4c4540"},
	{"name":"VERWALTUNG", "x":-92.0, "z":45.0, "w":47.0, "d":36.0, "color":"#455968"},
	{"name":"KANTINE", "x":-39.0, "z":46.0, "w":37.0, "d":34.0, "color":"#66705c"},
	{"name":"WERKSTATT", "x":12.0, "z":46.0, "w":40.0, "d":35.0, "color":"#5d524d"},
	{"name":"VERSAND", "x":76.0, "z":48.0, "w":62.0, "d":34.0, "color":"#5c6267"}
]

var game
var objects: Array[Dictionary] = []
var machines: Array[Node3D] = []
var pallets: Array[RigidBody3D] = []
var flicker_lights: Array[OmniLight3D] = []
var machine_running = true
var special_pallet: RigidBody3D
var nav = AStar3D.new()
var nav_positions: Dictionary = {}
var nav_ready = false
var rng = RandomNumberGenerator.new()
var t = 0.0
var materials: Dictionary = {}

func _ready() -> void:
	rng.seed = 493713
	_build()

func _material(c: String, metal = 0.0, roughness = 0.82, transparent = false) -> StandardMaterial3D:
	var key = "%s|%s|%s|%s" % [c, metal, roughness, transparent]
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.metallic = metal
	m.roughness = roughness
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials[key] = m
	return m

func box(pos: Vector3, dim: Vector3, color = "#565f64", solid = true, parent: Node3D = null, metal = 0.0) -> Node3D:
	var root: Node3D
	if solid:
		var shape_root = StaticBody3D.new()
		shape_root.collision_layer = 1
		shape_root.collision_mask = 0
		var shape = CollisionShape3D.new()
		var b = BoxShape3D.new()
		b.size = dim
		shape.shape = b
		shape_root.add_child(shape)
		root = shape_root
	else:
		root = Node3D.new()
	var mesh = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = dim
	mesh.mesh = cube
	mesh.material_override = _material(color, metal)
	root.add_child(mesh)
	root.position = pos
	if parent == null:
		add_child(root)
	else:
		parent.add_child(root)
	return root

func sign_text(value: String, pos: Vector3, size = 0.45, color = Color("#f3e5be"), turn = 0.0) -> Label3D:
	var l = Label3D.new()
	l.text = value
	l.font_size = 48
	l.pixel_size = size / 48.0
	l.modulate = color
	l.outline_size = 7
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.rotation.y = turn
	l.no_depth_test = false
	add_child(l)
	return l

func _building(info: Dictionary) -> void:
	var x: float = info.x
	var z: float = info.z
	var w: float = info.w
	var d: float = info.d
	var wall = str(info.color)
	box(Vector3(x, -0.18, z), Vector3(w, 0.32, d), "#b7b5ab")
	# Four external walls, with 8-meter-wide passages at north/south.
	box(Vector3(x - w*0.5, 5.7, z), Vector3(0.6, 11.4, d), wall)
	box(Vector3(x + w*0.5, 5.7, z), Vector3(0.6, 11.4, d), wall)
	for side in [-1, 1]:
		var edge_z = z + side*d*0.5
		box(Vector3(x - (w+8)*0.25, 5.7, edge_z), Vector3((w-8)*0.5, 11.4, 0.6), wall)
		box(Vector3(x + (w+8)*0.25, 5.7, edge_z), Vector3((w-8)*0.5, 11.4, 0.6), wall)
		box(Vector3(x, 10.65, edge_z), Vector3(8, 1.5, 0.7), "#303c46")
		box(Vector3(x, 8.4, edge_z), Vector3(8.0, 3.0, 0.25), "#8699a222", false)
	# Steel roof ribs leave the interior visible from the third-person camera.
	for i in range(-2, 3):
		box(Vector3(x + w*float(i)/5.4, 11.5, z), Vector3(0.55, 0.65, d), "#747d81")
	for j in [-1, 0, 1]:
		box(Vector3(x, 11.55, z + d*j/3.6), Vector3(w, 0.55, 0.55), "#747d81")
	sign_text(str(info.name), Vector3(x, 8.3, z+d*0.5+0.72), 0.55, Color("#ffc96a"))
	# Columns with hazard stripes.
	for i in [-1, 1]:
		for j in [-1, 1]:
			box(Vector3(x + i*(w*0.5-3), 5.5, z + j*(d*0.5-3)), Vector3(0.8, 11, 0.8), "#a79b66")

func _build() -> void:
	box(Vector3(0,-0.7,0), Vector3(320,1.4,250), "#555d60")
	# Ground, roads, painted lanes, compound boundary.
	for z in [-105.0, 9.0, 100.0]:
		box(Vector3(0,0.035,z), Vector3(313,0.065,12), "#33383b", false)
		for x in range(-145, 146, 11):
			box(Vector3(float(x),0.08,z), Vector3(4.0,0.035,0.18), "#d4bf72", false)
	for x in [-145.0, 146.0]:
		box(Vector3(x,0.035,0), Vector3(11,0.07,220), "#33383b", false)
	# Perimeter fence with gates at front and rear.
	for z in [-120.0, 120.0]:
		for x in range(-155,156,8):
			if abs(x) < 13 and z > 0:
				continue
			box(Vector3(x,1.4,z), Vector3(7.5,2.8,0.16), "#84969a", false)
			box(Vector3(x,1.6,z), Vector3(0.11,3.2,0.2), "#bac6c3")
	for x in [-155.0, 155.0]:
		for z in range(-116,120,9):
			if 11 < z < 36 and x < 0:
				continue
			box(Vector3(x,1.7,z), Vector3(0.18,3.4,8.5), "#8b999c", false)
	for building in BLOCKS:
		_building(building)
	# Production halls: three different active industrial lines.
	for bx in [-86.0,-15.0]:
		for i in range(3):
			var z = -68.0 + i * 17
			_conveyor(Vector3(bx,z*0.0+0.4,z), 42.0)
			for j in range(4):
				var mx = bx - 21 + j*14
				box(Vector3(mx,1.15,z-4), Vector3(2.7,2.2,2.4), "#7c9b98",true,self,0.65)
				box(Vector3(mx,2.5,z-4), Vector3(2.0,0.6,1.4), "#e1ac5d",false)
				box(Vector3(mx,3.0,z-4), Vector3(0.65,0.65,0.65), "#b4d8ce", false)
		for j in range(7):
			box(Vector3(bx-27+j*8.5,0.08,-72), Vector3(3,0.1,0.2), "#e0bd46",false)
	# Warehouse racks, corridors and movable cartons.
	for row in range(4):
		var z = -68.0 + row*13
		for col in range(4):
			var x = 39.0 + col*15.6
			_rack(Vector3(x,0,z))
	for _i in range(20):
		var p = Vector3(rng.randf_range(38,89),0.9,rng.randf_range(-69,-27))
		if int(p.x) % 7 < 2:
			continue
		crate(p, false)
	special_pallet = crate(Vector3(77,1.05,-47),true)
	special_pallet.name = "Missionspalette"
	# Offices, canteen, break area, lockers.
	for x in [-104.0,-92.0,-80.0]:
		for z in [37.0,48.0]:
			box(Vector3(x,0.68,z), Vector3(3.8,1.3,1.7), "#a8a39a")
			box(Vector3(x,1.4,z-1.9), Vector3(3.8,0.12,0.45), "#232b35",false)
			box(Vector3(x,1.75,z-1.75), Vector3(1.6,0.9,0.13), "#161d24",false)
			box(Vector3(x,0.7,z+2.0), Vector3(1.4,1.4,1.1), "#454f58")
	for x in [-47.0,-38.0,-29.0]:
		for z in [38.0,48.0,56.0]:
			box(Vector3(x,0.9,z), Vector3(2.7,0.16,2.7), "#c3a37a")
			for d in [-2.1,2.1]:
				box(Vector3(x+d,0.55,z), Vector3(0.9,1.1,0.9), "#4b656c")
	for i in range(6):
		box(Vector3(2+i*4.0,1.1,35), Vector3(2.5,2.2,1.8), "#537c87",true,self,0.4)
		box(Vector3(2+i*4.0,1.8,55), Vector3(2.5,3.6,2.0), "#3f5156")
	# Shipping: loading ramps, trailer parking, steel containers.
	for x in [57.0,78.0,99.0]:
		box(Vector3(x,0.8,66), Vector3(14,1.6,6), "#6b7274")
		box(Vector3(x,1.2,68), Vector3(12,2.3,0.32), "#aeb1a9")
	for x in [85.0,105.0,123.0]:
		box(Vector3(x,1.6,89), Vector3(10,3.2,5), "#75807c")
		box(Vector3(x,1.2,91.8), Vector3(7.0,0.7,0.2), "#e2ba52",false)
	# Parking lot, individual spots and traffic cones.
	box(Vector3(-94,0.06,91), Vector3(78,0.08,30), "#2d3034",false)
	for x in range(-127,-58,9):
		box(Vector3(float(x),0.12,80), Vector3(0.17,0.05,12), "#e8e2bc",false)
	for i in range(18):
		var x = rng.randf_range(-130,130)
		var z = rng.randf_range(108,113)
		box(Vector3(x,0.45,z), Vector3(0.75,0.9,0.75),"#e6a443")
	# Streetlights and isolated workshop lighting.
	for x in [-138.0,-67.0,1.0,70.0,139.0]:
		for z in [13.0,104.0]:
			_streetlight(Vector3(x,0,z))
	for b in BLOCKS:
		for i in [-1,1]:
			var omni = OmniLight3D.new()
			omni.position = Vector3(float(b.x)+float(i)*float(b.w)*0.22, 9.5, float(b.z))
			omni.omni_range = 24
			omni.light_energy = 0.95
			omni.light_color = Color("#ffe4ae")
			add_child(omni)
			flicker_lights.append(omni)
	# Interaction nodes are real world entities and mission events.
	interactive("timeclock", "EINSTEMPELN",Vector3(-110,0,55), "#58c0b4")
	interactive("barcode", "PALETTENSCAN",Vector3(82,0,-63), "#f6b353")
	interactive("terminal", "LIEFERDATEN",Vector3(-83,0,39), "#85c4ff")
	interactive("override", "SICHERHEITSSCHALTER",Vector3(1,0,-42), "#fb6e6e")
	interactive("line_a", "NOTHALT LINIE A",Vector3(-66,0,-55), "#ef4e54")
	interactive("line_b", "NOTHALT LINIE B",Vector3(-13,0,-53), "#ef4e54")
	interactive("line_c", "NOTHALT LINIE C",Vector3(16,0,-37), "#ef4e54")
	interactive("blueprint", "BLAUE AKTE",Vector3(50,0,-39), "#6cb8ec")
	interactive("final_terminal", "ZENTRALRECHNER",Vector3(-97,0,54), "#f09c60")
	interactive("ending_a", "NOTAUSGANG WEST",Vector3(-137,0,27), "#65bd9a")
	interactive("ending_b", "FLUCHTWEG NORD",Vector3(10,0,106), "#ffc166")
	interactive("challenge", "STAPLER-SLALOM",Vector3(-6,0,75), "#f2cd5c")
	interactive("secret", "GEHEIME TÜR",Vector3(128,0,-92), "#b579f3")
	interactive("vending", "GETRÄNKEAUTOMAT",Vector3(-34,0,36), "#e7a0af")
	interactive("repair", "FAHRZEUGWERKSTATT",Vector3(19,0,58), "#85d8ce")
	# Signage and ambient details.
	sign_text("KARTON EU IV",Vector3(0,14,117),1.9,Color("#efd598"))
	sign_text("WERKSZUFAHRT   |   20 km/h",Vector3(-2,4,112),0.68)
	sign_text("BETRIEBSGEHEIMNIS: KEINE SPASSBREMSE",Vector3(-60,4,-80),0.3,Color("#f1d4a9"))
	for _i in range(25):
		var x = rng.randf_range(-145,145)
		var z = rng.randf_range(111,117)
		box(Vector3(x,0.27,z), Vector3(1.1,0.54,0.8),"#656b61",false)

func _streetlight(p: Vector3) -> void:
	box(p+Vector3.UP*4.9,Vector3(0.18,9.8,0.18),"#7b858a")
	box(p+Vector3(0,9.7,-1.9),Vector3(0.18,0.12,3.8),"#7b858a",false)
	var glow = OmniLight3D.new()
	glow.position = p+Vector3(0,9.3,-3.5)
	glow.omni_range = 21
	glow.light_energy = 0.4
	glow.light_color = Color("#f6d9a0")
	add_child(glow)

func _rack(p: Vector3) -> void:
	for ix in [-1,1]:
		for iz in [-1,1]:
			box(p+Vector3(ix*4.7,4.0,iz*1.55),Vector3(0.22,8,0.22),"#a76c35")
	for h in [1.1,3.8,6.6]:
		box(p+Vector3(0,h,0),Vector3(10,0.19,3.5),"#586575")
		for i in [-3.1,0,3.1]:
			box(p+Vector3(i,h+0.7,0),Vector3(2.5,1.3,2.7),"#bb9260",false)

func _conveyor(p: Vector3, width: float) -> void:
	box(p+Vector3(0,0.57,0),Vector3(width,0.4,3.0),"#48565e")
	for k in range(int(width / 2)):
		var roller = box(p+Vector3(-width/2+1.2+k*2,0.89,0),Vector3(0.22,0.11,2.6),"#b4c8c4",false)
		machines.append(roller)
	for k in range(5):
		var item = box(p+Vector3(-width/2+k*8,1.6,0),Vector3(2.25,1.1,1.95),"#ccab74",false)
		item.set_meta("belt_min",p.x-width/2)
		item.set_meta("belt_max",p.x+width/2)
		machines.append(item)

func crate(p: Vector3, important = false) -> RigidBody3D:
	var b = RigidBody3D.new()
	b.position = p
	b.mass = 12 if important else 5
	b.collision_layer = 8
	b.collision_mask = 1 | 2 | 4 | 8
	b.add_to_group("crates")
	var c = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.75,1.7,1.75) if important else Vector3(1.1,1.1,1.1)
	c.shape = shape
	b.add_child(c)
	var mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = shape.size
	mesh.mesh = bm
	mesh.material_override = _material("#d09d57" if important else "#c09d6b")
	b.add_child(mesh)
	if important:
		var label = Label3D.new()
		label.text = "KEU-404 / EXPRESS"
		label.position.y = 1.04
		label.font_size = 40
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.add_child(label)
	add_child(b)
	pallets.append(b)
	return b

func interactive(id: String, title: String, p: Vector3, tint: String) -> void:
	var root = box(p+Vector3(0,1.15,0),Vector3(1.5,2.3,0.8),"#28333c")
	root.name = id
	box(Vector3(0,0.42,-0.45),Vector3(1.1,0.92,0.12),tint,false,root)
	var label = Label3D.new()
	label.text = title
	label.pixel_size = 0.005
	label.font_size = 38
	label.position = Vector3(0,0.65,-0.58)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	objects.append({"id":id,"name":title,"node":root,"position":p+Vector3.UP})

func nearest_interactive(at: Vector3, max_dist = 4.0) -> Dictionary:
	var best = {}
	var dist = max_dist
	for entry in objects:
		var d = at.distance_to(entry.position)
		if d < dist:
			dist = d
			best = entry
	return best

func _process(delta: float) -> void:
	t += delta
	if machine_running:
		for m in machines:
			if m.has_meta("belt_min"):
				m.position.x += delta * 2.5
				if m.position.x > float(m.get_meta("belt_max")):
					m.position.x = float(m.get_meta("belt_min"))
			else:
				m.rotation.z += delta * 2.1
	for i in flicker_lights.size():
		if i % 8 == 0:
			flicker_lights[i].light_energy = 0.68 + sin(t*12+i)*0.06

func setup_navigation() -> void:
	# Graph nodes and collision-checked edges form genuine pathfinding around walls/racks.
	var space = get_world_3d().direct_space_state
	var width = 41
	var depth = 31
	var next_id = 0
	for iz in range(depth):
		for ix in range(width):
			var pos = Vector3(-140 + ix*7.0,1.45,-105 + iz*7.0)
			var probe = PhysicsPointQueryParameters3D.new()
			probe.position = pos
			probe.collision_mask = 1
			if space.intersect_point(probe).size() > 0:
				continue
			nav.add_point(next_id, pos)
			nav_positions[Vector2i(ix,iz)] = next_id
			next_id += 1
	for key in nav_positions:
		var id: int = nav_positions[key]
		for delta_pos in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]:
			var neighbor: Vector2i = key + delta_pos
			if not nav_positions.has(neighbor):
				continue
			var other: int = nav_positions[neighbor]
			var query = PhysicsRayQueryParameters3D.create(nav.get_point_position(id),nav.get_point_position(other),1)
			if space.intersect_ray(query).is_empty():
				nav.connect_points(id,other)
	nav_ready = true

func closest_navigation_point(at: Vector3) -> int:
	if nav.get_point_count() == 0:
		return -1
	return nav.get_closest_point(at)

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not nav_ready:
		return PackedVector3Array([to])
	var a = closest_navigation_point(from)
	var b = closest_navigation_point(to)
	if a < 0 or b < 0:
		return PackedVector3Array([to])
	var route = nav.get_point_path(a,b)
	if route.size() == 0:
		return PackedVector3Array([to])
	return route

func get_blocks() -> Array:
	return BLOCKS
