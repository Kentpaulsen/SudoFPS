extends Node
## Party and multiplayer over the PixelEscape relay (server/relay.py). Autoloaded as "Net".
## The host's game is the authority. Join codes come from the relay.
## Wire format: JSON text frames for room control; binary frames = 4-byte target id + var_to_bytes([type, data]).

signal status_changed            # connection, party members or mode changed
signal started(seed: int, mode: String)
signal failed(reason: String)
signal left(reason: String)

enum { OFFLINE, CONNECTING, HOSTING, JOINED }
const SEND_HZ := 15.0
const Character = preload("res://game/character.gd")

var state := OFFLINE
var my_id := 0
var code := ""
var members := {}               # id -> {name, look(packed), mode?}
var remote := {}                # id -> latest in-game state dict
var mode := "zombie"            # the party's game mode (host decides)
var in_game := false
var game_seed := 0
var ws: WebSocketPeer
var _want := ""                 # "host" or "join:CODE" once connected
var _send_t := 0.0
var url := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--relay="):
			url = a.substr(8)

func relay_url() -> String:
	return url if url != "" else str(Settings.get_v("relay"))

func is_online() -> bool:
	return state == HOSTING or state == JOINED

func is_host() -> bool:
	return state == HOSTING

func host_party() -> void:
	_connect("host")

func join_party(c: String) -> void:
	c = c.strip_edges().to_upper().replace(" ", "")
	if c.length() < 4:
		failed.emit("Type the 5-letter code from your friend")
		return
	_connect("join:" + c)

func leave_party() -> void:
	if ws:
		ws.close()
	_reset()
	status_changed.emit()

func _reset() -> void:
	state = OFFLINE
	my_id = 0
	code = ""
	members.clear()
	remote.clear()
	in_game = false
	ws = null

func _connect(what: String) -> void:
	if ws:
		ws.close()
	_reset()
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 20
	var err := ws.connect_to_url(relay_url())
	if err != OK:
		ws = null
		failed.emit("Could not reach the server")
		return
	_want = what
	state = CONNECTING
	status_changed.emit()

func set_mode(m: String) -> void:
	mode = m
	if is_host():
		_send(0, "mode", m)
	status_changed.emit()

## Host only: everyone (including late joiners) loads the same island.
func start_game(m: String) -> void:
	mode = m
	game_seed = randi() % 1000000
	in_game = true
	_send(0, "start", {"seed": game_seed, "mode": mode})

func announce() -> void:
	_send(0, "hello", _hello())

func _hello() -> Dictionary:
	return {"name": Game.my_name(), "look": Character.pack(Game.my_look()), "mode": mode, "in_game": in_game}

# ---------------------------------------------------------------- traffic
func _send(target: int, type: String, data) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN or my_id == 0:
		return
	var payload := var_to_bytes([type, data])
	var buf := PackedByteArray([(target >> 24) & 255, (target >> 16) & 255, (target >> 8) & 255, target & 255])
	buf.append_array(payload)
	ws.send(buf, WebSocketPeer.WRITE_MODE_BINARY)

func _send_json(d: Dictionary) -> void:
	ws.send_text(JSON.stringify(d))

func _process(dt: float) -> void:
	if ws == null:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and _want != "":
		if _want == "host":
			_send_json({"op": "host"})
		else:
			_send_json({"op": "join", "code": _want.substr(5)})
		_want = ""
	while ws and ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		if ws.was_string_packet():
			_on_control(JSON.parse_string(pkt.get_string_from_utf8()))
		elif pkt.size() >= 4:
			var src := (pkt[0] << 24) | (pkt[1] << 16) | (pkt[2] << 8) | pkt[3]
			var msg = bytes_to_var(pkt.slice(4))
			if msg is Array and msg.size() == 2:
				_on_message(src, msg[0], msg[1])
	if ws and st == WebSocketPeer.STATE_CLOSED:
		var was := state
		_reset()
		if was == CONNECTING:
			failed.emit("Could not reach the server")
		elif was != OFFLINE:
			left.emit("Lost connection to the server")
		status_changed.emit()
		return
	# in-game: broadcast our state
	if in_game and is_online() and is_instance_valid(Game.player) and Game.player.is_inside_tree():
		_send_t += dt
		if _send_t >= 1.0 / SEND_HZ:
			_send_t = 0.0
			_send(0, "st", _my_state())

func _on_control(m) -> void:
	if not m is Dictionary:
		return
	match m.get("op", ""):
		"hosted":
			state = HOSTING
			my_id = int(m.id)
			code = m.code
			members[my_id] = _hello()
		"joined":
			state = JOINED
			my_id = int(m.id)
			code = m.code
			members[my_id] = _hello()
			announce()
		"peer_joined":
			members[int(m.id)] = {"name": "...", "look": {}}
			_send(int(m.id), "hello", _hello())
			if is_host() and in_game:
				_send(int(m.id), "start", {"seed": game_seed, "mode": mode})
		"peer_left":
			members.erase(int(m.id))
			remote.erase(int(m.id))
			if Game.world and Game.world.has_method("remove_remote"):
				Game.world.remove_remote(int(m.id))
			Game.msg("%s left the party" % _name_of(int(m.id)), Color(1, 0.8, 0.5))
		"closed":
			if ws:
				ws.close()
			_reset()
			left.emit("The host left. The party is closed.")
		"error":
			var r: String = str(m.get("reason", ""))
			var nice: String = {"no_such_room": "No party with that code", "room_full": "That party is full (8 players)",
				"server_full": "The server is full, try again later"}.get(r, "Server error: " + r)
			if state == CONNECTING:
				if ws:
					ws.close()
				_reset()
			failed.emit(nice)
	status_changed.emit()

func _name_of(id: int) -> String:
	return str(members.get(id, {}).get("name", "Player %d" % id))

func _on_message(src: int, type: String, data) -> void:
	match type:
		"hello":
			var first: bool = members.get(src, {}).get("name", "...") == "..."
			members[src] = data
			if src == 1 and not is_host():
				mode = str(data.get("mode", mode))
			if first and in_game:
				Game.msg("%s joined the game" % data.get("name", "Someone"), Color(0.6, 1, 0.6))
			status_changed.emit()
		"mode":
			if src == 1:
				mode = str(data)
				status_changed.emit()
		"start":
			if src == 1 and not in_game:
				in_game = true
				game_seed = int(data.seed)
				mode = str(data.mode)
				started.emit(game_seed, mode)
		"st":
			remote[src] = data
			if Game.world and Game.world.has_method("update_remote"):
				Game.world.update_remote(src, data)

func _my_state() -> Dictionary:
	var pl = Game.player
	var d := {"p": pl.global_position, "y": pl.rotation.y, "s": Vector2(pl.velocity.x, pl.velocity.z).length(),
		"v": "", "w": pl.cur, "c": pl.crouching, "d": pl.dead}
	if pl.vehicle:
		d.v = pl.vehicle.kind
		d.p = pl.vehicle.global_position
		d.y = pl.vehicle.rotation.y
		d["vs"] = pl.vehicle.speed
	return d
