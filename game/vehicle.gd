extends CharacterBody3D
## Drivable arcade vehicle (Tike or Bike). Models face +Z. The body only turns about Y;
## the model tilts to the ground (and the Bike leans) for looks, so it can never roll over.

var kind := "tike"
var model: Node3D
var driver = null
var speed := 0.0
var steer := 0.0
var max_speed := 15.0
var accel := 8.0
var brake := 16.0
var reverse_max := 5.0
var turn_rate := 1.9
var leans := false
var lean := 0.0
var roll := 0.0
var length := 2.0
var width := 1.2
var wheels: Array = []          # [node, rest basis, radius, steers]
var steer_node: Node3D
var steer_rest := Basis()
var steering_wheel: Node3D
var sw_axis := Vector3.UP
var pupils: Array = []          # [node, rest pos, max offset]
var seat_local := Vector3.ZERO
var exit_local := Vector3(1.2, 0, 0)
var engine: AudioStreamPlayer3D
var _noise_t := 0.0
var _crash_t := 0.0

func setup(glb: String, k: String) -> void:
	kind = k
	collision_layer = Game.L_WORLD
	collision_mask = Game.L_WORLD | Game.L_STRUCT | Game.L_ZOMBIE
	floor_snap_length = 0.7
	floor_max_angle = deg_to_rad(50)
	model = load(glb).instantiate()
	add_child(model)
	# the Blender colliders are replaced by this body's own box; left in, the body pushes itself upwards
	for sb in model.find_children("*", "StaticBody3D", true, false):
		sb.free()
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var box: AABB = (global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
		if m.name.begins_with("Pupil"):
			pupils.append([m, m.position, m.get_aabb().size.x * 0.45])
		if m.name.begins_with("Wheel_"):
			var steers := m.name in ["Wheel_FL", "Wheel_FR"]
			wheels.append([m, m.basis, m.get_aabb().size.y * 0.5, steers])
	length = aabb.size.z
	width = aabb.size.x
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var h := minf(aabb.size.y * 0.55, 0.9)
	bs.size = Vector3(aabb.size.x * 0.85, h, aabb.size.z * 0.85)
	cs.shape = bs
	cs.position = Vector3(aabb.get_center().x, 0.18 + h / 2.0, aabb.get_center().z)
	add_child(cs)
	steer_node = model.find_child("Steer", true, false)
	if steer_node:
		steer_rest = steer_node.basis
	steering_wheel = model.find_child("SteeringWheel", true, false)
	sw_axis = Vector3(0, 0.38, -0.22).normalized()
	var seat: Node3D = model.find_child("SEAT", true, false)
	if seat:
		seat_local = to_local(seat.global_position)
	var ex: Node3D = model.find_child("EXIT_L", true, false)
	if ex:
		exit_local = to_local(ex.global_position)
	if kind == "bike":
		max_speed = 19.0
		accel = 10.0
		turn_rate = 2.4
		leans = true
	engine = AudioStreamPlayer3D.new()
	engine.stream = Sfx.streams.engine
	engine.unit_size = 5.0
	engine.max_distance = 80.0
	engine.volume_db = -6.0
	add_child(engine)

func seat_global() -> Vector3:
	return to_global(seat_local)

func exit_global() -> Vector3:
	return to_global(exit_local)

func set_driver(d) -> void:
	driver = d
	if d:
		engine.play()
	else:
		engine.stop()

func _physics_process(dt: float) -> void:
	var throttle := 0.0
	var steer_in := 0.0
	var handbrake := false
	if driver and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Game.smoke):
		throttle = Input.get_axis("move_back", "move_forward")
		steer_in = Input.get_axis("move_right", "move_left")
		handbrake = Input.is_action_pressed("jump")
	if throttle > 0.0:
		speed = move_toward(speed, max_speed, accel * dt) if speed >= -0.2 else move_toward(speed, 0.0, brake * dt)
	elif throttle < 0.0:
		speed = move_toward(speed, -reverse_max, accel * 0.7 * dt) if speed <= 0.3 else move_toward(speed, 0.0, brake * dt)
	else:
		speed = move_toward(speed, 0.0, 3.0 * dt)
	if handbrake:
		speed = move_toward(speed, 0.0, brake * 1.3 * dt)
	if global_position.y < -0.3:
		speed = clampf(speed, -2.0, 3.0)
	steer = move_toward(steer, steer_in, 3.5 * dt)
	var grip := clampf(absf(speed) / 5.0, 0.0, 1.0) * lerpf(1.0, 0.55, absf(speed) / max_speed)
	rotation.y += steer * turn_rate * grip * signf(speed) * dt
	var fwd := global_transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y = maxf(velocity.y - 22.0 * dt, -25.0)
	move_and_slide()
	_crash_t -= dt
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var o = col.get_collider()
		if o and o.has_method("take_damage"):
			if absf(speed) > 3.0:
				o.take_damage(absf(speed) * 7.0, fwd * speed * 0.7 + Vector3.UP * 3.0, fwd)
				speed *= 0.85
				Sfx.play3d("hit", global_position + Vector3(0, 0.8, 0), 3.0, 0.8)
		elif absf(col.get_normal().y) < 0.5 and absf(speed) > 2.0 and _crash_t <= 0.0:
			_crash_t = 0.5
			if absf(speed) > 7.0:
				Sfx.play3d("hit", global_position + Vector3(0, 0.6, 0), 4.0, 0.6)
			speed *= 0.35
	_pose(dt)
	if driver:
		engine.pitch_scale = 0.65 + absf(speed) / max_speed * 1.4
		_noise_t += dt
		if _noise_t > 0.6 and Game.zombies_enabled:
			_noise_t = 0.0
			Game.make_noise(global_position, 22.0 + absf(speed) * 2.0)

