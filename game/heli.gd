extends CharacterBody3D
## Utility helicopter (developer mode only). Arcade flight: Space climbs, Shift/C descends,
## W/S fly forward/back, A/D turn. The rotor spins up before it can lift off.

var kind := "heli"
var model: Node3D
var driver = null
var speed := 0.0               # forward speed (m/s), shown on the HUD
var steer := 0.0
var rotor: Node3D
var tail_rotor: Node3D
var rotor_rpm := 0.0           # 0..1
var seat_local := Vector3.ZERO
var exit_local := Vector3(2.4, 0, 0)
var cam_offset := Vector3(0, 4.0, 15.0)
var audio: AudioStreamPlayer3D
var _climb := 0.0
var _noise_t := 0.0
var _pitch := 0.0
var _roll := 0.0

func setup(glb: String, _k := "heli") -> void:
	collision_layer = Game.L_WORLD
	collision_mask = Game.L_WORLD | Game.L_STRUCT
	floor_max_angle = deg_to_rad(35)
	model = load(glb).instantiate()
	add_child(model)
	for sb in model.find_children("*", "StaticBody3D", true, false):
		sb.free()
	rotor = model.find_child("Rotor", true, false)
	tail_rotor = model.find_child("TailRotor", true, false)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.3, 2.0, 6.0)
	cs.shape = bs
	cs.position = Vector3(0, 1.1, 1.0)
	add_child(cs)
	var tail := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(0.6, 0.9, 6.0)
	tail.shape = tb
	tail.position = Vector3(0, 1.9, -5.0)
	add_child(tail)
	var seat: Node3D = model.find_child("SEAT", true, false)
	if seat:
		seat_local = to_local(seat.global_position)
	var ex: Node3D = model.find_child("EXIT_L", true, false)
	if ex:
		exit_local = to_local(ex.global_position)
	audio = AudioStreamPlayer3D.new()
	audio.stream = Sfx.get_stream("rotor")
	audio.unit_size = 14.0
	audio.max_distance = 260.0
	add_child(audio)

func seat_global() -> Vector3:
	return to_global(seat_local)

func exit_global() -> Vector3:
	return to_global(exit_local)

func set_driver(d) -> void:
	driver = d
	if d and not audio.playing:
		audio.play()

func horn() -> void:
	pass

func _physics_process(dt: float) -> void:
	var fwd_in := 0.0
	var turn_in := 0.0
	var climb_in := 0.0
	if driver and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Game.smoke):
		fwd_in = Input.get_axis("move_back", "move_forward")
		turn_in = Input.get_axis("move_right", "move_left")
		climb_in = (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("sprint") or Input.is_action_pressed("crouch") else 0.0)
	rotor_rpm = move_toward(rotor_rpm, 1.0 if driver else 0.0, dt / (2.0 if driver else 8.0))
	var lift := smoothstep(0.5, 0.95, rotor_rpm)
	steer = move_toward(steer, turn_in, dt * 2.0)
	rotation.y += steer * 1.1 * dt * lift
	speed = move_toward(speed, fwd_in * 45.0 * lift, dt * (8.0 if fwd_in != 0.0 else 4.0))
	_climb = move_toward(_climb, climb_in * 7.0, dt * 6.0)
	var fwd := global_transform.basis.z
	var vy := _climb * lift + (-9.0 * (1.0 - lift))
	if is_on_floor() and vy < 0.0:
		vy = -0.5
		speed = move_toward(speed, 0.0, dt * 12.0)
	velocity = Vector3(fwd.x * speed, vy, fwd.z * speed)
	move_and_slide()
	if global_position.y > 220.0:
		global_position.y = 220.0
	# looks: nose dips when flying forward, banks into turns, rotors spin
	_pitch = lerpf(_pitch, speed / 45.0 * 0.25, minf(dt * 2.0, 1.0))
	_roll = lerpf(_roll, -steer * 0.25 * clampf(absf(speed) / 20.0, 0.2, 1.0), minf(dt * 2.0, 1.0))
	model.rotation = Vector3(_pitch, 0, _roll)
	if rotor:
		rotor.rotate_object_local(Vector3.UP, rotor_rpm * 28.0 * dt)
	if tail_rotor:
		tail_rotor.rotate_object_local(Vector3.RIGHT, rotor_rpm * 45.0 * dt)
	audio.pitch_scale = 0.5 + rotor_rpm * 0.6
	audio.volume_db = lerpf(-30.0, 2.0, rotor_rpm)
	if rotor_rpm < 0.02 and not driver:
		audio.stop()
	_noise_t += dt
	if _noise_t > 1.0 and rotor_rpm > 0.3 and Game.zombies_enabled:
		_noise_t = 0.0
		Game.make_noise(global_position, 110.0)
