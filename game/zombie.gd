extends CharacterBody3D
## One zombie: jointed low-poly body (legs, hunched torso, reaching arms, lolling head, glowing eyes).
## Asleep (no processing) while idle; the director wakes it on noise or sight.
## Walkers limp at different speeds; about one in five is a runner.

enum { IDLE, INVESTIGATE, CHASE, DEAD }

var state := IDLE
var hp := 100.0
var target := Vector3.ZERO
var director: Node
var visual: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var speed := 3.6
var runner := false
var limp := 0.0
var attack_cd := 0.0
var stun := 0.0
var flinch := 0.0
var swipe := 0.0
var lost_t := 0.0
var stuck_t := 0.0
var side_t := 0.0
var side_dir := Vector3.ZERO
var sep := Vector3.ZERO
var anim_t := 0.0
var groan_t := 0.0
var alerted := false

func setup(parts: Dictionary, d: Node) -> void:
	director = d
	collision_layer = Game.L_ZOMBIE
	collision_mask = Game.L_WORLD | Game.L_STRUCT | Game.L_PLAYER
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(55)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	runner = randf() < 0.2
	speed = randf_range(5.0, 5.6) if runner else randf_range(2.8, 3.9)
	limp = randf_range(0.0, 0.5) if not runner else 0.0
	visual = Node3D.new()
	var sc := randf_range(0.92, 1.08)
	visual.scale = Vector3(sc, sc, sc)
	add_child(visual)
	leg_l = _limb(visual, parts.leg, Vector3(0.1, 0.92, 0))
	leg_r = _limb(visual, parts.leg, Vector3(-0.1, 0.92, 0))
	torso = _limb(visual, parts.torso, Vector3(0, 0.92, 0))
	head = _limb(torso, parts.head, Vector3(0, 0.60, 0.02))
	arm_l = _limb(torso, parts.arm, Vector3(0.25, 0.50, 0))
	arm_r = _limb(torso, parts.arm, Vector3(-0.25, 0.50, 0))
	anim_t = randf() * 10.0
	groan_t = randf_range(2.0, 9.0)
	_idle_pose()
	set_physics_process(false)

