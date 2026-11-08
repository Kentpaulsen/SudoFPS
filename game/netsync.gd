extends Node3D
## In-game multiplayer for a party game. Child of the world.
## Host: runs the real zombies (zombies.gd), sends zombie snapshots to each guest 10 times a second
## and the time of day and storm every 2 s. Guests: show the host's zombies as puppets (this node
## stands in for the director, so the HUD and dev keys keep working).
## Everyone: shots, damage between players (Last Standing), deaths, building, harvesting and doors.

const ZombieScript := preload("res://game/zombie.gd")
const SNAP_RANGE := 120.0

var w
var host := false
var _snap_t := 0.0
var _env_t := 0.0
# guest side, director stand-in
var zombies: Array = []
var puppets := {}               # zid -> puppet
var meshes: Array = []
var kills := 0
var horde_count := 0

func _ready() -> void:
	w = get_parent()
	host = Net.is_host()
	if not host:
		for i in ZombieScript.OUTFITS.size():
			meshes.append(ZombieScript.build_parts(i))

# ---------------------------------------------------------------- per frame
func _process(dt: float) -> void:
	if not Net.is_party_game():
		return
	if host:
		_snap_t += dt
		if _snap_t >= 0.1:
			_snap_t = 0.0
			_send_snapshots()
		_env_t += dt
		if _env_t >= 2.0:
			_env_t = 0.0
			var env := {"day": w.day_t}
			if w.storm:
				env["storm"] = w.storm.net_state()
			Net.send(0, "env", env)
	else:
		# puppets the host stopped sending (out of range) go away
		for zid in puppets.keys():
			var p = puppets[zid]
			if not is_instance_valid(p):
				puppets.erase(zid)
				continue
			if p.state != ZombieScript.DEAD and p.net_seen > 1.5:
				zombies.erase(p)
				puppets.erase(zid)
				p.queue_free()

func _send_snapshots() -> void:
	var d = w.director
	if d == null:
		return
	for id in w.remotes:
		var r = w.remotes[id]
		var rp: Vector3 = r.target_pos
		var arr := PackedFloat32Array()
		for z in d.zombies:
			if z.state == ZombieScript.DEAD:
				continue
			var zp: Vector3 = z.global_position
			if absf(zp.x - rp.x) > SNAP_RANGE or absf(zp.z - rp.z) > SNAP_RANGE:
				continue
			var flags: int = z.state | (z.outfit << 2) | (int(z.runner) << 5) | (int(z.swipe > 0.6) << 6)
			arr.append_array([z.zid, zp.x, zp.y, zp.z, z.rotation.y, flags])
		Net.send(id, "zs", arr)

# ---------------------------------------------------------------- messages
func on_message(src: int, type: String, data) -> void:
	var pl = Game.player
	match type:
		# ---- zombies
		"zs":
			if not host:
				_apply_snapshot(data)
		"zd":
			var p = puppets.get(int(data))
			if p and is_instance_valid(p) and p.state != ZombieScript.DEAD:
				p.die()
		"zdmg":   # a guest hit one of the host's zombies
			if host and w.director:
				var z = w.director.by_id.get(int(data[0]))
				if z and is_instance_valid(z) and z.state != ZombieScript.DEAD:
					z.take_damage(float(data[1]), data[2], Vector3.ZERO)
					if z.state == ZombieScript.DEAD:
						Net.send(src, "zk", z.zid)
		"zk":
			kills += 1
		"zhit":   # a host zombie reached this player
			if pl:
				pl.zombie_hit(float(data[0]), float(data[1]))
		"noise":
			if host:
				Game.noise.emit(data[0], float(data[1]))
		"msg":
			Game.msg(str(data[0]), data[1])
		# ---- combat
		"shot":
			Sfx.play3d(str(data[2]), data[0], -2.0)
			w.tracer(data[0], data[1])
		"dmg":    # another player shot us (Last Standing only)
			if pl and not pl.dead and Game.mode == "last_standing":
				pl.hurt_by = src
				pl.last_cause = "shot"
				pl.damage(float(data[0]))
		"died":
			var killer := int(data[1])
			var who: String = Net._name_of(src)
			if killer > 0:
				var kname: String = "You" if killer == Net.my_id else Net._name_of(killer)
				Game.msg("%s eliminated %s" % [kname, who], Color(1, 0.55, 0.4))
			else:
				Game.msg("%s died (%s)" % [who, str(data[2])], Color(1, 0.7, 0.5))
		# ---- world
		"build":
			w.server_build(int(data[0]), {"xform": data[1], "edges": data[2]}, true)
		"harv":
			w.harvest_remote(int(data[0]), int(data[1]))
		"door":
			var i := int(data)
			if i >= 0 and i < w.doors.size():
				w.doors[i].toggle()
		"env":
			if not host:
				w.day_t = float(data.day)
				if w.storm and data.has("storm"):
					w.storm.net_apply(data.storm)

func _apply_snapshot(arr: PackedFloat32Array) -> void:
	var i := 0
	while i + 5 < arr.size():
		var zid := int(arr[i])
		var pos := Vector3(arr[i + 1], arr[i + 2], arr[i + 3])
		var yaw: float = arr[i + 4]
		var flags := int(arr[i + 5])
		i += 6
		var p = puppets.get(zid)
		if p == null or not is_instance_valid(p):
			var oi := (flags >> 2) & 7
			p = CharacterBody3D.new()
			p.set_script(ZombieScript)
			add_child(p)
			p.setup(meshes[oi % meshes.size()], self)
			p.zid = zid
			p.outfit = oi
			p.runner = ((flags >> 5) & 1) == 1
			p.make_puppet(pos, yaw)
			puppets[zid] = p
			zombies.append(p)
		p.net_update(pos, yaw, flags & 3, ((flags >> 6) & 1) == 1)

## A puppet was shot on this machine: the host applies the damage.
func puppet_hit(z, dmg: float, knock: Vector3) -> void:
	Net.send(1, "zdmg", [z.zid, dmg, knock])
	Sfx.play3d("hit", z.global_position + Vector3(0, 1.2, 0), -6.0)

func zombie_died(z) -> void:
	if host:
		Net.send(0, "zd", z.zid)

func broadcast_msg(text: String, col: Color) -> void:
	Net.send(0, "msg", [text, col])

## Our player died: tell the others (killer id 0 = zombies, storm or a fall).
func announce_death(killer := 0, cause := "") -> void:
	Net.send(0, "died", [Net.my_id, killer, cause])
	if killer > 0:
		Game.msg("%s eliminated you" % Net._name_of(killer), Color(1, 0.45, 0.35))

# ---------------------------------------------------------------- director stand-in (guests)
func on_dead(z) -> void:
	zombies.erase(z)

func alert(_z, _scream: bool) -> void:
	pass

func active_count() -> int:
	var n := 0
	for z in zombies:
		if is_instance_valid(z) and z.state == ZombieScript.CHASE:
			n += 1
	return n

func stress(_n: int) -> void:
	Game.msg("Only the host can spawn zombies", Color(0.8, 0.8, 0.8))

func clear_all() -> void:
	Game.msg("Only the host can remove zombies", Color(0.8, 0.8, 0.8))