func _pose(dt: float) -> void:
	var w = Game.world
	var b := global_transform.basis
	var p := global_position
	var hf: float = w.height_at(p.x + b.z.x * length * 0.4, p.z + b.z.z * length * 0.4)
	var hb: float = w.height_at(p.x - b.z.x * length * 0.4, p.z - b.z.z * length * 0.4)
	var hl: float = w.height_at(p.x + b.x.x * width * 0.4, p.z + b.x.z * width * 0.4)
	var hr: float = w.height_at(p.x - b.x.x * width * 0.4, p.z - b.x.z * width * 0.4)
	var pitch := -atan2(hf - hb, length * 0.8)
	var side := atan2(hl - hr, width * 0.8)
	if leans:
		lean = lerpf(lean, -steer * clampf(absf(speed) / max_speed, 0.0, 1.0) * 0.5, minf(6.0 * dt, 1.0))
		side = lean
	model.basis = model.basis.slerp(Basis.from_euler(Vector3(pitch, 0, side)), minf(10.0 * dt, 1.0))
	roll += speed * dt
	for wh in wheels:
		var n: Node3D = wh[0]
		var spin := Basis(Vector3.RIGHT, roll / maxf(wh[2], 0.1))
		var turn := Basis(Vector3.UP, steer * 0.45) if wh[3] else Basis()
		n.basis = turn * wh[1] * spin
	if steer_node:
		steer_node.basis = Basis(Vector3.UP, steer * 0.5) * steer_rest
	if steering_wheel:
		steering_wheel.basis = Basis(sw_axis, -steer * 2.2)

func _process(_dt: float) -> void:
	var pl = Game.player
	if pl == null or pupils.is_empty():
		return
	var target: Vector3
	if driver:
		target = global_position + global_transform.basis.z * 20.0 + Vector3(0, 1, 0)
	elif pl.global_position.distance_to(global_position) < 40.0:
		target = pl.global_position + Vector3(0, 1.6, 0)
	else:
		return
	for e in pupils:
		var n: Node3D = e[0]
		var local: Vector3 = n.get_parent().to_local(target) - e[1]
		var d := local.normalized()
		n.position = n.position.lerp(e[1] + Vector3(d.x, d.y, 0.0) * e[2], 0.15)