func _limb(parent: Node3D, mesh: Mesh, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.visibility_range_end = 130.0
	pivot.add_child(mi)
	return pivot

func _idle_pose() -> void:
	torso.rotation = Vector3(-0.35, randf_range(-0.2, 0.2), randf_range(-0.12, 0.12))
	head.rotation = Vector3(0.5, randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
	arm_l.rotation = Vector3(0.25, 0, 0.12)
	arm_r.rotation = Vector3(0.15, 0, -0.1)
	leg_l.rotation = Vector3.ZERO
	leg_r.rotation = Vector3(0.1 * limp, 0, 0)

func chase() -> void:
	if state == DEAD:
		return
	state = CHASE
	lost_t = 0.0
	set_physics_process(true)

func investigate(p: Vector3) -> void:
	if state != IDLE:
		return
	state = INVESTIGATE
	target = p
	set_physics_process(true)

func go_idle() -> void:
	state = IDLE
	alerted = false
	velocity = Vector3.ZERO
	visual.position = Vector3.ZERO
	_idle_pose()
	set_physics_process(false)

func _physics_process(dt: float) -> void:
	var pl = Game.player
	if state == CHASE:
		if pl == null or not pl.is_targetable():
			go_idle()
			return
		target = pl.global_position
		if global_position.distance_to(target) > 90.0:
			lost_t += dt
			if lost_t > 8.0:
				go_idle()
				return
		else:
			lost_t = 0.0
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	var dir := to / d if d > 0.01 else Vector3.ZERO
	if state == INVESTIGATE and d < 2.0:
		go_idle()
		return
	var spd := speed if state == CHASE else 1.6
	if stun > 0.0:
		stun -= dt
		spd = 0.0
	attack_cd -= dt
	var want := (dir + sep * 1.4 + side_dir).normalized() * spd
	if state == CHASE and d < 1.25:
		want = Vector3.ZERO
		if attack_cd <= 0.0 and absf(target.y - global_position.y) < 1.6 and stun <= 0.0:
			attack_cd = 1.0
			swipe = 1.0
			pl.zombie_hit(9.0, 11.0)
	var a := minf(7.0 * dt, 1.0)
	velocity.x = lerpf(velocity.x, want.x, a)
	velocity.z = lerpf(velocity.z, want.z, a)
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= 22.0 * dt
	move_and_slide()
	if dir.length() > 0.1 and stun <= 0.0:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(8.0 * dt, 1.0))
	if spd > 0.5 and Vector2(velocity.x, velocity.z).length() < 0.6 and d > 1.5:
		stuck_t += dt
		if stuck_t > 0.7:
			stuck_t = 0.0
			side_dir = dir.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
			side_t = 0.9
	else:
		stuck_t = 0.0
	side_t -= dt
	if side_t <= 0.0:
		side_dir = Vector3.ZERO
	_animate(dt)
	groan_t -= dt
	if groan_t <= 0.0:
		groan_t = randf_range(4.0, 11.0)
		if pl and global_position.distance_to(pl.global_position) < 35.0:
			Sfx.play3d("groan", global_position + Vector3(0, 1.6, 0), -4.0)

## Procedural walk: stride follows actual speed, limping walkers drag one leg, runners pump their arms.
func _animate(dt: float) -> void:
	if Game.player and global_position.distance_squared_to(Game.player.global_position) > 70.0 * 70.0:
		return
	var v := Vector2(velocity.x, velocity.z).length()
	anim_t += dt * (2.2 + v * 1.9)
	var stride := clampf(v / 3.0, 0.0, 1.0) * 0.65
	var s := sin(anim_t)
	leg_l.rotation.x = s * stride
	leg_r.rotation.x = -s * stride * (1.0 - limp) + limp * 0.25
	visual.position.y = absf(cos(anim_t)) * 0.05 * stride - limp * 0.03 * maxf(s, 0.0)
	flinch = move_toward(flinch, 0.0, dt * 4.0)
	swipe = move_toward(swipe, 0.0, dt * 3.5)
	var lean := -0.25 - (0.25 if runner and state == CHASE else 0.0) + flinch * 0.6
	torso.rotation = Vector3(lean, sin(anim_t * 0.5) * 0.08, s * 0.06 + limp * 0.1)
	head.rotation = Vector3(0.25 + sin(anim_t * 0.7) * 0.15, sin(anim_t * 0.3) * 0.3, sin(anim_t * 0.9) * 0.2)
	if state == CHASE and not runner:
		# arms up and reaching, a slow flail
		arm_l.rotation = Vector3(1.35 + sin(anim_t * 1.3) * 0.15 - swipe * 1.2, 0.0, 0.08)
		arm_r.rotation = Vector3(1.25 + cos(anim_t * 1.1) * 0.15 - swipe * 1.6, 0.0, -0.08)
	elif state == CHASE:
		arm_l.rotation = Vector3(-s * 0.9 + 0.3 - swipe * 1.2, 0, 0.1)
		arm_r.rotation = Vector3(s * 0.9 + 0.3 - swipe * 1.6, 0, -0.1)
	else:
		arm_l.rotation = Vector3(0.2 - s * 0.2, 0, 0.12)
		arm_r.rotation = Vector3(0.2 + s * 0.2, 0, -0.1)

func take_damage(dmg: float, knock: Vector3, _dir: Vector3) -> void:
	if state == DEAD:
		return
	hp -= dmg
	flinch = 1.0
	if knock.length() > 0.1:
		velocity += knock
		if knock.length() > 5.0:
			stun = 0.8
	if hp <= 0.0:
		die()
		return
	if state != CHASE:
		director.alert(self, true)

func die() -> void:
	state = DEAD
	collision_layer = 0
	collision_mask = Game.L_WORLD
	set_physics_process(false)
	director.on_dead(self)
	Sfx.play3d("zombie_death", global_position + Vector3(0, 1.2, 0), 0.0)
	var tw := create_tween()
	tw.tween_property(torso, "rotation", Vector3(0.3, 0.4, 0.2), 0.25)
	tw.parallel().tween_property(visual, "rotation:x", PI / 2.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(visual, "position:y", 0.12, 0.55)
	tw.parallel().tween_property(arm_l, "rotation", Vector3(2.6, 0.3, 0.6), 0.5)
	tw.parallel().tween_property(arm_r, "rotation", Vector3(1.8, -0.4, -0.8), 0.5)
	tw.parallel().tween_property(leg_r, "rotation:x", 0.5, 0.5)
	tw.tween_interval(4.0)
	tw.tween_property(visual, "position:y", -1.0, 1.5)
	tw.tween_callback(queue_free)

# ---------------------------------------------------------------- meshes
## Ordinary people, now dead: [shirt/jacket, trousers, tie (or none), hair, moustache, glasses].
## Several are Bjørn's type: suit, tie, moustache, glasses.
const OUTFITS := [
	[Color(0.32, 0.30, 0.28), Color(0.25, 0.24, 0.22), Color(0.15, 0.35, 0.20), Color(0.50, 0.50, 0.47), true, true],    # old car dealer
	[Color(0.12, 0.14, 0.22), Color(0.10, 0.11, 0.16), Color(0.45, 0.05, 0.05), Color(0.18, 0.12, 0.07), false, false],  # office worker
	[Color(0.33, 0.37, 0.44), Color(0.22, 0.20, 0.18), null, Color(0.30, 0.20, 0.10), true, false],                       # grey-blue shirt
	[Color(0.52, 0.30, 0.24), Color(0.18, 0.22, 0.30), null, Color(0.12, 0.09, 0.06), false, false],                      # rust shirt, jeans
	[Color(0.56, 0.54, 0.46), Color(0.28, 0.27, 0.22), null, Color(0.60, 0.58, 0.55), false, true],                       # pensioner
	[Color(0.20, 0.30, 0.22), Color(0.12, 0.12, 0.13), null, Color(0.40, 0.25, 0.10), false, false],                      # green jacket
	[Color(0.62, 0.22, 0.20), Color(0.30, 0.32, 0.36), null, Color(0.08, 0.06, 0.05), false, false],                      # red hoodie
	[Color(0.40, 0.38, 0.34), Color(0.30, 0.28, 0.26), Color(0.20, 0.20, 0.45), Color(0.25, 0.18, 0.10), true, false],    # suit, blue tie
]

## Shared per-outfit meshes: torso (origin at the hips), head (origin at the neck), arm (origin at the
## shoulder, hanging down), leg (origin at the hip joint, down to the foot). Faces -Z.
static func build_parts(i: int) -> Dictionary:
	var o: Array = OUTFITS[i % OUTFITS.size()]
	var shirt: Color = o[0]
	var pants: Color = o[1]
	var skin := Color(0.62, 0.64, 0.55).lerp(Color(0.55, 0.60, 0.50), float(i % 3) / 2.0)   # pale, grey-green
	var dark := skin.darkened(0.45)
	var blood := Color(0.32, 0.03, 0.02)
	var tparts := [
		[Vector3(0.36, 0.16, 0.21), Vector3(0, 0.02, 0), pants.darkened(0.15)],
		[Vector3(0.40, 0.50, 0.23), Vector3(0, 0.33, 0.01), shirt],
		[Vector3(0.14, 0.18, 0.012), Vector3(-0.09, 0.36, -0.12), blood],
		[Vector3(0.10, 0.08, 0.012), Vector3(0.11, 0.22, -0.12), blood.lightened(0.1)],
		[Vector3(0.44, 0.10, 0.25), Vector3(0, 0.55, 0.01), shirt.darkened(0.1)],
	]
	if o[2] != null:   # suit: white shirt, tie, lapels
		tparts += [[Vector3(0.12, 0.28, 0.012), Vector3(0, 0.42, -0.118), Color(0.75, 0.74, 0.68)],
				   [Vector3(0.045, 0.26, 0.014), Vector3(0.01, 0.40, -0.124), o[2]],
				   [Vector3(0.06, 0.22, 0.012), Vector3(0.07, 0.43, -0.122), shirt.darkened(0.25)],
				   [Vector3(0.06, 0.22, 0.012), Vector3(-0.07, 0.43, -0.122), shirt.darkened(0.25)]]
	else:              # torn shirt showing the belly
		tparts.append([Vector3(0.18, 0.14, 0.24), Vector3(0.08, 0.14, 0.01), skin.darkened(0.2)])
	var hair: Color = o[3]
	var hparts := [
		[Vector3(0.10, 0.10, 0.10), Vector3(0, 0.03, 0), skin.darkened(0.1)],
		[Vector3(0.22, 0.25, 0.23), Vector3(0, 0.19, -0.01), skin],
		[Vector3(0.19, 0.06, 0.19), Vector3(0, 0.06, -0.045), skin.darkened(0.12)],          # slack jaw
		[Vector3(0.11, 0.035, 0.01), Vector3(0, 0.075, -0.142), Color(0.10, 0.02, 0.02)],   # open mouth
		[Vector3(0.10, 0.012, 0.01), Vector3(0, 0.094, -0.143), Color(0.65, 0.62, 0.45)],   # teeth
		[Vector3(0.04, 0.06, 0.045), Vector3(0, 0.16, -0.135), skin.darkened(0.08)],         # nose
		[Vector3(0.03, 0.07, 0.05), Vector3(0.12, 0.18, -0.01), skin.darkened(0.1)],         # ears
		[Vector3(0.03, 0.07, 0.05), Vector3(-0.12, 0.18, -0.01), skin.darkened(0.1)],
		[Vector3(0.07, 0.05, 0.012), Vector3(0.055, 0.205, -0.124), dark],                   # sunken eye sockets
		[Vector3(0.07, 0.05, 0.012), Vector3(-0.055, 0.205, -0.124), dark],
		[Vector3(0.07, 0.015, 0.014), Vector3(0.055, 0.24, -0.126), hair.darkened(0.2)],     # brows
		[Vector3(0.07, 0.015, 0.014), Vector3(-0.055, 0.24, -0.126), hair.darkened(0.2)],
		[Vector3(0.24, 0.06, 0.24), Vector3(0.0, 0.32, 0.0), hair],                           # hair
		[Vector3(0.24, 0.12, 0.04), Vector3(0.0, 0.26, 0.11), hair],
		[Vector3(0.06, 0.05, 0.04), Vector3(0.09, 0.27, -0.11), blood],                      # head wound
	]
	if o[4]:
		hparts.append([Vector3(0.15, 0.035, 0.02), Vector3(0, 0.122, -0.135), hair.darkened(0.1)])   # moustache
	if o[5]:   # cracked glasses, one lens missing
		hparts += [[Vector3(0.20, 0.015, 0.012), Vector3(0, 0.215, -0.135), Color(0.08, 0.08, 0.08)],
				   [Vector3(0.065, 0.045, 0.008), Vector3(-0.055, 0.205, -0.137), Color(0.55, 0.65, 0.7)]]
	var torso := _mesh(tparts)
	var head := _mesh(hparts, [[Vector3(0.022, 0.02, 0.012), Vector3(0.055, 0.205, -0.131)], [Vector3(0.022, 0.02, 0.012), Vector3(-0.055, 0.205, -0.131)]])
	var arm := _mesh([
		[Vector3(0.11, 0.34, 0.11), Vector3(0, -0.15, 0), shirt.darkened(0.1)],
		[Vector3(0.10, 0.30, 0.10), Vector3(0, -0.47, 0), shirt.darkened(0.1) if o[2] != null else skin],
		[Vector3(0.09, 0.10, 0.07), Vector3(0, -0.66, -0.01), skin.darkened(0.1)],
		[Vector3(0.105, 0.08, 0.105), Vector3(0, -0.40, 0), blood],
	])
	var leg := _mesh([
		[Vector3(0.15, 0.46, 0.16), Vector3(0, -0.22, 0), pants],
		[Vector3(0.13, 0.42, 0.14), Vector3(0, -0.65, 0.01), pants.darkened(0.08)],
		[Vector3(0.13, 0.08, 0.25), Vector3(0, -0.88, -0.05), Color(0.10, 0.08, 0.06)],
	])
	return {"torso": torso, "head": head, "arm": arm, "leg": leg}

## Builds one mesh from boxes; optional glowing boxes (eyes) go in a second, emissive surface.
static func _mesh(parts: Array, glow := []) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		_box(st, p[0], p[1], p[2])
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	mesh.surface_set_material(0, m)
	if not glow.is_empty():
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		for g in glow:
			_box(st2, g[0], g[1], Color(1, 1, 1))
		st2.generate_normals()
		st2.commit(mesh)
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.9, 0.2, 0.1)
		em.emission_enabled = true
		em.emission = Color(1.0, 0.25, 0.1)
		em.emission_energy_multiplier = 2.5
		em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.surface_set_material(1, em)
	return mesh

static func _box(st: SurfaceTool, size: Vector3, c: Vector3, col: Color) -> void:
	var h := size / 2.0
	var v := []
	for i in 8:
		v.append(c + Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	for f in faces:
		st.set_color(col)
		for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_vertex(v[idx])
