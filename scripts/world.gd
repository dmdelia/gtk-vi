extends Node3D
## Texture-overhauled industrial yard inspired by the real karton.eu logistics footprint in Spremberg.
## The northern part contains the long hall blocks, while parking, administration and service sit south/front.

const BLOCKS = [
	{"name":"HALLE A", "x":-109.0, "z":-54.0, "w":48.0, "d":58.0, "wall_style":"hall_blue", "roof_style":"roof_light", "map_color":"#56788e"},
	{"name":"HALLE B", "x":-44.0, "z":-54.0, "w":52.0, "d":58.0, "wall_style":"hall_grey", "roof_style":"roof_light", "map_color":"#7d8589"},
	{"name":"HALLE C", "x":28.0, "z":-54.0, "w":62.0, "d":58.0, "wall_style":"warehouse_dark", "roof_style":"roof_dark", "map_color":"#6f685f"},
	{"name":"HALLE D", "x":104.0, "z":-54.0, "w":50.0, "d":58.0, "wall_style":"hall_grey", "roof_style":"roof_light", "map_color":"#a6aaad"},
	{"name":"HOCHREGALLAGER", "x":-43.0, "z":18.0, "w":38.0, "d":72.0, "wall_style":"hall_grey", "roof_style":"roof_light", "map_color":"#8a8f95"},
	{"name":"VERSAND", "x":34.0, "z":25.0, "w":66.0, "d":42.0, "wall_style":"shipping_grey", "roof_style":"roof_light", "map_color":"#9ca5ab"},
	{"name":"KANTINE", "x":24.0, "z":-8.0, "w":22.0, "d":16.0, "wall_style":"office_sage", "roof_style":"roof_dark", "map_color":"#92a087"},
	{"name":"WERKSTATT", "x":3.0, "z":22.0, "w":16.0, "d":16.0, "wall_style":"workshop_red", "roof_style":"roof_dark", "map_color":"#9e665b"},
	{"name":"VERWALTUNG", "x":82.0, "z":18.0, "w":14.0, "d":18.0, "wall_style":"office_white", "roof_style":"roof_dark", "map_color":"#d0d4cf"}
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
var texture_cache: Dictionary = {}

func _ready() -> void:
	rng.seed = 493713
	_build()

func _style_material(style: String, transparent = false) -> StandardMaterial3D:
	var key = "%s|%s" % [style, transparent]
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.roughness = 0.84
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match style:
		"asphalt":
			m.albedo_texture = _pattern_texture("asphalt", "#545b61", "#262b2f", 160)
			m.roughness = 0.96
			m.uv1_scale = Vector3(12, 12, 12)
		"road_marked":
			m.albedo_texture = _pattern_texture("asphalt", "#494f55", "#23272a", 160)
			m.roughness = 0.96
			m.uv1_scale = Vector3(14, 14, 14)
		"concrete":
			m.albedo_texture = _pattern_texture("speckle", "#b9b7af", "#8c8980", 160)
			m.roughness = 0.94
			m.uv1_scale = Vector3(9, 9, 9)
		"polished_concrete":
			m.albedo_texture = _pattern_texture("speckle", "#c9c5bb", "#9f9a90", 160)
			m.roughness = 0.68
			m.uv1_scale = Vector3(10, 10, 10)
		"hall_blue":
			m.albedo_texture = _pattern_texture("cladding", "#6e8da2", "#44606e", 256)
			m.roughness = 0.58
			m.metallic = 0.28
			m.uv1_scale = Vector3(4.2, 4.2, 4.2)
		"hall_grey":
			m.albedo_texture = _pattern_texture("cladding", "#9ca2a5", "#5f666b", 256)
			m.roughness = 0.58
			m.metallic = 0.24
			m.uv1_scale = Vector3(4.2, 4.2, 4.2)
		"hall_sand":
			m.albedo_texture = _pattern_texture("cladding", "#c1b58f", "#7d7157", 256)
			m.roughness = 0.6
			m.metallic = 0.18
			m.uv1_scale = Vector3(4.0, 4.0, 4.0)
		"warehouse_dark":
			m.albedo_texture = _pattern_texture("cladding", "#7d746a", "#514942", 256)
			m.roughness = 0.63
			m.metallic = 0.22
			m.uv1_scale = Vector3(3.8, 3.8, 3.8)
		"office_white":
			m.albedo_texture = _pattern_texture("cladding", "#d9ddd7", "#9fa59d", 256)
			m.roughness = 0.66
			m.uv1_scale = Vector3(3.4, 3.4, 3.4)
		"office_sage":
			m.albedo_texture = _pattern_texture("cladding", "#acb59d", "#6b7361", 256)
			m.roughness = 0.66
			m.uv1_scale = Vector3(3.4, 3.4, 3.4)
		"workshop_red":
			m.albedo_texture = _pattern_texture("cladding", "#b17567", "#72463b", 256)
			m.roughness = 0.62
			m.uv1_scale = Vector3(3.7, 3.7, 3.7)
		"shipping_grey":
			m.albedo_texture = _pattern_texture("cladding", "#9aa1a8", "#636b72", 256)
			m.roughness = 0.6
			m.uv1_scale = Vector3(4.1, 4.1, 4.1)
		"roof_light":
			m.albedo_texture = _pattern_texture("roof", "#c2c7ca", "#8a8f95", 256)
			m.roughness = 0.72
			m.metallic = 0.18
			m.uv1_scale = Vector3(5.2, 5.2, 5.2)
		"roof_dark":
			m.albedo_texture = _pattern_texture("roof", "#70767b", "#43484c", 256)
			m.roughness = 0.72
			m.metallic = 0.2
			m.uv1_scale = Vector3(5.2, 5.2, 5.2)
		"glass":
			m.albedo_texture = _pattern_texture("window", "#7bb7da88", "#21384622", 128)
			m.roughness = 0.1
			m.metallic = 0.0
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.uv1_scale = Vector3(2.2, 2.2, 2.2)
		"galvanized":
			m.albedo_texture = _pattern_texture("speckle", "#c9cfce", "#7e8887", 128)
			m.roughness = 0.52
			m.metallic = 0.44
			m.uv1_scale = Vector3(7.5, 7.5, 7.5)
		"hazard":
			m.albedo_texture = _pattern_texture("hazard", "#e3b83c", "#211c15", 128)
			m.roughness = 0.64
			m.uv1_scale = Vector3(3.5, 3.5, 3.5)
		"cardboard":
			m.albedo_texture = _pattern_texture("cardboard", "#caa269", "#8f6937", 256)
			m.roughness = 0.92
			m.uv1_scale = Vector3(5.0, 5.0, 5.0)
		"wood":
			m.albedo_texture = _pattern_texture("wood", "#b98a58", "#714927", 256)
			m.roughness = 0.86
			m.uv1_scale = Vector3(6.0, 6.0, 6.0)
		"machine_teal":
			m.albedo_texture = _pattern_texture("machine", "#7aa49d", "#466c69", 128)
			m.roughness = 0.48
			m.metallic = 0.42
			m.uv1_scale = Vector3(3.2, 3.2, 3.2)
		"painted_steel":
			m.albedo_texture = _pattern_texture("machine", "#717d84", "#39454d", 128)
			m.roughness = 0.44
			m.metallic = 0.52
			m.uv1_scale = Vector3(3.5, 3.5, 3.5)
		_:
			if style.begins_with("#"):
				m.albedo_color = Color(style)
			else:
				m.albedo_color = Color("#808890")
	materials[key] = m
	return m

func _pattern_texture(kind: String, c1: String, c2: String, size = 128) -> Texture2D:
	var key = "%s|%s|%s|%d" % [kind, c1, c2, size]
	if texture_cache.has(key):
		return texture_cache[key]
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var a = Color(c1)
	var b = Color(c2)
	for y in range(size):
		for x in range(size):
			var px = a
			match kind:
				"asphalt":
					var n = float(((x * 17 + y * 31 + x * y) % 37)) / 37.0
					px = a.lerp(b, 0.28 + n * 0.22)
					if ((x + y * 2) % 53) == 0:
						px = px.lightened(0.12)
				"speckle":
					var s = float(((x * 11 + y * 19 + x * y * 3) % 29)) / 29.0
					px = a.lerp(b, s * 0.35)
					if ((x + y) % 41) == 0:
						px = px.darkened(0.15)
				"cladding":
					var band = 1.0 if (y % 18) < 2 else 0.0
					var stain = float(((x * 3 + y * 5) % 17)) / 17.0
					px = a.lerp(b, 0.18 + stain * 0.12 + band * 0.35)
				"roof":
					var rib = 1.0 if (x % 22) < 3 else 0.0
					var dirt = float(((x * 5 + y * 7) % 23)) / 23.0
					px = a.lerp(b, 0.2 + dirt * 0.13 + rib * 0.28)
				"window":
					var mullion = ((x % 28) < 2) or ((y % 28) < 2)
					px = b if mullion else a
					if not mullion and (x + y) % 47 < 2:
						px = px.lightened(0.12)
				"hazard":
					var stripe = int(floor(float(x + y) / 18.0)) % 2 == 0
					px = a if stripe else b
				"cardboard":
					var corr = 1.0 if (x % 14) < 3 else 0.0
					var wear = float(((x * 7 + y * 13) % 19)) / 19.0
					px = a.lerp(b, 0.14 + wear * 0.09 + corr * 0.22)
				"wood":
					var grain = (sin(float(x) * 0.14) + sin(float(x) * 0.05 + float(y) * 0.04)) * 0.5 + 0.5
					px = a.lerp(b, grain * 0.45)
					if (y % 59) == 0:
						px = px.darkened(0.18)
				"machine":
					var edge = 1.0 if (x % 29) < 2 or (y % 25) < 2 else 0.0
					var smudge = float(((x * 9 + y * 4) % 31)) / 31.0
					px = a.lerp(b, smudge * 0.3 + edge * 0.22)
				_:
					px = a
			img.set_pixel(x, y, px)
	img.generate_mipmaps()
	var tex = ImageTexture.create_from_image(img)
	texture_cache[key] = tex
	return tex

func box(pos: Vector3, dim: Vector3, style = "concrete", solid = true, parent: Node3D = null, _metal = 0.0) -> Node3D:
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
	mesh.material_override = _style_material(str(style), str(style).ends_with("88") or str(style).ends_with("22"))
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
	var wall = str(info.wall_style)
	var roof = str(info.roof_style)
	var is_office = str(info.name) in ["VERWALTUNG", "KANTINE", "WERKSTATT", "VERSAND"]
	var floor_style = "polished_concrete" if not is_office else "concrete"
	box(Vector3(x, -0.16, z), Vector3(w, 0.28, d), floor_style)
	# Main shell with accessible openings.
	box(Vector3(x - w * 0.5, 5.2, z), Vector3(0.6, 10.4, d), wall)
	box(Vector3(x + w * 0.5, 5.2, z), Vector3(0.6, 10.4, d), wall)
	if is_office:
		for side in [-1, 1]:
			var edge_z = z + side * d * 0.5
			box(Vector3(x - (w + 2.6) * 0.25, 5.2, edge_z), Vector3((w - 2.6) * 0.5, 10.4, 0.6), wall)
			box(Vector3(x + (w + 2.6) * 0.25, 5.2, edge_z), Vector3((w - 2.6) * 0.5, 10.4, 0.6), wall)
			box(Vector3(x, 8.0, edge_z), Vector3(2.6, 4.0, 0.62), wall)
	else:
		for side in [-1, 1]:
			var edge_z = z + side * d * 0.5
			box(Vector3(x - (w + 7.8) * 0.25, 5.2, edge_z), Vector3((w - 7.8) * 0.5, 10.4, 0.6), wall)
			box(Vector3(x + (w + 7.8) * 0.25, 5.2, edge_z), Vector3((w - 7.8) * 0.5, 10.4, 0.6), wall)
			box(Vector3(x, 8.25, edge_z), Vector3(7.8, 4.5, 0.62), wall)
	# Ribbed roof and skylights
	box(Vector3(x, 10.75, z), Vector3(w + 0.5, 0.36, d + 0.5), roof, false)
	for ridge in range(-2, 3):
		box(Vector3(x + ridge * w / 5.3, 11.02, z), Vector3(0.26, 0.38, d - 1.5), "painted_steel", false)
	for lane in [-0.26, 0.0, 0.26]:
		if is_office:
			continue
		box(Vector3(x + w * lane, 10.9, z), Vector3(2.4, 0.1, d - 5.0), "glass", false)
	# Window strips and personnel doors
	if is_office:
		for side in [-1, 1]:
			box(Vector3(x, 5.4, z + side * (d * 0.5 + 0.02)), Vector3(w * 0.72, 2.2, 0.18), "glass", false)
		box(Vector3(x - w * 0.33, 1.55, z + d * 0.5 + 0.04), Vector3(1.6, 2.9, 0.14), "glass", false)
	else:
		for door_x in [-0.33, 0.0, 0.33]:
			box(Vector3(x + w * door_x, 2.55, z + d * 0.5 + 0.02), Vector3(5.8, 4.9, 0.18), "glass", false)
			box(Vector3(x + w * door_x, 2.55, z - d * 0.5 - 0.02), Vector3(5.8, 4.9, 0.18), "glass", false)
			box(Vector3(x + w * door_x, 5.05, z + d * 0.5 + 0.07), Vector3(6.3, 0.22, 0.24), "painted_steel", false)
			box(Vector3(x + w * door_x, 5.05, z - d * 0.5 - 0.07), Vector3(6.3, 0.22, 0.24), "painted_steel", false)
	# Corner columns
	for i in [-1, 1]:
		for j in [-1, 1]:
			box(Vector3(x + i * (w * 0.5 - 2.2), 5.4, z + j * (d * 0.5 - 2.2)), Vector3(0.7, 10.8, 0.7), "hazard")
	sign_text(str(info.name), Vector3(x, 8.0, z + d * 0.5 + 0.76), 0.5, Color("#ffd488"))

func _yard_lines(z_line: float, length: int, color_style: String) -> void:
	for x in range(-148, length, 11):
		box(Vector3(float(x), 0.08, z_line), Vector3(4.2, 0.035, 0.18), color_style, false)

func _build() -> void:
	# Base terrain, roads and yards.
	box(Vector3(0, -0.75, 0), Vector3(328, 1.5, 252), "asphalt")
	box(Vector3(0, 0.02, -103), Vector3(318, 0.05, 14), "road_marked", false)
	box(Vector3(0, 0.02, 7), Vector3(318, 0.05, 15), "road_marked", false)
	box(Vector3(0, 0.02, 105), Vector3(318, 0.05, 16), "road_marked", false)
	box(Vector3(-150, 0.02, 0), Vector3(12, 0.05, 224), "road_marked", false)
	box(Vector3(150, 0.02, 0), Vector3(12, 0.05, 224), "road_marked", false)
	box(Vector3(-16, 0.02, -18), Vector3(256, 0.05, 72), "concrete", false)
	box(Vector3(102, 0.02, 74), Vector3(66, 0.05, 54), "concrete", false)
	_yard_lines(-103, 149, "#d6c071")
	_yard_lines(7, 149, "#d6c071")
	_yard_lines(105, 149, "#d6c071")
	# Crosswalk and parking layout.
	for i in range(7):
		box(Vector3(-75 + i * 2.1, 0.085, 66), Vector3(1.2, 0.03, 4.8), "#f0ece0", false)
	box(Vector3(-97, 0.04, 91), Vector3(82, 0.05, 32), "road_marked", false)
	for x in range(-131, -56, 9):
		box(Vector3(float(x), 0.11, 80), Vector3(0.16, 0.05, 12), "#efe4bd", false)
	# Perimeter fence and gates.
	for z_edge in [-120.0, 120.0]:
		for x_gate in range(-155, 156, 8):
			if abs(x_gate) < 14 and z_edge > 0:
				continue
			box(Vector3(x_gate, 1.4, z_edge), Vector3(7.5, 2.8, 0.16), "galvanized", false)
			box(Vector3(x_gate, 1.6, z_edge), Vector3(0.11, 3.2, 0.2), "galvanized")
	for x_edge in [-155.0, 155.0]:
		for z_post in range(-116, 120, 9):
			if z_post > 11 and z_post < 36 and x_edge < 0:
				continue
			box(Vector3(x_edge, 1.7, z_post), Vector3(0.18, 3.4, 8.5), "galvanized", false)
	# Main blocks.
	for building in BLOCKS:
		_building(building)
	# Hall interiors: conveyors and machine islands.
	for bx in [-109.0, -44.0, 28.0]:
		for i in range(3):
			var zz = -69.0 + i * 17
			_conveyor(Vector3(bx, 0.4, zz), 44.0 if bx < 30 else 36.0)
			for j in range(4):
				var mx = bx - 19 + j * 12.5
				box(Vector3(mx, 1.15, zz - 4), Vector3(2.8, 2.25, 2.5), "machine_teal", true)
				box(Vector3(mx, 2.5, zz - 4), Vector3(2.0, 0.6, 1.4), "#e0aa54", false)
				box(Vector3(mx, 2.95, zz - 4), Vector3(0.75, 0.65, 0.65), "glass", false)
		for j in range(7):
			box(Vector3(bx - 24 + j * 8.1, 0.08, -77), Vector3(3, 0.1, 0.24), "#e1bd46", false)
	# Warehouse racks and cartons.
	for row in range(4):
		var z_row = -70.0 + row * 13
		for col in range(4):
			var x_row = -59.0 + col * 11.5
			_rack(Vector3(x_row, 0, z_row))
	for _i in range(26):
		var p = Vector3(rng.randf_range(-58, -25), 0.9, rng.randf_range(-8, 44))
		if int(p.x) % 7 < 2:
			continue
		crate(p, false)
	special_pallet = crate(Vector3(-43, 1.05, 18), true)
	special_pallet.name = "Missionspalette"
	# Office and social rooms.
	for x_office in [76.0, 82.0, 88.0]:
		for z_office in [14.0, 22.0]:
			box(Vector3(x_office, 0.68, z_office), Vector3(3.8, 1.3, 1.7), "wood")
			box(Vector3(x_office, 1.4, z_office - 1.9), Vector3(3.8, 0.12, 0.45), "painted_steel", false)
			box(Vector3(x_office, 1.75, z_office - 1.75), Vector3(1.6, 0.9, 0.13), "glass", false)
			box(Vector3(x_office, 0.7, z_office + 2.0), Vector3(1.4, 1.4, 1.1), "painted_steel")
	for x_cafe in [18.0, 24.0, 30.0]:
		for z_cafe in [-12.0, -6.0, 0.0]:
			box(Vector3(x_cafe, 0.9, z_cafe), Vector3(2.7, 0.16, 2.7), "wood")
			for chair_delta in [-2.1, 2.1]:
				box(Vector3(x_cafe + chair_delta, 0.55, z_cafe), Vector3(0.9, 1.1, 0.9), "painted_steel")
	for i in range(4):
		box(Vector3(-2 + i * 3.0, 1.1, 18), Vector3(2.3, 2.0, 1.7), "machine_teal", true)
		box(Vector3(-2 + i * 3.0, 1.7, 27), Vector3(2.4, 3.2, 1.9), "painted_steel")
	# Shipping yard, ramps, trailers and containers.
	for x_ship in [14.0, 37.0, 60.0]:
		box(Vector3(x_ship, 0.8, 65), Vector3(15, 1.6, 6), "concrete")
		box(Vector3(x_ship, 1.2, 67.6), Vector3(11.6, 2.5, 0.32), "shipping_grey")
		box(Vector3(x_ship, 2.0, 61.8), Vector3(4.8, 3.6, 0.2), "glass", false)
	for x_trailer in [82.0, 104.0, 126.0]:
		box(Vector3(x_trailer, 1.65, 89), Vector3(10, 3.3, 5), "shipping_grey")
		box(Vector3(x_trailer, 1.2, 91.8), Vector3(7.0, 0.7, 0.2), "#e2ba52", false)
	# Landscape and small details.
	for _i in range(18):
		var cone_x = rng.randf_range(-130, 130)
		var cone_z = rng.randf_range(108, 114)
		box(Vector3(cone_x, 0.45, cone_z), Vector3(0.75, 0.9, 0.75), "#e7973a")
	for _j in range(25):
		var shrub_x = rng.randf_range(-145, 145)
		var shrub_z = rng.randf_range(111, 117)
		box(Vector3(shrub_x, 0.27, shrub_z), Vector3(1.1, 0.54, 0.8), "#65705e", false)
	# Streetlights and hall lighting.
	for x_light in [-138.0, -67.0, 1.0, 70.0, 139.0]:
		for z_light in [13.0, 104.0]:
			_streetlight(Vector3(x_light, 0, z_light))
	for b in BLOCKS:
		for i in [-1, 1]:
			var omni = OmniLight3D.new()
			omni.position = Vector3(float(b.x) + float(i) * float(b.w) * 0.22, 9.5, float(b.z))
			omni.omni_range = 24
			omni.light_energy = 0.95
			omni.light_color = Color("#ffe4ae")
			add_child(omni)
			flicker_lights.append(omni)
	# Interaction nodes.
	interactive("timeclock", "EINSTEMPELN", Vector3(82, 0, 18), "#58c0b4")
	interactive("barcode", "PALETTENSCAN", Vector3(-43, 0, 18), "#f6b353")
	interactive("terminal", "LIEFERDATEN", Vector3(79, 0, 18), "#85c4ff")
	interactive("override", "SICHERHEITSSCHALTER", Vector3(-44, 0, -54), "#fb6e6e")
	interactive("line_a", "NOTHALT LINIE A", Vector3(-109, 0, -54), "#ef4e54")
	interactive("line_b", "NOTHALT LINIE B", Vector3(-44, 0, -54), "#ef4e54")
	interactive("line_c", "NOTHALT LINIE C", Vector3(28, 0, -54), "#ef4e54")
	interactive("blueprint", "BLAUE AKTE", Vector3(-34, 0, 7), "#6cb8ec")
	interactive("final_terminal", "ZENTRALRECHNER", Vector3(82, 0, 20), "#f09c60")
	interactive("ending_a", "NOTAUSGANG WEST", Vector3(-137, 0, 27), "#65bd9a")
	interactive("ending_b", "FLUCHTWEG NORD", Vector3(10, 0, 106), "#ffc166")
	interactive("challenge", "STAPLER-SLALOM", Vector3(112, 0, 92), "#f2cd5c")
	interactive("secret", "GEHEIME TÜR", Vector3(128, 0, -92), "#b579f3")
	interactive("vending", "GETRÄNKEAUTOMAT", Vector3(24, 0, -8), "#e7a0af")
	interactive("repair", "FAHRZEUGWERKSTATT", Vector3(3, 0, 22), "#85d8ce")
	# Signage.
	sign_text("KARTON EU IV", Vector3(0, 14, 117), 1.9, Color("#efd598"))
	sign_text("TUCHMACHERALLEE \u2502 WERKSZUFAHRT \u2502 20 km/h", Vector3(-2, 4, 112), 0.6)
	sign_text("TEXTURE OVERHAUL \u2502 LAYOUT NACH LOGISTIK-FOOTPRINT", Vector3(-77, 4, -84), 0.28, Color("#f1d4a9"))

func _streetlight(p: Vector3) -> void:
	box(p + Vector3.UP * 4.9, Vector3(0.18, 9.8, 0.18), "painted_steel")
	box(p + Vector3(0, 9.7, -1.9), Vector3(0.18, 0.12, 3.8), "painted_steel", false)
	var glow = OmniLight3D.new()
	glow.position = p + Vector3(0, 9.3, -3.5)
	glow.omni_range = 21
	glow.light_energy = 0.4
	glow.light_color = Color("#f6d9a0")
	add_child(glow)

func _rack(p: Vector3) -> void:
	for ix in [-1, 1]:
		for iz in [-1, 1]:
			box(p + Vector3(ix * 4.7, 4.0, iz * 1.55), Vector3(0.22, 8, 0.22), "painted_steel")
	for h in [1.1, 3.8, 6.6]:
		box(p + Vector3(0, h, 0), Vector3(10, 0.19, 3.5), "painted_steel")
		for i in [-3.1, 0, 3.1]:
			box(p + Vector3(i, h + 0.72, 0), Vector3(2.5, 1.3, 2.7), "cardboard", false)
	box(p + Vector3(0, 8.1, 0), Vector3(10, 0.12, 3.5), "hazard", false)

func _conveyor(p: Vector3, width: float) -> void:
	box(p + Vector3(0, 0.57, 0), Vector3(width, 0.4, 3.0), "painted_steel")
	for k in range(int(width / 2.0)):
		var roller = box(p + Vector3(-width / 2.0 + 1.2 + k * 2.0, 0.89, 0), Vector3(0.22, 0.11, 2.6), "galvanized", false)
		machines.append(roller)
	for k in range(5):
		var item = box(p + Vector3(-width / 2.0 + k * 8.0, 1.6, 0), Vector3(2.25, 1.1, 1.95), "cardboard", false)
		item.set_meta("belt_min", p.x - width / 2.0)
		item.set_meta("belt_max", p.x + width / 2.0)
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
	shape.size = Vector3(1.75, 1.7, 1.75) if important else Vector3(1.1, 1.1, 1.1)
	c.shape = shape
	b.add_child(c)
	var mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = shape.size
	mesh.mesh = bm
	mesh.material_override = _style_material("cardboard")
	b.add_child(mesh)
	var tape = MeshInstance3D.new()
	var tape_mesh = BoxMesh.new()
	tape_mesh.size = Vector3(shape.size.x * 0.22, shape.size.y + 0.02, shape.size.z + 0.04)
	tape.mesh = tape_mesh
	tape.material_override = _style_material("hazard")
	b.add_child(tape)
	if important:
		var label_plate = MeshInstance3D.new()
		var plate_mesh = BoxMesh.new()
		plate_mesh.size = Vector3(1.0, 0.5, 0.06)
		label_plate.mesh = plate_mesh
		label_plate.material_override = _style_material("office_white")
		label_plate.position = Vector3(0, 0.25, shape.size.z * 0.5 + 0.01)
		b.add_child(label_plate)
		var label = Label3D.new()
		label.text = "KEU-404 / EXPRESS"
		label.position = Vector3(0, 0.26, shape.size.z * 0.5 + 0.06)
		label.font_size = 40
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.add_child(label)
	add_child(b)
	pallets.append(b)
	return b

func interactive(id: String, title: String, p: Vector3, tint: String) -> void:
	var root = box(p + Vector3(0, 1.15, 0), Vector3(1.5, 2.3, 0.8), "painted_steel")
	root.name = id
	box(Vector3(0, 0.42, -0.45), Vector3(1.1, 0.92, 0.12), tint, false, root)
	var label = Label3D.new()
	label.text = title
	label.pixel_size = 0.005
	label.font_size = 38
	label.position = Vector3(0, 0.65, -0.58)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	objects.append({"id": id, "name": title, "node": root, "position": p + Vector3.UP})

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
	for i in range(flicker_lights.size()):
		if i % 8 == 0:
			flicker_lights[i].light_energy = 0.68 + sin(t * 12 + i) * 0.06

func setup_navigation() -> void:
	var space = get_world_3d().direct_space_state
	var width = 41
	var depth = 31
	var next_id = 0
	for iz in range(depth):
		for ix in range(width):
			var pos = Vector3(-140 + ix * 7.0, 1.45, -105 + iz * 7.0)
			var probe = PhysicsPointQueryParameters3D.new()
			probe.position = pos
			probe.collision_mask = 1
			if space.intersect_point(probe).size() > 0:
				continue
			nav.add_point(next_id, pos)
			nav_positions[Vector2i(ix, iz)] = next_id
			next_id += 1
	for key in nav_positions:
		var id: int = nav_positions[key]
		for delta_pos in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var neighbor: Vector2i = key + delta_pos
			if not nav_positions.has(neighbor):
				continue
			var other: int = nav_positions[neighbor]
			var query = PhysicsRayQueryParameters3D.create(nav.get_point_position(id), nav.get_point_position(other), 1)
			if space.intersect_ray(query).is_empty():
				nav.connect_points(id, other)
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
	var route = nav.get_point_path(a, b)
	if route.size() == 0:
		return PackedVector3Array([to])
	return route

func get_blocks() -> Array:
	return BLOCKS
