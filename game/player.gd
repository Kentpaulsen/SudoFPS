extends CharacterBody3D
## First-person player: movement, weapons, harvesting, crafting, building, health and zombification.

const W := [
	{"id": "pistol", "name": "Pistol", "glb": "res://assets/glb/weapon_pistol.glb", "mode": "semi", "dmg": 34.0,
	 "rate": 0.16, "mag": 12, "reload": 1.2, "spread": 0.006, "range": 140.0, "recoil": 0.035, "noise": 55.0,
	 "pos": Vector3(0.20, -0.20, -0.42), "snd": "pistol"},
	{"id": "uzi", "name": "UZI", "glb": "res://assets/glb/weapon_uzi.glb", "mode": "auto", "dmg": 17.0,
	 "rate": 0.075, "mag": 32, "reload": 1.6, "spread": 0.024, "range": 90.0, "recoil": 0.014, "noise": 50.0,
	 "pos": Vector3(0.20, -0.21, -0.42), "snd": "uzi"},
	{"id": "shotgun", "name": "Shotgun", "glb": "res://assets/glb/weapon_shotgun.glb", "mode": "semi", "pellets": 9,
	 "dmg": 13.0, "rate": 0.85, "mag": 6, "reload": 2.4, "spread": 0.065, "range": 45.0, "recoil": 0.09,
	 "noise": 70.0, "pos": Vector3(0.17, -0.22, -0.42), "snd": "shotgun"},
	{"id": "rifle", "name": "Rifle", "glb": "res://assets/glb/weapon_rifle.glb", "mode": "auto", "dmg": 38.0,
	 "rate": 0.11, "mag": 30, "reload": 2.0, "spread": 0.009, "range": 220.0, "recoil": 0.022, "noise": 80.0,
	 "pos": Vector3(0.17, -0.22, -0.40), "snd": "rifle"},
	{"id": "knife", "name": "Knife", "glb": "res://assets/glb/weapon_knife.glb", "mode": "melee", "dmg": 55.0,
	 "rate": 0.45, "range": 2.3, "knock": 1.5, "pos": Vector3(0.22, -0.22, -0.40)},
	{"id": "bat", "name": "Bat", "glb": "res://assets/glb/weapon_bat.glb", "mode": "melee", "dmg": 40.0,
	 "rate": 0.7, "range": 2.8, "knock": 10.0, "pos": Vector3(0.26, -0.30, -0.36)},
]
const SANDBAG_RECIPE := {"fibre": 1, "stone": 2}

var head: Node3D
var cam: Camera3D
var pivot: Node3D
var vm: Node3D
var muzzle: Node3D
var flash: Node3D
var slide: Node3D
var mag_node: Node3D
var base_pos := Vector3.ZERO
var ads_pos := Vector3.ZERO

var yaw := 0.0
var pitch := 0.0
var recoil_off := 0.0
var sens := 0.0022
var sway := Vector2.ZERO
var kick := 0.0
var bob_t := 0.0
var wobble_t := 0.0
var swing_t := 0.0

var hp := 100.0
var zomb := 0.0
var dead := false
var last_hurt := -100.0
var hurt_flash := 0.0
var hit_marker := 0.0
var head_marker := false
var inv := {"wood": 0, "stone": 0, "metal": 0, "fibre": 0, "sandbags": 20}
var cur := 0
var ammo: Array = []
var fire_cd := 0.0
var reloading := 0.0
var aiming := false
var crouching := false
var step_t := 0.0
var broadcast_cd := 0.0
var ping_marker := Vector3.INF
var ping_t := 0.0

var vehicle = null
var near_vehicle = null
var interact_target = null
var interact_kind := ""
var interact_label := ""
var talk_open := false
var nightvision := false
var _cam_bob := 0.0
var talk_npc = null
var third_person := false
var sprinting := false
var _vyaw := 0.0
var gun_kick := 0.0
var build_mode := false
var build_kind := 0
var build_rot := 0
var build_valid := false
var build_slot := {}
var ghost: Node3D
var ghost_mat_ok: StandardMaterial3D
var ghost_mat_bad: StandardMaterial3D
var wheel_open := false
var wheel_vec := Vector2.ZERO
var craft_open := false
var dev_open := false
var driver_body: Node3D
var map_open := false

