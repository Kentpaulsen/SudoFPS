extends CharacterBody3D
## One zombie. Asleep (no processing) while idle; the director wakes it on noise or sight.

enum { IDLE, INVESTIGATE, CHASE, DEAD }
const SPEED := 4.3

var state := IDLE
var hp := 100.0
var target := Vector3.ZERO
var director: Node
var visual: Node3D
var attack_cd := 0.0
var stun := 0.0
var lost_t := 0.0
var stuck_t := 0.0
var side_t := 0.0
var side_dir := Vector3.ZERO
var sep := Vector3.ZERO
var anim_t := 0.0
var groan_t := 0.0
var alerted := false

func setup(mesh: Mesh, d: Node) -> void:
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
	visual = Node3D.new()
	add_child(visual)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.visibility_range_end = 150.0
	visual.add_child(mi)
	anim_t = randf() * 10.0
	groan_t = randf_range(2.0, 9.0)
	set_physics_process(false)

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
	visual.rotation = Vector3.ZERO
	visual.position = Vector3.ZERO
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
	var spd := SPEED if state == CHASE else 1.8
	if stun > 0.0:
		stun -= dt
		spd = 0.0
	attack_cd -= dt
	var want := (dir + sep * 1.4 + side_dir).normalized() * spd
	if state == CHASE and d < 1.25:
		want = Vector3.ZERO
		if attack_cd <= 0.0 and absf(target.y - global_position.y) < 1.6 and stun <= 0.0:
			attack_cd = 1.0
			pl.zombie_hit(9.0, 11.0)
			var tw := create_tween()
			tw.tween_property(visual, "position:z", -0.35, 0.08)
			tw.tween_property(visual, "position:z", 0.0, 0.2)
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
	# unstick: sidestep along obstacles
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
	# shamble
	anim_t += dt * (6.0 if state == CHASE else 3.0)
	visual.rotation.z = sin(anim_t) * 0.10
	visual.rotation.x = -0.12 if state == CHASE else 0.0
	visual.position.y = absf(sin(anim_t)) * 0.05
	groan_t -= dt
	if groan_t <= 0.0:
		groan_t = randf_range(4.0, 11.0)
		if pl and global_position.distance_to(pl.global_position) < 35.0:
			Sfx.play3d("groan", global_position + Vector3(0, 1.6, 0), -4.0)

func take_damage(dmg: float, knock: Vector3, _dir: Vector3) -> void:
	if state == DEAD:
		return
	hp -= dmg
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
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", PI / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(visual, "position:y", 0.15, 0.45)
	tw.tween_interval(4.0)
	tw.tween_property(visual, "position:y", -1.0, 1.5)
	tw.tween_callback(queue_free)

## Builds the shared zombie meshes (arms out front, facing -Z, origin at feet).
static func build_mesh(shirt: Color, pants: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skin := Color(0.47, 0.58, 0.40)
	var parts := [
		[Vector3(0.15, 0.82, 0.16), Vector3(0.10, 0.43, 0.0), pants, 0.0],
		[Vector3(0.15, 0.82, 0.16), Vector3(-0.10, 0.43, 0.03), pants, 0.0],
		[Vector3(0.37, 0.16, 0.21), Vector3(0, 0.90, 0), pants.darkened(0.2), 0.0],
		[Vector3(0.40, 0.52, 0.22), Vector3(0, 1.22, 0.02), shirt, 0.08],
		[Vector3(0.16, 0.12, 0.23), Vector3(0.09, 1.05, 0.02), skin.darkened(0.15), 0.0],
		[Vector3(0.10, 0.10, 0.58), Vector3(0.25, 1.40, -0.26), shirt.darkened(0.15), 0.0],
		[Vector3(0.10, 0.10, 0.58), Vector3(-0.25, 1.36, -0.24), shirt.darkened(0.15), 0.0],
		[Vector3(0.09, 0.08, 0.14), Vector3(0.25, 1.40, -0.60), skin, 0.0],
		[Vector3(0.09, 0.08, 0.14), Vector3(-0.25, 1.36, -0.58), skin, 0.0],
		[Vector3(0.10, 0.10, 0.10), Vector3(0, 1.52, 0.0), skin, 0.0],
		[Vector3(0.24, 0.26, 0.24), Vector3(0.02, 1.68, -0.04), skin, 0.25],
		[Vector3(0.05, 0.03, 0.02), Vector3(0.07, 1.71, -0.17), Color(0.75, 0.08, 0.05), 0.25],
		[Vector3(0.05, 0.03, 0.02), Vector3(-0.03, 1.71, -0.17), Color(0.75, 0.08, 0.05), 0.25],
		[Vector3(0.12, 0.03, 0.02), Vector3(0.02, 1.61, -0.165), Color(0.15, 0.05, 0.05), 0.25],
	]
	for p in parts:
		_box(st, p[0], p[1], p[2], Basis(Vector3.FORWARD, p[3] * 0.4))
	st.generate_normals()
	var mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	mesh.surface_set_material(0, m)
	return mesh

static func _box(st: SurfaceTool, size: Vector3, c: Vector3, col: Color, b: Basis) -> void:
	var h := size / 2.0
	var v := []
	for i in 8:
		v.append(c + b * Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	for f in faces:
		st.set_color(col)
		for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_vertex(v[idx])
