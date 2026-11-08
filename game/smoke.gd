extends Node
## Automated test run: `godot -- --smoke [--shots=dir]`. Exercises the main systems, prints stats, quits.

var t := 0.0
var step := 0
var shots := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	print("SMOKE start mode=", Game.mode)

func _look_at(p: Vector3) -> void:
	var pl = Game.player
	var d: Vector3 = p - pl.head.global_position
	pl.yaw = atan2(-d.x, -d.z)
	pl.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots, name])
	print("SMOKE shot ", name)

func _process(dt: float) -> void:
	t += dt
	var pl = Game.player
	var w = Game.world
	if pl == null:
		return
	if step == 0 and t > 1.0:
		step = 1
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
		Input.action_press("move_left")
	elif step == 7 and t > 15.5:
		step = 8
		_shot("05_driving")
		Input.action_release("move_forward")
		Input.action_release("move_left")
		print("SMOKE drove speed=", w.vehicles[0].speed, " moved=", w.vehicles[0].global_position)
		pl.exit_vehicle()
		pl.equip(3)
		pl.yaw += 0.6
		pl.pitch = -0.15
	elif step == 8 and t > 17.0:
		step = 9
		pl.fire()
		_shot("06_rifle")
	elif step == 9 and t > 18.0:
		var d = w.director
		print("SMOKE fps=", Engine.get_frames_per_second(), " zombies=", d.zombies.size() if d else 0,
			" chasing=", d.active_count() if d else 0, " hp=", pl.hp, " pieces=", w.pieces.size(),
			" trees=", w.trees.size(), " grass_chunks=", w.grass_chunks.size(), " storm=", w.storm != null)
		print("SMOKE ok")
		get_tree().quit()
