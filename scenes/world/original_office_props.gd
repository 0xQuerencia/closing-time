class_name OriginalOfficeProps
extends RefCounted

var materials: Dictionary = {}

func make(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind
	var beige := Color("#a49c85")
	var dark := Color("#333735")
	var wood := Color("#765c43")
	var metal := Color("#565b59")
	match kind:
		"desk":
			_box(root, Vector3(1.55, .065, .78), Vector3(0,.735,0), wood)
			_box(root, Vector3(1.45,.27,.035), Vector3(0,.49,-.34), wood.darkened(.18))
			for x in [-.69,.69]:
				_box(root, Vector3(.07,.70,.70), Vector3(x,.35,0), wood.darkened(.12))
			_box(root, Vector3(.36,.52,.62), Vector3(-.46,.34,0), wood)
			for y in [.22,.43,.60]:
				_box(root, Vector3(.32,.17,.025), Vector3(-.46,y,.32), wood.lightened(.07))
				_box(root, Vector3(.11,.018,.03), Vector3(-.46,y,.35), metal)
		"chair":
			_box(root, Vector3(.43,.09,.42), Vector3(0,.47,0), dark)
			_box(root, Vector3(.41,.37,.085), Vector3(0,.73,-.19), dark)
			_box(root, Vector3(.045,.31,.06), Vector3(0,.52,-.19), metal)
			_cylinder(root,.035,.045,.37,Vector3(0,.23,0),metal)
			for i in range(5):
				var arm := _box(root,Vector3(.055,.04,.29),Vector3.ZERO,metal)
				arm.rotation.y = TAU * float(i) / 5.0
				arm.position = Vector3(sin(arm.rotation.y)*.12,.065,cos(arm.rotation.y)*.12)
				_cylinder(root,.035,.035,.045,arm.position + Vector3(sin(arm.rotation.y)*.12,-.035,cos(arm.rotation.y)*.12),dark)
		"crt":
			_box(root, Vector3(.36,.30,.34), Vector3(0,.20,-.035), beige.darkened(.12))
			_box(root, Vector3(.39,.32,.08), Vector3(0,.20,.13), beige)
			_box(root, Vector3(.32,.235,.018), Vector3(0,.212,.177), Color("#202a29"))
			var screen := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(.29,.205)
			screen.mesh = quad
			screen.name = "OriginalCRTGlass"
			screen.position = Vector3(0,.212,.191)
			screen.material_override = _material(Color("#37423c"))
			root.add_child(screen)
			_box(root, Vector3(.19,.045,.17), Vector3(0,.023,0), beige.darkened(.13))
			_box(root, Vector3(.013,.009,.007), Vector3(.157,.071,.18), Color("#827e43"))
			for i in range(6):
				_box(root,Vector3(.012,.12,.008),Vector3(-.12 + i*.045,.23,-.208),dark)
		"computer":
			_box(root,Vector3(.19,.38,.38),Vector3(0,.19,0),beige)
			for y in [.27,.32]:
				_box(root,Vector3(.15,.035,.007),Vector3(0,y,.194),dark)
			_box(root,Vector3(.026,.018,.01),Vector3(.052,.065,.195),Color("#727844"))
		"keyboard":
			_box(root,Vector3(.40,.025,.15),Vector3(0,.018,0),beige)
			for row in range(4):
				for column in range(13):
					_box(root,Vector3(.022,.013,.024),Vector3(-.18 + column*.029,.036,-.055 + row*.029),beige.lightened(.10))
			_box(root,Vector3(.15,.013,.021),Vector3(-.035,.036,.060),beige.lightened(.10))
		"phone":
			_box(root,Vector3(.21,.055,.17),Vector3(0,.028,0),dark)
			_box(root,Vector3(.045,.065,.155),Vector3(-.073,.065,0),metal)
			for z in range(4):
				for x in range(3):
					_box(root,Vector3(.021,.008,.018),Vector3(-.015+x*.027,.06,-.033+z*.027),beige.darkened(.13))
			_box(root,Vector3(.078,.008,.022),Vector3(.012,.06,-.067),Color("#68705d"))
		"mug":
			_cylinder(root,.047,.041,.093,Vector3(0,.047,0),Color("#b1a88c"))
			_cylinder(root,.038,.038,.004,Vector3(0,.095,0),Color("#32291e"))
			for y in [.028,.073]:
				_box(root,Vector3(.037,.013,.018),Vector3(.054,y,0),beige)
			_box(root,Vector3(.013,.047,.018),Vector3(.073,.051,0),beige)
		"crate":
			var green := Color("#52634d")
			_box(root,Vector3(.54,.04,.36),Vector3(0,.02,0),green)
			for x in [-.25,.25]:
				_box(root,Vector3(.04,.21,.36),Vector3(x,.125,0),green)
			for z in [-.16,.16]:
				_box(root,Vector3(.54,.21,.04),Vector3(0,.125,z),green)
			for x in [-.16,0,.16]:
				for z in [-.08,.08]:
					_cylinder(root,.042,.047,.23,Vector3(x,.155,z),Color("#757b60"))
					_cylinder(root,.019,.022,.08,Vector3(x,.30,z),Color("#a29c7b"))
		"extinguisher":
			var red := Color("#a23a31")
			_cylinder(root,.08,.08,.35,Vector3(0,.19,0),red)
			_cylinder(root,.045,.07,.055,Vector3(0,.39,0),red)
			_box(root,Vector3(.14,.025,.045),Vector3(0,.43,0),dark)
			_box(root,Vector3(.065,.09,.009),Vector3(0,.22,.08),beige)
			_box(root,Vector3(.024,.25,.026),Vector3(.09,.255,0),dark)
		"camera":
			_box(root,Vector3(.12,.115,.23),Vector3(0,0,0),beige)
			_box(root,Vector3(.135,.025,.25),Vector3(0,.07,.025),beige.darkened(.10))
			_box(root,Vector3(.087,.087,.018),Vector3(0,0,.124),dark)
			var lens := _cylinder(root,.031,.031,.018,Vector3(0,0,.14),Color("#45504c"))
			lens.rotation.x = PI/2
			_box(root,Vector3(.035,.11,.045),Vector3(0,.10,-.08),metal)
	return root

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key):
		return materials[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .89
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var image := Image.create(32,32,false,Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	for y in range(32):
		for x in range(32):
			var grain := rng.randf_range(.82,1.0)
			image.set_pixel(x,y,Color(grain,grain,grain))
	m.albedo_texture = ImageTexture.create_from_image(image)
	materials[key] = m
	return m

func _box(root: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos
	part.material_override = _material(color)
	root.add_child(part)
	return part

func _cylinder(root: Node3D, top: float, bottom: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 0
	part.mesh = mesh
	part.position = pos
	part.material_override = _material(color)
	root.add_child(part)
	return part
