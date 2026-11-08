extends StaticBody3D
## Bjørn, the car dealer. Talk to him (E) to get the Tike or the motorbike.

var npc_name := "Bjørn"
var head: Node3D
var arm_r: Node3D
var _wave := 0.0
var _t := 0.0

func setup() -> void:
	collision_layer = Game.L_WORLD
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	var suit := Color(0.32, 0.30, 0.28)
	var skin := Color(0.70, 0.52, 0.40)
	var body := Node3D.new()
	add_child(body)
	# body faces +Z (out of the showroom, towards customers)
	for p in [[Vector3(0.15, 0.85, 0.16), Vector3(0.1, 0.43, 0), suit.darkened(0.2)],
			  [Vector3(0.15, 0.85, 0.16), Vector3(-0.1, 0.43, 0), suit.darkened(0.2)],
			  [Vector3(0.13, 0.08, 0.26), Vector3(0.1, 0.04, 0.05), Color(0.12, 0.08, 0.05)],
			  [Vector3(0.13, 0.08, 0.26), Vector3(-0.1, 0.04, 0.05), Color(0.12, 0.08, 0.05)],
			  [Vector3(0.44, 0.62, 0.26), Vector3(0, 1.17, 0), suit],                     # jacket (a bit of a belly)
			  [Vector3(0.36, 0.25, 0.08), Vector3(0, 1.0, 0.12), suit],
			  [Vector3(0.12, 0.30, 0.01), Vector3(0, 1.32, 0.135), Color(0.85, 0.75, 0.55)],  # yellow shirt
			  [Vector3(0.05, 0.28, 0.012), Vector3(0, 1.30, 0.142), Color(0.15, 0.35, 0.20)], # green tie
			  [Vector3(0.10, 0.62, 0.10), Vector3(0.27, 1.17, 0), suit]]:                  # left arm
		_box(body, p[0], p[1], p[2])
	arm_r = Node3D.new()
	arm_r.position = Vector3(-0.27, 1.46, 0)
	body.add_child(arm_r)
	_box(arm_r, Vector3(0.10, 0.62, 0.10), Vector3(0, -0.29, 0), suit)
	_box(arm_r, Vector3(0.09, 0.1, 0.09), Vector3(0, -0.64, 0), skin)
	_box(body, Vector3(0.09, 0.1, 0.09), Vector3(0.27, 0.83, 0), skin)
	head = Node3D.new()
	head.position = Vector3(0, 1.5, 0)
	body.add_child(head)
	_box(head, Vector3(0.10, 0.08, 0.10), Vector3(0, 0.02, 0), skin)
	_box(head, Vector3(0.23, 0.26, 0.24), Vector3(0, 0.18, 0), skin)
	_box(head, Vector3(0.25, 0.05, 0.26), Vector3(0, 0.32, 0), Color(0.55, 0.55, 0.52))   # grey hair
	_box(head, Vector3(0.17, 0.05, 0.03), Vector3(0, 0.12, 0.125), Color(0.45, 0.43, 0.40))  # moustache
	for x in [0.05, -0.05]:
		_box(head, Vector3(0.035, 0.025, 0.01), Vector3(x, 0.2, 0.122), Color(0.05, 0.05, 0.05))
	_box(head, Vector3(0.20, 0.02, 0.05), Vector3(0, 0.205, 0.13), Color(0.1, 0.1, 0.1))  # glasses frame
	var tag := Label3D.new()
	tag.text = npc_name + "\nCar dealer"
	tag.font_size = 40
	tag.pixel_size = 0.004
	tag.position = Vector3(0, 2.2, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1, 0.95, 0.7)
	tag.outline_size = 8
	add_child(tag)

func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)

func wave() -> void:
	_wave = 1.6

func _process(dt: float) -> void:
	_t += dt
	var pl = Game.player
	if pl and pl.global_position.distance_to(global_position) < 12.0:
		var local := to_local(pl.global_position)
		var yaw := clampf(atan2(local.x, local.z), -1.0, 1.0)
		head.rotation.y = lerp_angle(head.rotation.y, yaw, minf(dt * 4.0, 1.0))
	else:
		head.rotation.y = lerp_angle(head.rotation.y, sin(_t * 0.4) * 0.5, minf(dt * 2.0, 1.0))
	_wave = maxf(_wave - dt, 0.0)
	if _wave > 0.0:
		arm_r.rotation = Vector3(0, 0, -2.6 + sin(_t * 12.0) * 0.35)
	else:
		arm_r.rotation = arm_r.rotation.lerp(Vector3.ZERO, minf(dt * 5.0, 1.0))
