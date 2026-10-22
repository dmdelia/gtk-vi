extends Node3D
## GTK: VI humanoid visual rig. Soft continuous surfaces, anatomical proportions,
## joint-driven walk/run/idle animation and bitmap-based skin/clothing materials.
## No box/sphere construction for the head, torso or main limbs.
const V = preload("res://scripts/visuals.gd")

var profession = "worker"
var appearance_seed = 0
var cloth: Material
var trouser: Material
var skin: Material
var hair_mat: Material
var shoe_mat: Material
var trim: Material
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var head_pivot: Node3D
var torso_root: Node3D
var gait_time = 0.0
var walk_amount = 0.0
var is_sitting = false

func configure(job: String, custom_seed: int = 0) -> void:
	profession = job
	appearance_seed = absi(custom_seed)

func _ready() -> void:
	var skins = [Color("#dbb399"), Color("#ae8063"), Color("#80543d"), Color("#edc8aa"), Color("#b99277")]
	var hairs = [Color("#242222"), Color("#352719"), Color("#54402c"), Color("#6a5c49"), Color("#292a30")]
	var shirts = [Color("#c99935"), Color("#567f8c"), Color("#c18555"), Color("#648274"), Color("#9a6c56")]
	var tone: Color = skins[appearance_seed % skins.size()]
	var hair_tone: Color = hairs[int(appearance_seed / 3) % hairs.size()]
	var shirt: Color = shirts[int(appearance_seed / 5) % shirts.size()]
	if profession == "guard":
		shirt = Color("#293b50")
	elif profession == "office":
		shirt = Color("#a9b4bf") if appearance_seed % 2 == 0 else Color("#788c9e")
	elif profession == "player":
		shirt = Color("#405c73")
	cloth = V.material("fabric", shirt)
	trouser = V.material("fabric", Color("#2d343e") if profession == "guard" else Color("#444b51"))
	skin = V.material("skin", tone)
	hair_mat = V.material("hair", hair_tone)
	shoe_mat = V.material("rubber", Color("#2c3033"))
	trim = V.material("fabric", Color("#c1b7a3"))
	_build_body()
	_build_head()
	_build_arms()
	_build_legs()
	_build_costume()

func _new_pivot(parent: Node3D, name_text: String, location: Vector3) -> Node3D:
	var pivot = Node3D.new()
	pivot.name = name_text
	pivot.position = location
	parent.add_child(pivot)
	return pivot

func _ring(y: float, x: float, z: float, cx = 0.0, cz = 0.0) -> Dictionary:
	return {"y": y, "rx": x, "rz": z, "cx": cx, "cz": cz}