func _ready() -> void:
	Game.player = self
	process_physics_priority = 10   # move after vehicles so the seat never lags
	collision_layer = Game.L_PLAYER
	collision_mask = Game.L_WORLD | Game.L_STRUCT | Game.L_ZOMBIE
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.04
	cam.far = 700.0
	cam.current = true
	head.add_child(cam)
	pivot = Node3D.new()
	cam.add_child(pivot)
	for w in W:
		ammo.append(w.get("mag", 0))
	ghost_mat_ok = _ghost_mat(Color(0.3, 1.0, 0.4, 0.38))
	ghost_mat_bad = _ghost_mat(Color(1.0, 0.25, 0.2, 0.38))
	yaw = randf() * TAU
	equip(0)

func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m

func captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func ui_blocking() -> bool:
	return craft_open or dead or dev_open or Game.menu_open or talk_open

# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and captured():
		var rel: Vector2 = event.relative
		if wheel_open:
			wheel_vec += rel
			return
		var s: float = sens * Settings.get_v("sensitivity") * (0.6 if aiming else 1.0)
		yaw -= rel.x * s
		pitch = clampf(pitch - rel.y * s * (-1.0 if Settings.get_v("invert_y") else 1.0), -1.5, 1.5)
		sway += rel
		sway = sway.limit_length(60.0)
	elif event is InputEventMouseButton and event.pressed:
		if not captured():
			if not ui_blocking():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			if build_mode:
				build_kind = posmod(build_kind + step, Game.world.PIECES.size())
				_make_ghost()
			else:
				var n := cur
				for i in W.size():
					n = posmod(n + step, W.size())
					if _can_equip(n):
						break
				equip(n)

# ---------------------------------------------------------------- movement
func _physics_process(dt: float) -> void:
	if dead:
		return
	if vehicle:
		yaw += vehicle.rotation.y - _vyaw
		_vyaw = vehicle.rotation.y
		rotation.y = yaw
		head.rotation.x = pitch
		head.position.y = 1.62
		global_position = vehicle.seat_global() + Vector3(0, 0.72 - 1.62, 0)
		velocity = Vector3.ZERO
		sprinting = false
		return
	rotation.y = yaw
	head.rotation.x = pitch
	var cap := captured() and not wheel_open
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if cap else Vector2.ZERO
	if zomb >= 50.0:
		input = input.rotated(sin(wobble_t * 1.7) * 0.4 * clampf((zomb - 40.0) / 60.0, 0.0, 1.0))
	crouching = cap and Input.is_action_pressed("crouch")
	var sprint := cap and Input.is_action_pressed("sprint") and not crouching and input.y < -0.1 and not aiming
	sprinting = sprint and input.length() > 0.1
	var speed := 2.6 if crouching else (8.0 if sprint else 5.0)
	if aiming:
		speed = minf(speed, 3.2)
	if global_position.y < -0.4:
		speed *= 0.5
	var wish := (transform.basis * Vector3(input.x, 0, input.y))
	wish.y = 0.0
	wish = wish.normalized() * speed * minf(input.length(), 1.0)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, wish.x, 55.0 * dt)
		velocity.z = move_toward(velocity.z, wish.z, 55.0 * dt)
		if cap and Input.is_action_just_pressed("jump"):
			velocity.y = 6.2
	else:
		velocity.x = lerpf(velocity.x, wish.x, 2.5 * dt)
		velocity.z = lerpf(velocity.z, wish.z, 2.5 * dt)
		velocity.y -= 20.0 * dt
	move_and_slide()
	head.position.y = lerpf(head.position.y, 1.05 if crouching else 1.62, 12.0 * dt)
	if sprint and is_on_floor() and input.length() > 0.1:
		step_t += dt
		if step_t > 0.4:
			step_t = 0.0
			Game.make_noise(global_position, 9.0)
	if is_on_floor() and input.length() > 0.1:
		bob_t += dt * speed * 1.7
	if global_position.y < -30.0:
		respawn()

# ---------------------------------------------------------------- per frame
func _process(dt: float) -> void:
	wobble_t += dt
	hit_marker = maxf(hit_marker - dt, 0.0)
	hurt_flash = maxf(hurt_flash - dt * 2.0, 0.0)
	broadcast_cd = maxf(broadcast_cd - dt, 0.0)
	ping_t = maxf(ping_t - dt, 0.0)
	if dead:
		return
	if Time.get_ticks_msec() / 1000.0 - last_hurt > 6.0:
		hp = minf(100.0, hp + 2.0 * dt)
	var cap := captured()
	_actions(cap)
	_weapon(dt, cap)
	_build(cap)
	_camera(dt)

