extends Node
## Network test: `godot -- --nettest --relay=ws://127.0.0.1:8090` with server/relay.py running.
## Net (autoload) hosts, a second client joins with the code, the host starts a game and both
## exchange in-game states. Prints NETTEST lines and quits.

var b: Node
var t := 0.0
var step := 0
var got_start := false

func _ready() -> void:
	Settings.v["nickname"] = "Host"
	b = Node.new()
	b.set_script(load("res://game/net.gd"))
	b.url = Net.relay_url()
	add_child(b)
	b.started.connect(func(s, m): got_start = true; print("NETTEST client got start seed=%d mode=%s" % [s, m]))
	b.failed.connect(func(r): print("NETTEST client failed: ", r))
	Net.failed.connect(func(r): print("NETTEST host failed: ", r))
	Net.host_party()

func _process(dt: float) -> void:
	t += dt
	if step == 0 and Net.code != "":
		step = 1
		print("NETTEST hosted code=", Net.code)
		b.join_party(Net.code.to_lower())
	elif step == 1 and b.state == b.JOINED and Net.members.size() == 2 and b.members.size() == 2 and str(b.members.get(1, {}).get("name", "")) == "Host":
		step = 2
		print("NETTEST party ok: host sees %d, client sees host as '%s'" % [Net.members.size(), b.members[1].name])
		Net.set_mode("last_standing")
	elif step == 2 and b.mode == "last_standing":
		step = 3
		print("NETTEST mode synced")
		Net.start_game("last_standing")
	elif step == 3 and got_start:
		step = 4
		Net._send(0, "st", {"p": Vector3(1, 2, 3), "y": 0.5, "s": 3.0, "v": "", "w": 0, "c": false, "d": false})
		b._send(1, "st", {"p": Vector3(4, 5, 6), "y": 1.0, "s": 0.0, "v": "bike", "w": 0, "c": false, "d": false})
	elif step == 4 and b.remote.has(1) and Net.remote.has(b.my_id):
		step = 5
		print("NETTEST states ok: client sees host at ", b.remote[1].p, ", host sees client in ", Net.remote[b.my_id].v)
		Net.leave_party()
	elif step == 5 and b.state == b.OFFLINE:
		print("NETTEST host left -> client closed ok")
		print("NETTEST ok")
		get_tree().quit()
	if t > 15.0:
		print("NETTEST timeout at step ", step)
		get_tree().quit(1)