func _loft(parent: Node3D, rows: Array, mat: Material, sections = 20, cap = true) -> MeshInstance3D:
	# A skinned-looking sculpted form made from smooth elliptical cross-sections.
	# Vertex normals are smoothed across each seam for an uninterrupted silhouette.
	var vertices = PackedVector3Array()
	var uv = PackedVector2Array()
	var indices = PackedInt32Array()
	for j in range(rows.size()):
		var r: Dictionary = rows[j]
		for i in range(sections + 1):
			var theta = TAU * float(i) / float(sections)
			vertices.append(Vector3(float(r["cx"]) + sin(theta) * float(r["rx"]), float(r["y"]), float(r["cz"]) + cos(theta) * float(r["rz"])))
			uv.append(Vector2(float(i) / float(sections), float(j) / maxf(1.0, float(rows.size()-1))))
	for j in range(rows.size() - 1):
		for i in range(sections):
			var a = j * (sections+1)+i
			var b = a+sections+1
			indices.append_array(PackedInt32Array([a,a+1,b, a+1,b+1,b]))
	if cap:
		var lower = vertices.size()
		var lo: Dictionary = rows[0]
		var hi: Dictionary = rows[rows.size()-1]
		vertices.append(Vector3(float(lo["cx"]), float(lo["y"]), float(lo["cz"])))
		uv.append(Vector2(.5,.5))
		var upper = vertices.size()
		vertices.append(Vector3(float(hi["cx"]), float(hi["y"]), float(hi["cz"])))
		uv.append(Vector2(.5,.5))
		for i in range(sections):
			indices.append_array(PackedInt32Array([lower,i+1,i]))
			var a = (rows.size()-1)*(sections+1)+i
			indices.append_array(PackedInt32Array([upper,a,a+1]))
	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	mesh_array[Mesh.ARRAY_VERTEX] = vertices
	mesh_array[Mesh.ARRAY_TEX_UV] = uv
	mesh_array[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
	var surface = SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_normals()
	var smoothed = surface.commit()
	var node = MeshInstance3D.new()
	node.mesh = smoothed
	node.material_override = mat
	parent.add_child(node)
	return node

func _build_body() -> void:
	torso_root = _new_pivot(self, "SpineAndTorso", Vector3.ZERO)
	_loft(torso_root, [
		_ring(.92,.248,.156), _ring(1.04,.275,.170),
		_ring(1.19,.278,.175), _ring(1.35,.296,.191),
		_ring(1.49,.349,.196), _ring(1.62,.390,.202),
		_ring(1.72,.361,.187), _ring(1.81,.225,.138),
		_ring(1.86,.132,.107)
	], cloth, 24)
	# Neck fits the head instead of intersecting an oversized sphere.
	_loft(torso_root, [_ring(1.82,.092,.088),_ring(1.94,.09,.086),_ring(1.972,.10,.086)], skin, 16)
	# Waist/belt topology, small layered jacket hem.
	_loft(torso_root, [_ring(.925,.255,.165),_ring(.96,.262,.165),_ring(.983,.266,.171)], trouser, 22)

func _build_head() -> void:
	head_pivot = _new_pivot(self, "HeadNeck", Vector3(0,1.95,0))
	# Anatomical head: chin narrows, cheekbones widen, temple rounds into scalp.
	# Relative coordinates. Front of character is negative Z.
	_loft(head_pivot, [
		_ring(-.07,.075,.079,0,-.015),
		_ring(-.045,.105,.113,0,-.009),
		_ring(.01,.135,.135,0,-.010),
		_ring(.085,.171,.159,0,-.008),
		_ring(.152,.179,.169,0,.004),
		_ring(.216,.166,.158,0,.010),
		_ring(.272,.128,.124,0,.010),
		_ring(.306,.066,.063,0,.015),
		_ring(.314,.004,.004,0,.015)
	], skin, 26)
	# Ear shell and inner recess, small and recessed against skull.
	for side in [-1,1]:
		var sx = float(side)
		_loft(head_pivot, [
			_ring(.066,.014,.035,sx*.169,-.004),
			_ring(.11,.033,.049,sx*.179,-.006),
			_ring(.16,.031,.037,sx*.176,-.003),
			_ring(.181,.008,.015,sx*.163,0)
		], skin, 12)
		# Eyebrows + lids hug the curved facial surface, no protruding googly eyes.
		V.sphere(head_pivot,Vector3(sx*.077,.152,-.145),Vector3(.118,.058,.028),V.plain(Color("#e4d8ca"),0,.55),16)
		V.sphere(head_pivot,Vector3(sx*.077,.150,-.167),Vector3(.041,.044,.013),V.plain(Color("#55493d"),0,.42),16)
		V.sphere(head_pivot,Vector3(sx*.077,.150,-.179),Vector3(.019,.022,.009),V.plain(Color("#1c1d20"),0,.28),12)
		V.pipe_between(head_pivot,Vector3(sx*.028,.202,-.148),Vector3(sx*.124,.211,-.139),.011,hair_mat,7)
	# Sculpted wedge-like nose and philtrum, mouth close to skin surface.
	_loft(head_pivot,[_ring(.052,.037,.030,0,-.148),_ring(.090,.045,.053,0,-.145),_ring(.115,.035,.027,0,-.144)],skin,12)
	V.pipe_between(head_pivot,Vector3(-.042,-.001,-.115),Vector3(.042,-.001,-.115),.007,V.plain(Color("#855a54")),9)
	# Hair forms a contoured scalp cap rather than a top-of-head sphere.
	_loft(head_pivot, [
		_ring(.226,.165,.162,0,.015),
		_ring(.258,.157,.159,0,.021),
		_ring(.302,.117,.121,0,.021),
		_ring(.331,.062,.066,0,.020),
		_ring(.335,.004,.005,0,.022)
	], hair_mat, 22)
	for side in [-1,1]:
		var sx=float(side)
		V.pipe_between(head_pivot,Vector3(sx*.133,.263,-.067),Vector3(sx*.151,.177,-.056),.021,hair_mat,7)

func _arm(side: float) -> void:
	var pivot = _new_pivot(self,"ShoulderL" if side < 0 else "ShoulderR",Vector3(side*.399,1.67,0))
	var cuff_color = V.material("fabric",Color("#405361")) if profession == "guard" else cloth
	_loft(pivot, [
		_ring(-.422,.115,.115,side*.06,-.015),
		_ring(-.354,.128,.128,side*.058,-.012),
		_ring(-.22,.149,.135,side*.049,0),
		_ring(-.07,.170,.16,side*.023,0),
		_ring(.027,.151,.139,0,0),
		_ring(.074,.07,.08,0,0)
	],cloth,16)
	var elbow = _new_pivot(pivot,"ElbowL" if side < 0 else "ElbowR",Vector3(side*.059,-.408,-.014))
	_loft(elbow, [
		_ring(-.425,.079,.075),
		_ring(-.367,.105,.092),
		_ring(-.18,.119,.108),
		_ring(.016,.130,.126)
	],cuff_color,16)
	_loft(elbow, [_ring(-.47,.068,.056),_ring(-.435,.083,.069),_ring(-.41,.073,.066)],skin,12)
	# Fingers shaped as tapered small skin geometry, not a fist sphere.
	for i in range(4):
		var x = (float(i)-1.5)*.033
		_loft(elbow, [_ring(-.505,.011,.013,x,-.034),_ring(-.476,.012,.012,x,-.034),_ring(-.447,.013,.013,x,-.034)],skin,8)
	if side < 0:
		shoulder_l=pivot
		elbow_l=elbow
	else:
		shoulder_r=pivot
		elbow_r=elbow

func _build_arms() -> void:
	_arm(-1.0)
	_arm(1.0)

func _leg(side: float) -> void:
	var hip = _new_pivot(self,"ThighL" if side < 0 else "ThighR",Vector3(side*.164,.951,0))
	_loft(hip, [
		_ring(-.515,.116,.118,side*.008,-.011),
		_ring(-.465,.130,.126,side*.005,-.012),
		_ring(-.31,.151,.147,0,.0),
		_ring(-.1,.171,.164,0,.005),
		_ring(.023,.157,.151,0,0)
	],trouser,18)
	var knee = _new_pivot(hip,"KneeL" if side < 0 else "KneeR",Vector3(side*.008,-.502,-.012))
	_loft(knee, [
		_ring(-.368,.093,.097,0,-.008),
		_ring(-.31,.111,.114,0,-.008),
		_ring(-.15,.127,.125,0,0),
		_ring(.013,.137,.133)
	],trouser,16)
	# Anatomical shoe: low sculpted shape with toe extending forward.
	_loft(knee, [
		_ring(-.405,.112,.219,0,-.102),
		_ring(-.37,.121,.237,0,-.103),
		_ring(-.308,.109,.205,0,-.077)
	],shoe_mat,18)
	if side<0:
		hip_l=hip
		knee_l=knee
	else:
		hip_r=hip
		knee_r=knee

func _build_legs() -> void:
	_leg(-1.0)
	_leg(1.0)

func _build_costume() -> void:
	if profession == "worker":
		# Reflective safety vest runs across torso, plus a fabric collar.
		V.pipe_between(torso_root,Vector3(-.26,1.61,-.13),Vector3(-.18,1.08,-.17),.023,trim,7)
		V.pipe_between(torso_root,Vector3(.26,1.61,-.13),Vector3(.18,1.08,-.17),.023,trim,7)
		V.pipe_between(torso_root,Vector3(-.24,1.18,-.177),Vector3(.24,1.18,-.177),.023,trim,7)
	elif profession == "office":
		# Collar and narrow tie, flattened against the chest.
		V.pipe_between(torso_root,Vector3(0,1.75,-.148),Vector3(0,1.39,-.209),.022,V.material("fabric",Color("#344557")),8)
	elif profession == "guard":
		# Belt and metal badge anchored to the upper torso.
		V.pipe_between(torso_root,Vector3(-.265,1.05,-.13),Vector3(.265,1.05,-.13),.024,V.material("rubber",Color("#24282c")),8)
		V.sphere(torso_root,Vector3(-.19,1.55,-.198),Vector3(.105,.13,.025),V.material("steel",Color("#ccd2d1")),12)
	elif profession == "player":
		# Hoodie zipper and a small left chest pocket.
		V.pipe_between(torso_root,Vector3(0,1.76,-.135),Vector3(0,1.12,-.177),.012,V.material("steel",Color("#a4aab3")),7)
		V.pipe_between(torso_root,Vector3(-.26,1.22,-.167),Vector3(-.10,1.22,-.187),.014,trim,7)

func set_pose(speed: float, moving: bool, sprinting = false, crouching = false, driving = false, dt = 0.016) -> void:
	var target = clampf(speed / 7.5,0.0,1.0) if moving else 0.0
	walk_amount = move_toward(walk_amount,target,dt*5.5)
	gait_time += speed * dt * (.58 if sprinting else .47)
	var sway = sin(gait_time*1.75) * walk_amount
	var lift_l = maxf(0.0,cos(gait_time*1.75))*walk_amount
	var lift_r = maxf(0.0,-cos(gait_time*1.75))*walk_amount
	var stride = .58 if sprinting else .40
	hip_l.rotation.x = -sway*stride
	hip_r.rotation.x = sway*stride
	knee_l.rotation.x = lift_l*.38
	knee_r.rotation.x = lift_r*.38
	shoulder_l.rotation.x = sway*.32
	shoulder_r.rotation.x = -sway*.32
	elbow_l.rotation.x = -.08 - walk_amount*.14
	elbow_r.rotation.x = -.08 - walk_amount*.14
	var breathing = sin(Time.get_ticks_msec()*.0024)*.008
	torso_root.scale.y = 1.0 + breathing
	rotation.z = -sway*.018
	position.y = sin(gait_time*3.5)*.012*walk_amount
	head_pivot.rotation.x = sin(gait_time*1.7)*walk_amount*.035
	if crouching:
		rotation.x = -.14
		position.y -= .14
	else:
		rotation.x = 0.0
	if driving:
		position.y = 0.0
		walk_amount = 0.0