func _actions(cap: bool) -> void:
	if Input.is_action_just_pressed("dev"):
		dev_open = not dev_open
		if dev_open:
			craft_open = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("craft"):
		craft_open = not craft_open
		if craft_open:
			build_mode = false
			_clear_ghost()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not cap:
		return
	if Input.is_action_just_pressed("map"):
		map_open = not map_open
	if Input.is_action_just_pressed("nightvision"):
		nightvision = not nightvision
		Sfx.play("click", -6.0, 0.6 if nightvision else 0.5)
	_find_interact()
	if Input.is_action_just_pressed("interact"):
		if vehicle:
			exit_vehicle()
		elif interact_kind == "vehicle":
			enter_vehicle(interact_target)
		elif interact_kind == "door":
			interact_target.toggle()
		elif interact_kind == "npc":
			talk_to(interact_target)
	if Input.is_action_just_pressed("camera") and vehicle:
		third_person = not third_person
		if driver_body:
			driver_body.visible = third_person
	if Input.is_action_just_pressed("ping"):
		ping_marker = global_position
		ping_t = 12.0
		Sfx.play("ping")
		Game.msg("Team ping: I'm at %s" % Game.sector(global_position), Color(0.5, 0.9, 1.0))
	if Input.is_action_just_pressed("broadcast"):
		if broadcast_cd > 0.0:
			Game.msg("Broadcast recharging (%ds)" % ceili(broadcast_cd), Color(0.7, 0.7, 0.7))
		else:
			broadcast_cd = 20.0
			Sfx.play("ping", 0.0, 0.7)
			Game.msg("OPEN BROADCAST to all players: I'm at %s. Come get me." % Game.sector(global_position), Color(1.0, 0.75, 0.3))
			if Game.zombies_enabled:
				Game.make_noise(global_position, 70.0)
	for i in 6:
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			build_mode = false
			_clear_ghost()
			equip(i)
	if Input.is_action_just_pressed("debug_antidote"):
		zomb = 0.0
		Game.msg("Debug: antidote. Zombification reset.", Color(0.6, 1, 0.6))
	if Input.is_action_just_pressed("debug_bags"):
		inv.sandbags += 20
		Game.msg("Debug: +20 sandbags", Color(0.8, 0.8, 0.8))
	var d = Game.world.director
	if d:
		if Input.is_action_just_pressed("debug_spawn10"):
			d.stress(10)
		if Input.is_action_just_pressed("debug_spawn50"):
			d.stress(50)
		if Input.is_action_just_pressed("debug_clear"):
			d.clear_all()
	elif Input.is_action_just_pressed("debug_spawn10") or Input.is_action_just_pressed("debug_spawn50"):
		Game.msg("No zombies in this mode. Pick Zombie Royale for the stress test.", Color(0.8, 0.8, 0.8))

# ---------------------------------------------------------------- weapons
func _can_equip(i: int) -> bool:
	return zomb < 100.0 or W[i].mode == "melee"

func equip(i: int) -> void:
	if not _can_equip(i):
		Game.msg("You have turned. Guns are useless to you now.", Color(0.6, 1.0, 0.5))
		return
	if vm:
		vm.queue_free()
	cur = i
	reloading = 0.0
	var w: Dictionary = W[i]
	vm = load(w.glb).instantiate()
	pivot.add_child(vm)
	var b := Basis(Vector3.UP, PI)
	if w.id == "bat":
		b = Basis(Vector3.RIGHT, deg_to_rad(62)) * Basis(Vector3.FORWARD, deg_to_rad(-15)) * b
	elif w.id == "knife":
		b = Basis(Vector3.RIGHT, deg_to_rad(12)) * b
	vm.basis = b
	for mi in vm.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle = vm.find_child("MUZZLE", true, false)
	slide = vm.find_child("Slide", true, false)
	mag_node = vm.find_child("Mag", true, false)
	_add_hand(vm, Vector3.ZERO, w.mode != "melee")
	var gl: Node3D = vm.find_child("GRIP_L", true, false)
	if gl and w.id != "bat":
		_add_hand(vm, vm.global_transform.affine_inverse() * gl.global_position, true)
	base_pos = w.pos
	ads_pos = base_pos
	var aim_n: Node3D = vm.find_child("AIM", true, false)
	if aim_n:
		var p_vm: Vector3 = vm.global_transform.affine_inverse() * aim_n.global_position
		ads_pos = Vector3(0, -0.012, -0.24) - vm.basis * p_vm
	flash = null
	if muzzle:
		flash = Node3D.new()
		var fm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.07, 0.14)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.4)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.material = m
		fm.mesh = bm
		fm.position.z = 0.06
		fm.rotation.z = 0.785
		flash.add_child(fm)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.5)
		light.omni_range = 5.0
		light.light_energy = 2.0
		flash.add_child(light)
		muzzle.add_child(flash)
		flash.visible = false
	vm.position = base_pos + Vector3(0, -0.3, 0)

