extends Node3D
## Helicopter hangar. A red button inside, next to the big front opening, slides the two
## roof halves apart (and back) so the helicopter can climb straight out.
## The node sits in world.doors, so the player's E-interaction finds the button like a door.

const W := 11.0          # half width (x)
const D := 12.0          # half depth (z), front is +Z
const H := 6.5           # wall height
const T := 0.3           # wall thickness
const OX := 8.0          # roof opening half width
const OZ := 9.0          # roof opening half depth
const GAP := 4.5         # front opening half width
const GAP_H := 5.0
const SLIDE := 8.4       # how far each roof half travels outwards
const SPEED := 0.28      # 0..1 per second (about 3.5 s to open)

var open := false
var _t := 0.0
var _target := 0.0
var panels: Array = []    # [body, side]
var button_local := Vector3(GAP + 1.0, 1.35, D - T - 0.05)
var button_cap: MeshInstance3D
var beacon: OmniLight3D
var beacon_mesh: MeshInstance3D
var motor: AudioStreamPlayer3D
var _blink := 0.0

func _mat(c: Color, rough := 0.8, metal := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material, body: CollisionObject3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.visibility_range_end = 300.0
	parent.add_child(mi)
	if body:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos - (body.position if body.get_parent() == parent else Vector3.ZERO)
		body.add_child(cs)
	return mi

func build() -> void:
	var wall := _mat(Color(0.33, 0.38, 0.30), 0.85, 0.2)
	var rib := _mat(Color(0.25, 0.29, 0.23), 0.8, 0.3)
	var roof := _mat(Color(0.22, 0.24, 0.24), 0.7, 0.4)
	var steel := _mat(Color(0.40, 0.41, 0.42), 0.5, 0.7)
	var concrete := _mat(Color(0.55, 0.55, 0.53), 0.95)
	var yellow := _mat(Color(0.95, 0.78, 0.10), 0.6, 0.0, true)
	var white := _mat(Color(0.92, 0.92, 0.90), 0.6, 0.0, true)
	var sb := StaticBody3D.new()
	sb.collision_layer = Game.L_WORLD
	sb.collision_mask = 0
	add_child(sb)
	# floor slab with a helipad H and a ring
	_box(self, Vector3(W * 2.0, 0.06, D * 2.0), Vector3(0, 0.01, 0), concrete)
	_box(self, Vector3(0.7, 0.012, 6.0), Vector3(-1.6, 0.05, 0), white)
	_box(self, Vector3(0.7, 0.012, 6.0), Vector3(1.6, 0.05, 0), white)
	_box(self, Vector3(2.5, 0.012, 0.7), Vector3(0, 0.05, 0), white)
	for k in 32:
		var a := k * TAU / 32.0
		var seg := _box(self, Vector3(1.2, 0.01, 0.35), Vector3(sin(a) * 5.2, 0.045, cos(a) * 5.2), yellow)
		seg.rotation.y = a
	# walls
	_box(self, Vector3(W * 2.0, H, T), Vector3(0, H / 2.0, -D + T / 2.0), wall, sb)
	for s in [-1.0, 1.0]:
		_box(self, Vector3(T, H, D * 2.0), Vector3(s * (W - T / 2.0), H / 2.0, 0), wall, sb)
		var w := W - GAP
		_box(self, Vector3(w, H, T), Vector3(s * (GAP + w / 2.0), H / 2.0, D - T / 2.0), wall, sb)
		# yellow-black edge on the opening
		for k in 5:
			_box(self, Vector3(0.06, 0.5, 0.32), Vector3(s * (GAP + 0.02), 0.25 + k * 1.0, D - T / 2.0), yellow)
	_box(self, Vector3(GAP * 2.0, H - GAP_H, T), Vector3(0, GAP_H + (H - GAP_H) / 2.0, D - T / 2.0), wall, sb)
	# outside ribs so it reads as corrugated metal
	for i in 11:
		var x := -W + 1.0 + i * 2.0
		_box(self, Vector3(0.12, H, 0.1), Vector3(x, H / 2.0, -D - 0.04), rib)
	for i in 12:
		var z := -D + 1.0 + i * 2.0
		for s in [-1.0, 1.0]:
			_box(self, Vector3(0.1, H, 0.12), Vector3(s * (W + 0.04), H / 2.0, z), rib)
	# fixed roof round the opening
	var rt := 0.25
	var ry := H + rt / 2.0
	_box(self, Vector3(W * 2.0, rt, D - OZ), Vector3(0, ry, (D + OZ) / 2.0), roof, sb)
	_box(self, Vector3(W * 2.0, rt, D - OZ), Vector3(0, ry, -(D + OZ) / 2.0), roof, sb)
	for s in [-1.0, 1.0]:
		_box(self, Vector3(W - OX, rt, OZ * 2.0), Vector3(s * (W + OX) / 2.0, ry, 0), roof, sb)
	# rails the roof halves run on, reaching past the side walls, with posts at the ends
	var reach := OX + SLIDE + 0.3
	for s in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			var z: float = zs * (OZ + 0.35)
			_box(self, Vector3(reach, 0.18, 0.25), Vector3(s * reach / 2.0, H + rt + 0.09, z), steel)
			_box(self, Vector3(0.25, H + rt, 0.25), Vector3(s * (reach - 0.15), (H + rt) / 2.0, z), steel, sb)
	# the two sliding roof halves
	for s in [-1.0, 1.0]:
		var body := AnimatableBody3D.new()
		body.collision_layer = Game.L_WORLD
		body.collision_mask = 0
		body.sync_to_physics = false
		body.position = Vector3(s * OX / 2.0, H + rt + 0.28, 0)
		add_child(body)
		_box(body, Vector3(OX, 0.2, OZ * 2.0 + 0.9), Vector3.ZERO, roof, body)
		for k in 5:
			_box(body, Vector3(0.12, 0.08, OZ * 2.0 + 0.9), Vector3(-s * OX / 2.0 + s * (0.4 + k * 1.9), 0.13, 0), rib)
		_box(body, Vector3(0.1, 0.12, OZ * 2.0 + 0.9), Vector3(-s * (OX / 2.0 - 0.05), 0.0, 0), yellow)
		panels.append([body, s])
	# button panel on the inside of the front wall, right of the opening
	var plate := _box(self, Vector3(0.5, 0.65, 0.06), button_local + Vector3(0, 0, 0.02), yellow)
	plate.visibility_range_end = 60.0
	_box(self, Vector3(0.36, 0.5, 0.07), button_local + Vector3(0, 0, 0.0), _mat(Color(0.08, 0.08, 0.08)))
	button_cap = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.1
	cyl.height = 0.08
	cyl.material = _mat(Color(0.85, 0.08, 0.05), 0.4, 0.0, false)
	button_cap.mesh = cyl
	button_cap.rotation.x = PI / 2.0
	button_cap.position = button_local + Vector3(0, 0.05, -0.04)
	add_child(button_cap)
	var lbl := Label3D.new()
	lbl.text = "ROOF"
	lbl.font_size = 40
	lbl.pixel_size = 0.004
	lbl.modulate = Color(0.95, 0.95, 0.9)
	lbl.position = button_local + Vector3(0, -0.17, -0.06)
	lbl.rotation.y = PI
	add_child(lbl)
	# orange warning beacon over the opening, flashes while the roof moves
	beacon_mesh = _box(self, Vector3(0.25, 0.25, 0.25), Vector3(0, GAP_H + 0.45, D - T - 0.2), _mat(Color(0.5, 0.25, 0.05), 0.4))
	beacon = OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.55, 0.1)
	beacon.light_energy = 0.0
	beacon.omni_range = 14.0
	beacon.position = beacon_mesh.position + Vector3(0, 0, -0.4)
	add_child(beacon)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_energy = 1.2
	lamp.omni_range = 18.0
	lamp.position = Vector3(0, H - 1.0, -D + 3.0)
	add_child(lamp)
	motor = AudioStreamPlayer3D.new()
	motor.stream = Sfx.get_stream("rumble")
	motor.unit_size = 10.0
	motor.max_distance = 120.0
	motor.volume_db = -6.0
	motor.pitch_scale = 0.6
	motor.position = Vector3(0, H, 0)
	add_child(motor)
	set_physics_process(false)

