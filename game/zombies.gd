extends Node3D
## Zombie director: DayZ-style population, detection, scream chains, escalation and the stress test.

const ZombieScript := preload("res://game/zombie.gd")
const MAX_CHASERS := 90

var zombies: Array = []
var meshes: Array = []
var kills := 0
var target_pop := 110
var minutes := 0.0
var _check_i := 0
var _t := 0.0
var _sep_t := 0.0
var _pop_t := 0.0
var _horde_t := 75.0
var horde_count := 0

func _ready() -> void:
	meshes = [ZombieScript.build_mesh(Color(0.35, 0.38, 0.45), Color(0.25, 0.22, 0.20)),
			  ZombieScript.build_mesh(Color(0.50, 0.30, 0.25), Color(0.20, 0.24, 0.30)),
			  ZombieScript.build_mesh(Color(0.55, 0.53, 0.45), Color(0.30, 0.28, 0.22))]
	Game.noise.connect(_on_noise)
	var w = Game.world
	var groups := 0
	while zombies.size() < target_pop and groups < 400:
		groups += 1
		var p := _far_point(60.0)
		if p != Vector3.INF:
			spawn_group(p, randi_range(1, 5))

func spawn(pos: Vector3, chase := false) -> CharacterBody3D:
	var z := CharacterBody3D.new()
	z.set_script(ZombieScript)
	add_child(z)
	z.setup(meshes[randi() % meshes.size()], self)
	z.global_position = pos + Vector3(0, 0.05, 0)
	z.rotation.y = randf() * TAU
	zombies.append(z)
	if chase:
		z.chase()
	return z

func spawn_group(center: Vector3, n: int, chase := false) -> void:
	var w = Game.world
	for i in n:
		var p := center + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		if w.is_land(p.x, p.z, 0.5, 40.0):
			p.y = w.height_at(p.x, p.z)
			spawn(p, chase)

func _far_point(min_dist: float) -> Vector3:
	var w = Game.world
	var pl = Game.player
	for i in 60:
		var x = randf_range(-w.SIZE * 0.45, w.SIZE * 0.45)
		var z = randf_range(-w.SIZE * 0.45, w.SIZE * 0.45)
		if not w.is_land(x, z, 1.0, 30.0):
			continue
		if pl and Vector2(x - pl.global_position.x, z - pl.global_position.z).length() < min_dist:
			continue
		return Vector3(x, w.height_at(x, z), z)
	return Vector3.INF

func active_count() -> int:
	var n := 0
	for z in zombies:
		if z.state == ZombieScript.CHASE or z.state == ZombieScript.INVESTIGATE:
			n += 1
	return n

## Stress test: n zombies spawn 30-45 m around the player, already chasing.
func stress(n: int) -> void:
	var pl = Game.player
	var w = Game.world
	var made := 0
	for i in n * 4:
		if made >= n:
			break
		var a := randf() * TAU
		var r := randf_range(30.0, 45.0)
		var p = pl.global_position + Vector3(cos(a) * r, 0, sin(a) * r)
		if w.is_land(p.x, p.z, 0.3, 40.0):
			p.y = w.height_at(p.x, p.z)
			spawn(p, true)
			made += 1
	Game.msg("Stress test: +%d chasing zombies" % made, Color(1, 0.7, 0.4))

func clear_all() -> void:
	for z in zombies:
		if is_instance_valid(z):
			z.queue_free()
	zombies.clear()
	Game.msg("All zombies removed", Color(0.8, 0.8, 0.8))

func on_dead(z) -> void:
	zombies.erase(z)
	kills += 1

func alert(z, scream: bool) -> void:
	if not is_instance_valid(z) or z.state == ZombieScript.DEAD or z.alerted:
		return
	z.alerted = true
	if active_count() >= MAX_CHASERS:
		z.investigate(Game.player.global_position)
		return
	z.chase()
	if scream:
		Sfx.play3d("scream", z.global_position + Vector3(0, 1.6, 0), 2.0)
		for o in zombies:
			if o != z and not o.alerted and o.state != ZombieScript.DEAD \
					and o.global_position.distance_squared_to(z.global_position) < 22.0 * 22.0:
				get_tree().create_timer(randf_range(0.2, 1.0)).timeout.connect(alert.bind(o, randf() < 0.3))

func _on_noise(pos: Vector3, radius: float) -> void:
	for z in zombies:
		if z.state == ZombieScript.IDLE or z.state == ZombieScript.INVESTIGATE:
			var d: float = z.global_position.distance_to(pos)
			if d < radius * 0.5:
				alert(z, randf() < 0.5)
			elif d < radius:
				z.investigate(pos)

func _physics_process(dt: float) -> void:
	var pl = Game.player
	if pl == null:
		return
	_t += dt
	if _t > 0.1:
		_t = 0.0
		_detect(pl)
	_sep_t += dt
	if _sep_t > 0.15:
		_sep_t = 0.0
		_separate()
	# Zombie Royale escalation: population creeps up, hordes arrive on a timer
	minutes += dt / 60.0
	target_pop = mini(110 + int(minutes * 8.0), 260)
	_pop_t += dt
	if _pop_t > 2.0:
		_pop_t = 0.0
		if zombies.size() < target_pop:
			var p := _far_point(70.0)
			if p != Vector3.INF:
				spawn_group(p, randi_range(2, 5))
	_horde_t -= dt
	if _horde_t <= 0.0 and pl.is_targetable():
		horde_count += 1
		_horde_t = maxf(45.0, 80.0 - horde_count * 4.0)
		var a := randf() * TAU
		var c = pl.global_position + Vector3(cos(a), 0, sin(a)) * 65.0
		var w = Game.world
		if w.is_land(c.x, c.z, 0.5, 40.0):
			spawn_group(c, mini(6 + horde_count * 2, 30), true)
			Game.msg("HORDE incoming from %s" % Game.sector(c), Color(1, 0.4, 0.3))

func _detect(pl) -> void:
	if not pl.is_targetable() or zombies.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var eye: Vector3 = pl.global_position + Vector3(0, 1.5, 0)
	var sight: float = 18.0 if pl.crouching else 32.0
	var n := mini(30, zombies.size())
	for k in n:
		_check_i = (_check_i + 1) % zombies.size()
		var z = zombies[_check_i]
		if z.state != ZombieScript.IDLE and z.state != ZombieScript.INVESTIGATE:
			continue
		var to: Vector3 = eye - z.global_position
		var d2 := to.length_squared()
		if d2 > sight * sight:
			continue
		if d2 < 25.0:
			alert(z, true)
			continue
		var fwd: Vector3 = -z.global_transform.basis.z
		if fwd.dot(to.normalized()) < 0.2:
			continue
		var q = PhysicsRayQueryParameters3D.create(z.global_position + Vector3(0, 1.6, 0), eye, Game.L_WORLD | Game.L_STRUCT)
		if space.intersect_ray(q).is_empty():
			alert(z, true)

func _separate() -> void:
	var act: Array = []
	for z in zombies:
		if z.state == ZombieScript.CHASE:
			act.append(z)
			z.sep = Vector3.ZERO
	for i in act.size():
		var a = act[i]
		for j in range(i + 1, act.size()):
			var b = act[j]
			var d: Vector3 = a.global_position - b.global_position
			d.y = 0.0
			var l = d.length()
			if l < 1.1 and l > 0.001:
				var push: Vector3 = d / l * (1.1 - l)
				a.sep += push
				b.sep -= push
