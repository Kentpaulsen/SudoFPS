extends Node
## Two-process multiplayer test (with server/relay.py running locally):
##   godot --headless -- --mptest=host   --mpfile=/tmp/code --relay=ws://127.0.0.1:8090
##   godot --headless -- --mptest=client --mpfile=/tmp/code --relay=ws://127.0.0.1:8090
## The host creates a party and writes the code to the file, the client joins, the host starts
## Zombie Royale. In game the client shoots a zombie, chops a tree and opens a door; both print
## MPTEST lines and the host checks that everything arrived.

var role := ""
var file := ""
var main: Node
var t := 0.0
var game_t := 0.0
var step := 0
var tree_rid := -1
var tree_hp0 := 0
var saw_remote := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mptest="):
			role = a.substr(9)
		if a.begins_with("--mpfile="):
			file = a.substr(9)
	Settings.v["nickname"] = role.capitalize()
	if role == "host":
		Net.host_party()

func _process(dt: float) -> void:
	t += dt
	if t > 60.0:
		print("MPTEST %s timeout at step %d" % [role, step])
		get_tree().quit(1)
	if not Net.in_game:
		_lobby()
		return
	var w = Game.world
	if w == null or w.player == null:
		return
	game_t += dt
	if role == "host":
		_host_game(w)
	else:
		_client_game(w)

func _lobby() -> void:
	if role == "host":
		if step == 0 and Net.code != "":
			step = 1
			var f := FileAccess.open(file, FileAccess.WRITE)
			f.store_string(Net.code)
			f.close()
			print("MPTEST host code ", Net.code)
		elif step == 1 and Net.members.size() >= 2 and str(Net.members.get(2, {}).get("name", "...")) != "...":
			step = 2
			print("MPTEST host sees client '%s'" % Net.members[2].name)
			if "--ls" in OS.get_cmdline_user_args():
				main.mode_i = 1
			main._on_play()
	else:
		if step == 0 and FileAccess.file_exists(file):
			var c := FileAccess.get_file_as_string(file).strip_edges()
			if c.length() == 5:
				step = 1
				Net.join_party(c)

func _host_game(w) -> void:
	if step == 2 and game_t > 2.0:
		step = 3
		print("MPTEST host zombies=%d remotes=%d" % [w.director.zombies.size() if w.director else 0, w.remotes.size()])
		saw_remote = w.remotes.size() == 1
		var tr = w.trees[0][0]
		tree_rid = tr.get_meta("rid")
		tree_hp0 = tr.get_meta("hp")
	elif step == 3 and game_t > 9.0:
		step = 4
		var tr = w.res_by_id[tree_rid]
		var r = w.remotes.get(2)
		print("MPTEST host remote at %s, tree hp %d -> %d, door0 open=%s, kills=%d, pieces=%d" % [
			str(r.global_position.snapped(Vector3.ONE)) if r else "none", tree_hp0, tr.get_meta("hp"), w.doors[0].open, w.director.kills if w.director else -1, w.pieces.size()])
		if Game.mode == "last_standing":
			print("MPTEST host hp after PvP hit: %d" % w.player.hp)
		var ok: bool = (Game.mode != "last_standing" or w.player.hp < 100.0) and saw_remote and tr.get_meta("hp") < tree_hp0 and w.doors[0].open and (w.director == null or w.director.kills >= 1) and w.pieces.size() >= 1
		print("MPTEST host ", "ok" if ok else "FAILED")
		get_tree().quit(0 if ok else 1)

func _client_game(w) -> void:
	var pl = w.player
	if step == 1 and game_t > 4.0:
		step = 2
		print("MPTEST client puppets=%d remotes=%d" % [w.director.zombies.size() if w.director else 0, w.remotes.size()])
		# shoot the nearest zombie puppet (as a hit would), chop the first tree, open the first door
		var best = null
		for z in (w.director.zombies if w.director else []):
			if best == null or z.global_position.distance_to(pl.global_position) < best.global_position.distance_to(pl.global_position):
				best = z
		if best and w.director:
			best.take_damage(500.0, Vector3.ZERO, Vector3.ZERO)
		var tr = w.trees[0][0]
		for c in tr.get_children():
			if c is StaticBody3D:
				print("MPTEST client chop ", w.server_harvest(c, 1))
				break
		w.doors[0].toggle()
		Net.send(0, "door", 0)
		if Game.mode == "last_standing" and w.remotes.has(1) and w.remotes[1].hitbox:
			w.remotes[1].hitbox.take_damage(30.0, Vector3.ZERO, Vector3.ZERO)
			print("MPTEST client shot the host")
		var slot: Dictionary = w.piece_slot(0, pl.global_position + Vector3(4, 0, 0), 0)
		w.server_build(0, slot)
		pl.fire()
	elif step == 2 and game_t > 6.5:
		step = 3
		var zok: bool = w.director == null or (w.director.kills >= 1 and w.director.zombies.size() > 0)
		print("MPTEST client day=%.3f storm=%s zombies_ok=%s" % [w.day_t, str(w.storm.center.snapped(Vector2.ONE)) if w.storm else "-", zok])
		print("MPTEST client ", "ok" if zok else "FAILED")
		get_tree().quit()
