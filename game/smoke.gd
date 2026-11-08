extends Node
## Automated test run: `godot -- --smoke [--shots=dir]`. Exercises the main systems, prints stats, quits.

var t := 0.0
var step := 0
var shots := ""
var max_air := 0.0
var menu = null
var start_pos := Vector3.ZERO
var shot_air := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps running while the pause menu has the game paused
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	print("SMOKE start mode=", Game.mode)

func _look_at(p: Vector3) -> void:
	var pl = Game.player
	var d: Vector3 = p - pl.head.global_position
	pl.yaw = atan2(-d.x, -d.z)
	pl.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	pl.rotation.y = pl.yaw
	pl.head.rotation.x = pl.pitch

func _shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots, name])
	print("SMOKE shot ", name)

func _process(dt: float) -> void:
	t += dt
	if "--quick" in OS.get_cmdline_user_args():
		_quick()
		return
	var pl = Game.player
	var w = Game.world
	if pl == null:
		return
	if step == 0 and t > 1.0:
		step = 1
		w.give_vehicle("tike")
		w.give_vehicle("bike")
		if w.doors.size() > 0:
			w.doors[0].toggle()
		print("SMOKE vehicles=", w.vehicles.size(), " doors=", w.doors.size(), " npc=", w.npc != null)
		var tike = w.vehicles[0]
		if tike:
			_look_at(tike.global_position + Vector3(0, 0.6, 0))
	elif step == 1 and t > 2.5:
		step = 2
		_shot("01_spawn_tike")
		pl.equip(0); pl.fire()
		pl.equip(2); pl.fire()
		pl.equip(3); pl.fire()
		pl.equip(4); pl._melee()
		pl.yaw += PI
		pl.pitch = -0.25
	elif step == 2 and t > 3.5:
		step = 3
		var aim: Vector3 = pl.global_position + (-pl.global_transform.basis.z) * 6.0
		for k in 4:
			var slot: Dictionary = w.piece_slot(k, aim + pl.global_transform.basis.x * (k * 4.0 - 6.0), 0)
			if slot.free:
				w.server_build(k, slot)
		pl.equip(3)
		pl.build_mode = true
		pl._make_ghost()
	elif step == 3 and t > 6.5:
		step = 4
		_shot("02_build")
		pl.build_mode = false
		pl._clear_ghost()
		if w.director:
			w.director.stress(50)
		pl.pitch = -0.05
	elif step == 4 and t > 10.0:
		step = 5
		_shot("03_horde")
		pl.zomb = 70.0
		pl.map_open = true
	elif step == 5 and t > 11.5:
		step = 6
		_shot("04_zombified_map")
		pl.map_open = false
		pl.zomb = 0.0
	elif step == 6 and t > 12.0:
		step = 7
		pl.enter_vehicle(w.vehicles[0])
		pl.third_person = true
		Input.action_press("move_forward")
		start_pos = w.vehicles[0].global_position
	elif step == 7 and t > 15.5:
		step = 8
		_shot("05_driving")
		Input.action_release("move_forward")
		print("SMOKE drove speed=%.1f distance=%.1f" % [w.vehicles[0].speed, w.vehicles[0].global_position.distance_to(start_pos)])
		pl.exit_vehicle()
		pl.equip(3)
		pl.yaw += 0.6
		pl.pitch = -0.15
	elif step == 8 and t > 17.0:
		step = 9
		pl.fire()
		_shot("06_rifle")
	elif step == 9 and t > 18.0:
		step = 10
		# jump test: line the Tike up with a ramp and floor it
		var v = w.vehicles[0]
		var r = w.ramps[0]
		var dir: Vector3 = r.global_transform.basis.z
		var start: Vector3 = r.global_position - dir * 16.0
		start.y = w.height_at(start.x, start.z) + 0.5
		v.global_position = start
		v.rotation.y = r.rotation.y
		v.speed = v.max_speed
		if w.director:
			w.director.clear_all()
		pl.enter_vehicle(v)
		pl.third_person = true
		pl.driver_body.visible = true
		pl.yaw = v.rotation.y + PI + 0.9
		Input.action_press("move_forward")
		max_air = 0.0
	elif step == 10:
		max_air = maxf(max_air, w.vehicles[0].air_time)
		if not shot_air and w.vehicles[0].air_time > 0.25:
			shot_air = true
			_shot("07_air")
		if t > 22.0:
			step = 11
			Input.action_release("move_forward")
			print("SMOKE ramp max_air=%.2f" % max_air)
			pl.exit_vehicle()
			var st = w.sites[0]
			var p: Vector3 = st.pos + Vector3(30, 0, 30)
			p.y = w.height_at(p.x, p.z) + 0.2
			pl.global_position = p
			_look_at(st.pos + Vector3(0, 3, 0))
	elif step == 11 and t > 23.5:
		step = 12
		_shot("08_town")
		var church = null
		for st in w.sites:
			if st.kind == "church":
				church = st
		if church:
			pl.global_position = church.pos + Basis(Vector3.UP, church.rot * PI / 2.0) * Vector3(0, 0.3, 6.0)
			_look_at(church.pos + Basis(Vector3.UP, church.rot * PI / 2.0) * Vector3(0, 2.0, -8.0))
	elif step == 12 and t > 25.0:
		step = 13
		_shot("09_church_inside")
		var c: Vector3 = w.sites[0].pos
		pl.set_physics_process(false)
		pl.global_position = c + Vector3(-60, 55, 60)
		_look_at(c)
	elif step == 13 and t > 25.8 and t < 26.0:
		_shot("10_aerial")
		var dl = w.site_of("dealership")
		if dl:
			var b := Basis(Vector3.UP, dl.rot * PI / 2.0)
			pl.global_position = dl.pos + b * Vector3(-6, 0, 22) + Vector3(0, 0.2, 0)
			_look_at(dl.pos + Vector3(0, 2, 0))
	elif step == 13 and t > 27.0:
		_shot("11_dealership")
		step = 14
		Settings.set_preset("Low")
		Settings.set_preset("Medium")
		w.day_t = 0.88
		if w.lamps.size() > 0:
			var lp: Vector3 = w.lamps[0].global_position
			var pp: Vector3 = lp + Vector3(9, 0, 9)
			pp.y = w.height_at(pp.x, pp.z) + 0.1
			pl.global_position = pp
			_look_at(lp - Vector3(0, 4, 0))
	elif step == 14 and t > 29.0:
		_shot("12_night")
		step = 15
		for c in w.get_children():
			if c.has_method("open_menu"):
				menu = c
		menu.open_menu()
		menu.panel.visible = false
		menu.settings.visible = true
	elif step == 15 and t > 30.5:
		print("SMOKE paused=", get_tree().paused, " mode=", Game.mode)
		_shot("13_settings")
		menu.resume()
		step = 16
	elif step == 16 and t > 31.0:
		var d = w.director
		print("SMOKE fps=", Engine.get_frames_per_second(), " zombies=", d.zombies.size() if d else 0,
			" chasing=", d.active_count() if d else 0, " hp=", pl.hp, " pieces=", w.pieces.size(),
			" trees=", w.trees.size(), " grass_chunks=", w.grass_chunks.size(), " buildings=", w.sites.size(), " roads=", w.roads.size(), " ramps=", w.ramps.size(), " lamps=", w.lamps.size(), " time=", w.clock(), " storm=", w.storm != null)
		print("SMOKE ok")
		get_tree().quit()