## Interface shared with doors (player.gd's E-interaction).
func centre() -> Vector3:
	return to_global(button_local)

func label() -> String:
	return "close the roof" if open else "open the roof"

func toggle() -> void:
	open = not open
	_blink = 0.0
	_target = 1.0 if open else 0.0
	Sfx.play3d("click", centre(), 0.0, 0.8)
	button_cap.position = button_local + Vector3(0, 0.05, -0.01)
	Game.make_noise(global_position, 40.0)
	if not motor.playing:
		motor.play()
	set_physics_process(true)

## Instantly open or close (used when a level loads with the roof already open).
func set_open(v: bool) -> void:
	open = v
	_target = 1.0 if v else 0.0
	_t = _target
	_apply()

func _apply() -> void:
	var e := smoothstep(0.0, 1.0, _t)
	for p in panels:
		var body: AnimatableBody3D = p[0]
		body.position.x = p[1] * (OX / 2.0 + e * SLIDE)

func _physics_process(dt: float) -> void:
	_t = move_toward(_t, _target, dt * SPEED)
	_apply()
	_blink += dt
	var on := fmod(_blink, 0.6) < 0.3
	beacon.light_energy = 3.0 if on else 0.0
	(beacon_mesh.mesh.material as StandardMaterial3D).emission_enabled = on
	(beacon_mesh.mesh.material as StandardMaterial3D).emission = Color(1.0, 0.5, 0.1)
	if _blink > 0.25:
		button_cap.position = button_local + Vector3(0, 0.05, -0.04)
	if is_equal_approx(_t, _target):
		beacon.light_energy = 0.0
		(beacon_mesh.mesh.material as StandardMaterial3D).emission_enabled = false
		motor.stop()
		Sfx.play3d("build", global_position + Vector3(0, H, 0), -2.0, 0.6)
		_blink = 0.0
		set_physics_process(false)
