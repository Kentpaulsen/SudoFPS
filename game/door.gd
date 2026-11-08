extends StaticBody3D
## A hinged door leaf. E opens/closes it. Closed doors block players and zombies alike.

var open := false
var hinge_sign := 1.0          # which way it swings
var _t := 0.0
var _target := 0.0
var leaf_w := 1.0

## width/height of this leaf; hinge at the node origin, leaf extends along +X (or -X if hinge_sign < 0).
func setup(w: float, h: float, side: float, wood: Color) -> void:
	leaf_w = w
	hinge_sign = side
	collision_layer = Game.L_WORLD
	collision_mask = 0
	var m := StandardMaterial3D.new()
	m.albedo_color = wood
	m.roughness = 0.7
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w - 0.02, h - 0.02, 0.07)
	bm.material = m
	mi.mesh = bm
	mi.position = Vector3(side * w / 2.0, h / 2.0, 0)
	add_child(mi)
	for p in [Vector3(side * w * 0.5, h * 0.72, 0), Vector3(side * w * 0.5, h * 0.25, 0)]:   # panels
		var pm := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(w * 0.7, h * 0.3, 0.085)
		var dm := StandardMaterial3D.new()
		dm.albedo_color = wood.darkened(0.25)
		pb.material = dm
		pm.mesh = pb
		pm.position = p
		add_child(pm)
	var hm := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.12, 0.03, 0.14)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.75, 0.6, 0.2)
	gold.metallic = 0.8
	hb.material = gold
	hm.mesh = hb
	hm.position = Vector3(side * (w - 0.1), 1.0, 0)
	add_child(hm)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w - 0.04, h - 0.04, 0.08)
	cs.shape = box
	cs.position = mi.position
	add_child(cs)

func centre() -> Vector3:
	return global_transform * Vector3(hinge_sign * leaf_w / 2.0, 1.0, 0)

func toggle() -> void:
	open = not open
	_target = 1.0 if open else 0.0
	Sfx.play3d("chop", centre(), -4.0, 0.7 if open else 0.55)
	Game.make_noise(centre(), 6.0)
	set_process(true)

func _ready() -> void:
	set_process(false)

func _process(dt: float) -> void:
	_t = move_toward(_t, _target, dt * 2.5)
	# swing inwards (towards -Z, into the building)
	rotation.y = hinge_sign * smoothstep(0.0, 1.0, _t) * deg_to_rad(100)
	if is_equal_approx(_t, _target):
		set_process(false)