func _quick() -> void:
	var pl = Game.player
	var w = Game.world
	if pl == null:
		return
	pl.set_physics_process(false)
	if step == 0 and t > 1.0:
		step = 1
		var n = w.npc
		var b: Basis = n.global_transform.basis
		pl.global_position = n.global_position + b * Vector3(0.6, 0, 2.6)
		_look_at(n.global_position + Vector3(0, 1.5, 0))
		pl.equip(4)
		pl.talk_to(n)
	elif step == 1 and t > 2.5:
		step = 2
		_shot("30_npc")
		pl.end_talk()
		var ch = w.site_of("church")
		var b := Basis(Vector3.UP, ch.rot * PI / 2.0)
		pl.global_position = ch.pos + b * Vector3(1.5, 0.1, 19.0)
		_look_at(ch.pos + b * Vector3(0, 3.0, 12.0))
	elif step == 2 and t > 4.0:
		step = 3
		_shot("31_church")
		w.doors[0].toggle()
		w.doors[1].toggle()
	elif step == 3 and t > 6.0:
		step = 4
		_shot("32_church_open")
		if w.director:
			w.director.clear_all()
			for k in 7:
				var a := -0.6 + k * 0.2
				var fwd: Vector3 = -pl.global_transform.basis.z
				var p: Vector3 = pl.global_position + fwd.rotated(Vector3.UP, a) * (5.0 + k % 3 * 2.0)
				p.y = w.height_at(p.x, p.z)
				w.director.spawn(p, true)
	elif step == 4 and t > 7.6:
		step = 5
		_shot("33_zombies")
		print("SMOKE ok")
		get_tree().quit()