func _add_hand(parent: Node3D, at: Vector3, arm := false) -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.58, 0.40, 0.30)
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color(0.035, 0.05, 0.10)
	var cuff := StandardMaterial3D.new()
	cuff.albedo_color = Color(0.92, 0.92, 0.90)
	var parts: Array = [[Vector3(0.07, 0.085, 0.10), at + Vector3(0, -0.035, 0), skin]]
	if arm:
		# forearm reaching back towards the camera (weapon space: -Z points at the player)
		parts.append([Vector3(0.078, 0.082, 0.025), at + Vector3(0.0, -0.045, -0.06), cuff])
		parts.append([Vector3(0.085, 0.09, 0.34), at + Vector3(0.0, -0.08, -0.24), sleeve])
	for prt in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = prt[0]
		bm.material = prt[2]
		mi.mesh = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = prt[1]
		parent.add_child(mi)

func _weapon(dt: float, cap: bool) -> void:
	var w: Dictionary = W[cur]
	fire_cd -= dt
	if reloading > 0.0:
		reloading -= dt
		if reloading <= 0.0:
			ammo[cur] = w.mag
			Sfx.play("click", -4, 0.8)
	var active := cap and not build_mode and not wheel_open and vehicle == null
	aiming = active and Input.is_action_pressed("aim") and w.mode != "melee"
	if active:
		if Input.is_action_just_pressed("reload"):
			start_reload()
		var want = Input.is_action_pressed("fire") if w.mode == "auto" else Input.is_action_just_pressed("fire")
		if want and fire_cd <= 0.0 and reloading <= 0.0:
			fire()
	# viewmodel motion
	if vm:
		vm.visible = vehicle == null
		var target := ads_pos if aiming else base_pos
		if sprinting and w.mode != "melee":
			target += Vector3(-0.06, -0.07, 0.04)
		var moving := Vector2(velocity.x, velocity.z).length() > 0.5 and is_on_floor()
		if moving:
			target += Vector3(cos(bob_t) * 0.009, absf(sin(bob_t)) * 0.013, 0) * (0.25 if aiming else 1.0)
		sway = sway.lerp(Vector2.ZERO, minf(10.0 * dt, 1.0))
		target += Vector3(-sway.x, sway.y, 0) * (0.0002 if aiming else 0.0006)
		target.z += kick * 0.06
		kick = move_toward(kick, 0.0, dt * 9.0)
		if reloading > 0.0:
			target.y -= 0.14
		vm.position = vm.position.lerp(target, minf(18.0 * dt, 1.0))
		swing_t = maxf(swing_t - dt / maxf(w.get("rate", 0.5), 0.1), 0.0)
		var s := sin(swing_t * PI)
		gun_kick = move_toward(gun_kick, 0.0, dt * 7.0)
		var sprint_rot := Vector3(-0.35, 0.7, 0.15) if sprinting and w.mode != "melee" else Vector3.ZERO
		if w.id == "bat":
			pivot.rotation = Vector3(-0.5 * s, 1.1 * s, 0.4 * s)
		else:
			var target_rot := sprint_rot + Vector3(gun_kick * 0.18, 0, gun_kick * randf_range(-0.03, 0.03))
			pivot.rotation = pivot.rotation.lerp(target_rot, minf(14.0 * dt, 1.0)) if gun_kick < 0.01 else target_rot
			pivot.position = Vector3(0, 0, -0.28 * s) if w.id == "knife" else Vector3.ZERO

func start_reload() -> void:
	var w: Dictionary = W[cur]
	if w.mode == "melee" or reloading > 0.0 or ammo[cur] >= w.mag:
		return
	reloading = w.reload
	Sfx.play("reload", -3.0)
	if mag_node:
		var rest := mag_node.position
		var tw := create_tween()
		tw.tween_property(mag_node, "position", rest + Vector3(0, -0.25, 0), w.reload * 0.35)
		tw.tween_property(mag_node, "position", rest, w.reload * 0.4)

func fire() -> void:
	var w: Dictionary = W[cur]
	if w.mode == "melee":
		_melee()
		return
	if ammo[cur] <= 0:
		Sfx.play("click")
		fire_cd = 0.25
		start_reload()
		return
	ammo[cur] -= 1
	fire_cd = w.rate
	Sfx.play(w.snd, -3.0)
	Game.make_noise(global_position, w.noise)
	var space := get_world_3d().direct_space_state
	var origin := cam.global_position
	var bt := cam.global_transform.basis
	var spread: float = w.spread * (0.35 if aiming else 1.0) * (1.0 if is_on_floor() else 1.8)
	var muzzle_pos := muzzle.global_position if muzzle else origin
	for p in w.get("pellets", 1):
		var dir := (-bt.z + bt.x * randf_range(-spread, spread) + bt.y * randf_range(-spread, spread)).normalized()
		var end: Vector3 = origin + dir * w.range
		var q := PhysicsRayQueryParameters3D.create(origin, end, Game.L_WORLD | Game.L_STRUCT | Game.L_ZOMBIE, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit:
			end = hit.position
			var r: int = Game.world.server_shot_hit(hit, w.dmg, dir, 0.0)
			if r > 0:
				hit_marker = 0.15
				head_marker = r == 2
		if p < 3:
			Game.world.tracer(muzzle_pos, end)
	recoil_off += w.recoil * (0.55 if aiming else 1.0)
	yaw += randf_range(-1.0, 1.0) * w.recoil * 0.25
	pitch = clampf(pitch + w.recoil * 0.35, -1.5, 1.5)
	kick = 1.0
	gun_kick = 1.0
	var ej: Node3D = vm.find_child("EJECT", true, false) if vm else null
	if ej:
		Game.world.casing(ej.global_position, (cam.global_transform.basis.x + cam.global_transform.basis.y * 0.6).normalized(), w.id == "shotgun")
	if muzzle:
		Game.world.smoke(muzzle.global_position)
	if w.id == "shotgun":
		var pump: Node3D = vm.find_child("Pump", true, false)
		if pump:
			var rest := pump.position
			var tw2 := create_tween()
			tw2.tween_interval(0.25)
			tw2.tween_property(pump, "position", rest + Vector3(0, 0, -0.08), 0.12)
			tw2.tween_property(pump, "position", rest, 0.12)
	if flash:
		flash.visible = true
		flash.rotation.z = randf() * TAU
		get_tree().create_timer(0.045).timeout.connect(func(): if is_instance_valid(flash): flash.visible = false)
	if slide:
		var rest := slide.position
		var tw := create_tween()
		tw.tween_property(slide, "position", rest + Vector3(0, 0, -0.035), 0.03)
		tw.tween_property(slide, "position", rest, 0.06)
	if ammo[cur] == 0:
		start_reload()

func _melee() -> void:
	var w: Dictionary = W[cur]
	fire_cd = w.rate
	swing_t = 1.0
	Sfx.play("swing", -6.0)
	get_tree().create_timer(0.1).timeout.connect(_melee_hit)

func _melee_hit() -> void:
	if dead:
		return
	var w: Dictionary = W[cur]
	if w.mode != "melee":
		return
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q = PhysicsRayQueryParameters3D.create(origin, origin + dir * w.range,
		Game.L_WORLD | Game.L_STRUCT | Game.L_ZOMBIE | Game.L_HARVEST, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit:
		return
	var col: Object = hit.collider
	if col.has_method("take_damage"):
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		var knock: Vector3 = flat * w.knock + Vector3.UP * (2.5 if w.knock > 5.0 else 0.0)
		var r: int = Game.world.server_shot_hit(hit, w.dmg, dir, 0.0, knock)
		Sfx.play3d("hit", hit.position, 2.0)
		hit_marker = 0.15
		head_marker = r == 2
		Game.make_noise(global_position, 10.0)
		return
	var power := 1
	if w.id == "bat" and col.has_meta("owner_root") and col.get_meta("owner_root").get_meta("res", "") == "wood":
		power = 2
	var got: Dictionary = Game.world.server_harvest(col, power)
	if got.is_empty():
		Sfx.play3d("hit", hit.position, -6.0, 1.4)
		return
	var parts: Array = []
	for k in got:
		inv[k] += got[k]
		parts.append("+%d %s" % [got[k], k])
	Game.msg(", ".join(parts), Color(0.85, 1.0, 0.75))
	var res: String = col.get_meta("owner_root").get_meta("res") if col.has_meta("owner_root") else ""
	Sfx.play3d("rock" if res == "stone" else "chop", hit.position)
	Game.world.puff(hit.position, Color(0.5, 0.48, 0.45) if res == "stone" else Color(0.45, 0.32, 0.18), 6)

# ---------------------------------------------------------------- crafting
func craft(what: String, n: int) -> void:
	var made := 0
	if what == "sandbag":
		for k in n:
			if inv.fibre >= SANDBAG_RECIPE.fibre and inv.stone >= SANDBAG_RECIPE.stone:
				inv.fibre -= SANDBAG_RECIPE.fibre
				inv.stone -= SANDBAG_RECIPE.stone
				inv.sandbags += 1
				made += 1
	if made > 0:
		Sfx.play("craft")
		Game.msg("Crafted %d sandbag%s" % [made, "" if made == 1 else "s"], Color(0.9, 0.9, 0.7))
	else:
		Game.msg("Not enough materials: a sandbag needs 1 fibre (bushes) and 2 stone (rocks).", Color(1, 0.6, 0.5))

# ---------------------------------------------------------------- building
func _build(cap: bool) -> void:
	if not cap:
		wheel_open = false
		return
	if Input.is_action_just_pressed("build"):
		wheel_open = true
		wheel_vec = Vector2.ZERO
	if wheel_open and Input.is_action_just_released("build"):
		wheel_open = false
		if wheel_vec.length() > 40.0:
			var a := wheel_vec.angle()  # 0 = right, PI/2 = down
			var seg := posmod(roundi((a + PI / 2.0) / (PI / 2.0)), 4)  # up=0, right=1, down=2, left=3
			build_kind = seg
			build_mode = true
		else:
			build_mode = not build_mode
		if build_mode:
			_make_ghost()
		else:
			_clear_ghost()
	if not build_mode:
		return
	if Input.is_action_just_pressed("aim"):
		build_mode = false
		_clear_ghost()
		return
	if Input.is_action_just_pressed("reload"):
		build_rot = (build_rot + 1) % 4
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 14.0, Game.L_WORLD | Game.L_STRUCT, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var cost: int = Game.world.PIECES[build_kind].cost
	if not hit:
		build_valid = false
		if ghost:
			ghost.visible = false
		return
	build_slot = Game.world.piece_slot(build_kind, hit.position, build_rot)
	var xf: Transform3D = build_slot.xform
	var near_self := Vector2(xf.origin.x - global_position.x, xf.origin.z - global_position.z).length() < 1.0
	if Game.dev_free_build:
		cost = 0
	build_valid = build_slot.free and build_slot.dry and inv.sandbags >= cost and not near_self
	if ghost:
		ghost.visible = true
		ghost.global_transform = xf
		for mi in ghost.get_children():
			(mi as MeshInstance3D).material_override = ghost_mat_ok if build_valid else ghost_mat_bad
	if Input.is_action_just_pressed("fire"):
		if build_valid:
			Game.world.server_build(build_kind, build_slot)
			inv.sandbags -= cost
		elif inv.sandbags < cost:
			Game.msg("Need %d sandbags (you have %d). Craft them with Q." % [cost, inv.sandbags], Color(1, 0.6, 0.5))
		elif not build_slot.free:
			Game.msg("Something is already built there.", Color(1, 0.6, 0.5))
		elif not build_slot.dry:
			Game.msg("Can't build in the water.", Color(1, 0.6, 0.5))

func _make_ghost() -> void:
	_clear_ghost()
	ghost = Node3D.new()
	Game.world.add_child(ghost)
	var d = Game.asset(Game.world.PIECES[build_kind].glb)
	for m in d.meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = m[0]
		mi.transform = m[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = ghost_mat_ok
		ghost.add_child(mi)

func _clear_ghost() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null

# ---------------------------------------------------------------- camera
func _camera(dt: float) -> void:
	recoil_off = lerpf(recoil_off, 0.0, minf(7.0 * dt, 1.0))
	var k := clampf((zomb - 45.0) / 55.0, 0.0, 1.0)
	cam.rotation.x = recoil_off + sin(wobble_t * 0.9) * 0.035 * k
	cam.rotation.z = sin(wobble_t * 1.3) * 0.07 * k
	var fov: float = Settings.get_v("fov")
	cam.fov = lerpf(cam.fov, fov * 0.7 if aiming else fov, minf(12.0 * dt, 1.0))
	cam.far = Settings.get_v("view_distance") + 150.0
	var want := Vector3.ZERO
	if vehicle and third_person:
		want = vehicle.cam_offset
		var from := head.global_position
		var to := head.global_transform * want
		var q := PhysicsRayQueryParameters3D.create(from, to, Game.L_WORLD | Game.L_STRUCT, [get_rid(), vehicle.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			want = want * maxf(from.distance_to(hit.position) - 0.3, 0.5) / want.length()
	if Settings.get_v("bodycam") and vehicle == null:
		# chest-mounted camera: lower, wider, bounces and sways with every step
		var moving := Vector2(velocity.x, velocity.z).length()
		_cam_bob += dt * (6.0 + moving * 1.6)
		var k2 := clampf(moving / 5.0, 0.0, 1.5)
		want += Vector3(sin(_cam_bob * 0.5) * 0.03 * k2, -0.22 + absf(sin(_cam_bob)) * 0.05 * k2, 0.05)
		cam.rotation.z += sin(_cam_bob * 0.5) * 0.025 * k2
		cam.fov = lerpf(cam.fov, (fov + 14.0) * (0.7 if aiming else 1.0), minf(12.0 * dt, 1.0))
	cam.position = cam.position.lerp(want, minf(10.0 * dt, 1.0))

# ---------------------------------------------------------------- health
func _make_driver_body() -> Node3D:
	var root := Node3D.new()
	var parts := [  # [size, position, colour]; seated pose facing +Z (vehicle forward), origin at the hips
		[Vector3(0.40, 0.55, 0.24), Vector3(0, 0.30, -0.02), Color(0.035, 0.05, 0.10)],      # jacket
		[Vector3(0.12, 0.30, 0.01), Vector3(0, 0.40, 0.11), Color(0.92, 0.92, 0.90)],        # shirt
		[Vector3(0.045, 0.28, 0.012), Vector3(0, 0.38, 0.12), Color(0.45, 0.04, 0.04)],      # tie
		[Vector3(0.10, 0.10, 0.10), Vector3(0, 0.62, 0), Color(0.62, 0.44, 0.33)],          # neck
		[Vector3(0.22, 0.25, 0.24), Vector3(0, 0.78, 0), Color(0.62, 0.44, 0.33)],          # head
		[Vector3(0.24, 0.06, 0.26), Vector3(0, 0.93, -0.01), Color(0.22, 0.14, 0.08)],      # hair
		[Vector3(0.24, 0.16, 0.04), Vector3(0, 0.84, -0.12), Color(0.22, 0.14, 0.08)],
		[Vector3(0.36, 0.16, 0.48), Vector3(0, 0.0, 0.2), Color(0.035, 0.05, 0.10)],        # thighs
		[Vector3(0.34, 0.42, 0.14), Vector3(0, -0.18, 0.42), Color(0.035, 0.05, 0.10)],     # shins
		[Vector3(0.34, 0.08, 0.24), Vector3(0, -0.38, 0.5), Color(0.02, 0.02, 0.02)],       # shoes
		[Vector3(0.10, 0.10, 0.42), Vector3(0.24, 0.40, 0.18), Color(0.035, 0.05, 0.10)],   # arms to the wheel
		[Vector3(0.10, 0.10, 0.42), Vector3(-0.24, 0.40, 0.18), Color(0.035, 0.05, 0.10)],
		[Vector3(0.09, 0.09, 0.09), Vector3(0.22, 0.40, 0.42), Color(0.62, 0.44, 0.33)],
		[Vector3(0.09, 0.09, 0.09), Vector3(-0.22, 0.40, 0.42), Color(0.62, 0.44, 0.33)],
	]
	for prt in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = prt[0]
		var m := StandardMaterial3D.new()
		m.albedo_color = prt[2]
		bm.material = m
		mi.mesh = bm
		mi.position = prt[1]
		root.add_child(mi)
	return root

## The nearest thing E can use: a vehicle, a door or Bjørn.
func _find_interact() -> void:
	interact_target = null
	interact_kind = ""
	interact_label = ""
	near_vehicle = null
	if vehicle:
		return
	var best := INF
	var w = Game.world
	for v in w.vehicles:
		var d: float = v.global_position.distance_to(global_position)
		if d < 3.2 and d < best:
			best = d
			interact_target = v
			interact_kind = "vehicle"
			interact_label = "get in the %s" % {"tike": "Tike", "bike": "motorbike", "atv": "ATV", "sedan": "sport sedan", "heli": "helicopter"}.get(v.kind, v.kind)
	for door in w.doors:
		var d: float = door.centre().distance_to(global_position + Vector3(0, 1.0, 0))
		if d < 2.3 and d < best:
			best = d
			interact_target = door
			interact_kind = "door"
			interact_label = door.label() if door.has_method("label") else ("close the door" if door.open else "open the door")
	if w.npc:
		var d: float = w.npc.global_position.distance_to(global_position)
		if d < 3.0 and d < best:
			best = d
			interact_target = w.npc
			interact_kind = "npc"
			interact_label = "talk to %s" % w.npc.npc_name
	if interact_kind == "vehicle":
		near_vehicle = interact_target

func talk_to(n) -> void:
	talk_open = true
	talk_npc = n
	n.wave()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func end_talk() -> void:
	talk_open = false
	talk_npc = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func enter_vehicle(v) -> void:
	vehicle = v
	if driver_body == null:
		driver_body = _make_driver_body()
	if driver_body.get_parent():
		driver_body.get_parent().remove_child(driver_body)
	v.model.add_child(driver_body)
	driver_body.position = v.model.to_local(v.seat_global())
	driver_body.visible = third_person
	v.set_driver(self)
	_vyaw = v.rotation.y
	yaw = v.rotation.y + PI
	pitch = -0.1
	collision_layer = 0
	collision_mask = 0
	build_mode = false
	_clear_ghost()
	aiming = false
	Game.msg("W/S drive, A/D steer, Space brake, G horn, E get out, V camera", Color(0.8, 0.95, 1.0))

func exit_vehicle() -> void:
	if vehicle == null:
		return
	var v = vehicle
	vehicle = null
	v.set_driver(null)
	if driver_body:
		driver_body.visible = false
	var p: Vector3 = v.exit_global()
	p.y = maxf(p.y, Game.world.height_at(p.x, p.z)) + 0.1
	global_position = p
	collision_layer = Game.L_PLAYER
	collision_mask = Game.L_WORLD | Game.L_STRUCT | Game.L_ZOMBIE
	cam.position = Vector3.ZERO
	velocity = Vector3.ZERO

func is_targetable() -> bool:
	return not dead and zomb < 100.0 and Game.dev_zombies_chase

func damage(amount: float) -> void:
	if dead or Game.dev_god:
		return
	hp -= amount
	last_hurt = Time.get_ticks_msec() / 1000.0
	hurt_flash = minf(hurt_flash + amount * 0.05, 0.8)
	if hp <= 0.0:
		die()

func zombie_hit(dmg: float, infection: float) -> void:
	if dead:
		return
	var before := zomb
	if not Game.dev_god:
		zomb = minf(100.0, zomb + infection)
	Sfx.play("hurt")
	damage(dmg)
	if before < 50.0 and zomb >= 50.0:
		Game.msg("Zombification 50%: you're staggering.", Color(0.6, 1.0, 0.5))
	if before < 100.0 and zomb >= 100.0:
		Game.msg("You have turned. Melee only. The zombies ignore you now.", Color(0.5, 1.0, 0.4))
		if W[cur].mode != "melee":
			equip(5)

func die() -> void:
	exit_vehicle()
	dead = true
	build_mode = false
	_clear_ghost()
	craft_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("death", 2.0, 0.85)

func respawn() -> void:
	var near := Vector3.ZERO
	var radius := 120.0
	var st = Game.world.storm
	if st:
		near = Vector3(st.center.x, 0, st.center.y)
		radius = st.radius * 0.6
	global_position = Game.world.find_spawn(near, radius) + Vector3(0, 0.3, 0)
	velocity = Vector3.ZERO
	hp = 100.0
	zomb = 0.0
	dead = false
	for i in W.size():
		ammo[i] = W[i].get("mag", 0)
	equip(0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
