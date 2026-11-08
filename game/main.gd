extends Node
## Lobby: your character on a pedestal, the character builder, game mode, nickname, party (invite
## friends with a code through the relay) and PLAY. Party members stand on the side pedestals.

const Character = preload("res://game/character.gd")
const MODES := [
	["zombie", "ZOMBIE ROYALE", "Zombies idle around the island. Noise and sight wake them, hordes arrive over time. No storm."],
	["last_standing", "LAST STANDING", "The Hex Horizon storm shrinks the island. No zombies. Last one standing."],
]
const SLOT_POS := [Vector3(-1.2, 0, -0.9), Vector3(1.2, 0, -0.9)]

var ui: CanvasLayer
var stage: Node3D
var cam: Camera3D
var me: Node3D
var others: Array = [null, null]       # side pedestal characters
var other_ids: Array = [0, 0]
var other_keys: Array = ["", ""]
var settings_panel: Control
var look := {}
var mode_i := 0
var t := 0.0
var spin := PI                  # characters face -Z; turn them towards the camera
var dragging := false
# widgets
var name_edit: LineEdit
var mode_title: Label
var mode_desc: Label
var mode_prev: Button
var mode_next: Button
var play_btn: Button
var party_status: Label
var code_label: Label
var code_edit: LineEdit
var host_btn: Button
var join_btn: Button
var leave_btn: Button
var slot_buttons: Array = []
var slot_names: Array = []
var rows := {}                          # builder row key -> value label
var preset_i := 0
var shot_dir := ""

func _ready() -> void:
	if Game.smoke:
		_start("last_standing" if "--ls" in OS.get_cmdline_user_args() else "zombie")
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lobbyshot="):
			shot_dir = a.substr(12)
		if a == "--nettest":
			var nt := Node.new()
			nt.set_script(load("res://game/nettest.gd"))
			add_child(nt)
			return
	look = Game.my_look()
	_build_stage()
	_build_ui()
	Net.status_changed.connect(_refresh_party)
	Net.started.connect(_on_started)
	Net.failed.connect(func(r): party_status.text = r; party_status.modulate = Color(1, 0.55, 0.45))
	Net.left.connect(func(r): party_status.text = r; party_status.modulate = Color(1, 0.75, 0.45))
	mode_i = maxi(0, MODES.map(func(m): return m[0]).find(Net.mode if Net.is_online() else Game.mode))
	_refresh_mode()
	_refresh_party()
	if shot_dir != "":
		get_tree().create_timer(1.5).timeout.connect(func():
			get_viewport().get_texture().get_image().save_png(shot_dir + "/50_lobby.png")
			_open_party_demo()
			get_tree().create_timer(0.6).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png(shot_dir + "/51_lobby_party.png")
				get_tree().quit()))

# ---------------------------------------------------------------- 3D stage
func _build_stage() -> void:
	stage = Node3D.new()
	add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.28, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.65, 0.85)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, PI + 0.6, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.6, 0.8, 1.0)
	stage.add_child(fill)
	# floor with a tile grid
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_color = Color(0.05, 0.25, 0.70)
	floor_m.roughness = 0.4
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	pm.material = floor_m
	fl.mesh = pm
	stage.add_child(fl)
	var line_m := StandardMaterial3D.new()
	line_m.albedo_color = Color(0.35, 0.65, 1.0)
	line_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(-12, 13):
		for axis in 2:
			var ln := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.025, 0.004, 60) if axis == 0 else Vector3(60, 0.004, 0.025)
			bm.material = line_m
			ln.mesh = bm
			ln.position = Vector3(i * 1.6, 0.002, 0) if axis == 0 else Vector3(0, 0.002, i * 1.6)
			stage.add_child(ln)
	_pedestal(Vector3.ZERO, 0.75)
	for p in SLOT_POS:
		_pedestal(p, 0.55)
	me = Game.make_character(look)
	stage.add_child(me)
	me.position = Vector3(0, 0.16, 0)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.position = Vector3(0, 1.4, 6.2)
	stage.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))
	cam.current = true

func _pedestal(p: Vector3, r: float) -> void:
	for spec in [[r + 0.08, 0.10, Color(0.10, 0.12, 0.16), 0.05], [r, 0.06, Color(0.16, 0.18, 0.22), 0.13]]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = spec[0]
		cm.bottom_radius = spec[0]
		cm.height = spec[1]
		var m := StandardMaterial3D.new()
		m.albedo_color = spec[2]
		m.roughness = 0.5
		cm.material = m
		mi.mesh = cm
		mi.position = p + Vector3(0, spec[3], 0)
		stage.add_child(mi)
	var glow := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = r * 0.8
	gm.bottom_radius = r * 0.8
	gm.height = 0.01
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.75, 0.92, 1.0)
	g.emission_enabled = true
	g.emission = Color(0.6, 0.85, 1.0)
	g.emission_energy_multiplier = 1.2
	gm.material = g
	glow.mesh = gm
	glow.position = p + Vector3(0, 0.165, 0)
	stage.add_child(glow)

# ---------------------------------------------------------------- UI
func _panel(parent: Control, col := Color(0.03, 0.10, 0.25, 0.82)) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	return pc

func _btn(text: String, cb: Callable, h := 38, col := Color(0.10, 0.30, 0.62)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": col, "hover": col.lightened(0.15), "pressed": col.darkened(0.2), "disabled": col.darkened(0.45)}[st]
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(cb)
	return b

func _label(text: String, size := 16, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	# title, top left
	var tbox := VBoxContainer.new()
	tbox.position = Vector2(22, 14)
	root.add_child(tbox)
	var title := _label("PixelEscape", 46, Color(1, 0.86, 0.25))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.25))
	title.add_theme_constant_override("outline_size", 10)
	tbox.add_child(title)
	tbox.add_child(_label("Prototype v%s" % Game.VERSION, 14, Color(0.8, 0.9, 1.0)))
	# settings / fullscreen, top right
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -330
	top.offset_right = -18
	top.offset_top = 16
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	for spec in [["Settings", func(): settings_panel.visible = true], ["Fullscreen", func(): Settings.toggle_fullscreen()]]:
		var b := _btn(spec[0], spec[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(b)
	_build_builder(root)
	_build_right(root)
	# party slots over the side pedestals
	for i in 2:
		var b := _btn("+\nINVITE", _on_slot, 110, Color(0.08, 0.30, 0.65, 0.85))
		b.custom_minimum_size = Vector2(84, 110)
		b.add_theme_font_size_override("font_size", 20)
		root.add_child(b)
		slot_buttons.append(b)
		var nl := _label("", 18, Color(1, 1, 1))
		nl.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.25))
		nl.add_theme_constant_override("outline_size", 8)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.custom_minimum_size = Vector2(200, 0)
		root.add_child(nl)
		slot_names.append(nl)
	var me_name := _label("", 20)
	me_name.name = "MeName"
	me_name.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.25))
	me_name.add_theme_constant_override("outline_size", 8)
	me_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	me_name.custom_minimum_size = Vector2(240, 0)
	root.add_child(me_name)
	var hint := _label("Drag to turn your character.  In game: Esc menu, H controls.", 13, Color(0.8, 0.88, 1.0))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 22
	hint.offset_top = -30
	root.add_child(hint)
	settings_panel = load("res://game/settings_ui.gd").new()
	settings_panel.visible = false
	settings_panel.closed.connect(func(): settings_panel.visible = false)
	ui.add_child(settings_panel)

func _build_builder(root: Control) -> void:
	var p := _panel(root)
	p.position = Vector2(18, 108)
	p.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	p.add_child(box)
	box.add_child(_label("CHARACTER", 18, Color(1, 0.86, 0.25)))
	var specs := [["preset", "Look"], ["skin", "Skin"], ["hair", "Hair"], ["hair_col", "Hair colour"], ["beard", "Beard"],
		["glasses", "Glasses"], ["top", "Top"], ["top_col", "Top colour"], ["pants", "Trousers"], ["pants_col", "Trouser colour"], ["feet", "Feet"]]
	for sp in specs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		box.add_child(row)
		var name_l := _label(sp[1], 14, Color(0.75, 0.85, 1.0))
		name_l.custom_minimum_size = Vector2(98, 0)
		row.add_child(name_l)
		var prev := _btn("<", _step.bind(sp[0], -1), 28)
		prev.custom_minimum_size = Vector2(30, 28)
		row.add_child(prev)
		var val := _label("", 14)
		val.custom_minimum_size = Vector2(110, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.clip_text = true
		row.add_child(val)
		var nxt := _btn(">", _step.bind(sp[0], 1), 28)
		nxt.custom_minimum_size = Vector2(30, 28)
		row.add_child(nxt)
		rows[sp[0]] = val
	box.add_child(_btn("Random", _randomise, 32, Color(0.35, 0.22, 0.60)))
	_refresh_rows()

func _build_right(root: Control) -> void:
	var p := _panel(root)
	p.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	p.offset_left = -360
	p.offset_right = -18
	p.offset_top = 70
	p.offset_bottom = -18
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	box.add_child(_label("Nickname", 13, Color(0.75, 0.85, 1.0)))
	name_edit = LineEdit.new()
	name_edit.text = str(Settings.get_v("nickname"))
	name_edit.placeholder_text = "Type your name"
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 38)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.text_changed.connect(func(tx):
		Settings.set_v("nickname", tx)
		if Net.is_online():
			Net.members[Net.my_id] = Net._hello()
			Net.announce()
		_place_labels())
	box.add_child(name_edit)
	# mode card
	var card := _panel(box, Color(0.10, 0.18, 0.08, 0.95))
	var cb := VBoxContainer.new()
	card.add_child(cb)
	var mrow := HBoxContainer.new()
	cb.add_child(mrow)
	mode_prev = _btn("<", func(): _change_mode(-1), 34)
	mode_prev.custom_minimum_size = Vector2(34, 34)
	mrow.add_child(mode_prev)
	mode_title = _label("", 22, Color(1, 1, 1))
	mode_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(mode_title)
	mode_next = _btn(">", func(): _change_mode(1), 34)
	mode_next.custom_minimum_size = Vector2(34, 34)
	mrow.add_child(mode_next)
	mode_desc = _label("", 13, Color(0.85, 0.92, 0.8))
	mode_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	mode_desc.custom_minimum_size = Vector2(300, 54)
	cb.add_child(mode_desc)
	# party
	box.add_child(_label("PARTY", 18, Color(1, 0.86, 0.25)))
	party_status = _label("", 14, Color(0.85, 0.9, 1.0))
	party_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	party_status.custom_minimum_size = Vector2(300, 0)
	box.add_child(party_status)
	code_label = _label("", 38, Color(1, 0.95, 0.6))
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(code_label)
	host_btn = _btn("Create party (get a code)", func(): Net.host_party(), 38)
	box.add_child(host_btn)
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 6)
	box.add_child(jrow)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "Friend's code"
	code_edit.max_length = 5
	code_edit.custom_minimum_size = Vector2(0, 38)
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.add_theme_font_size_override("font_size", 20)
	code_edit.text_submitted.connect(func(tx): Net.join_party(tx))
	jrow.add_child(code_edit)
	join_btn = _btn("Join", func(): Net.join_party(code_edit.text), 38)
	join_btn.custom_minimum_size = Vector2(90, 38)
	jrow.add_child(join_btn)
	leave_btn = _btn("Leave party", func(): Net.leave_party(), 34, Color(0.45, 0.12, 0.10))
	box.add_child(leave_btn)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	play_btn = _btn("PLAY", _on_play, 86, Color(0.98, 0.80, 0.08))
	play_btn.add_theme_font_size_override("font_size", 46)
	play_btn.add_theme_color_override("font_color", Color(0.12, 0.10, 0.02))
	play_btn.add_theme_color_override("font_hover_color", Color(0.12, 0.10, 0.02))
	play_btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.28, 0.2))
	box.add_child(play_btn)

# ---------------------------------------------------------------- builder logic
func _cycle(arr: Array, cur, d: int):
	var i := arr.find(cur)
	return arr[(maxi(i, 0) + d + arr.size()) % arr.size()]

func _nearest(arr: Array, c: Color) -> int:
	var best := 0
	var bd := INF
	for i in arr.size():
		var dd: float = Vector3(arr[i].r - c.r, arr[i].g - c.g, arr[i].b - c.b).length()
		if dd < bd:
			bd = dd
			best = i
	return best

func _step(key: String, d: int) -> void:
	match key:
		"preset":
			preset_i = (preset_i + d + Character.PRESET_ORDER.size()) % Character.PRESET_ORDER.size()
			look = Character.PRESETS[Character.PRESET_ORDER[preset_i]].duplicate()
		"skin": look.skin = (int(look.skin) + d + Character.SKINS.size()) % Character.SKINS.size()
		"hair_col": look.hair_col = (int(look.hair_col) + d + Character.HAIR_COLS.size()) % Character.HAIR_COLS.size()
		"hair": look.hair = _cycle(Character.HAIRS, look.hair, d)
		"beard": look.beard = _cycle(Character.BEARDS, look.beard, d)
		"glasses": look.glasses = not look.glasses
		"top":
			look.top = _cycle(Character.TOPS, look.top, d)
			if look.top == "suit" and look.get("tie") == null:
				look.tie = Color(0.45, 0.04, 0.04)
		"pants": look.pants = _cycle(Character.PANTS, look.pants, d)
		"feet": look.feet = _cycle(Character.FEET, look.feet, d)
		"top_col":
			look.top_col = Character.TOP_COLS[(_nearest(Character.TOP_COLS, look.top_col) + d + Character.TOP_COLS.size()) % Character.TOP_COLS.size()]
		"pants_col":
			look.pants_col = Character.PANTS_COLS[(_nearest(Character.PANTS_COLS, look.pants_col) + d + Character.PANTS_COLS.size()) % Character.PANTS_COLS.size()]
	_apply_look()

func _randomise() -> void:
	look = {"skin": randi() % Character.SKINS.size(), "hair": Character.HAIRS.pick_random(), "hair_col": randi() % Character.HAIR_COLS.size(),
		"top": Character.TOPS.pick_random(), "top_col": Character.TOP_COLS.pick_random(), "tie": [null, Color(0.45, 0.04, 0.04), Color(0.2, 0.2, 0.45)].pick_random(),
		"pants": Character.PANTS.pick_random(), "pants_col": Character.PANTS_COLS.pick_random(), "feet": Character.FEET.pick_random(),
		"glasses": randf() < 0.25, "beard": Character.BEARDS.pick_random() if randf() < 0.5 else "none", "height": randf_range(0.95, 1.03)}
	_apply_look()

func _apply_look() -> void:
	me.build(look)
	Settings.set_v("look", Character.pack(look))
	if Net.is_online():
		Net.members[Net.my_id] = Net._hello()
		Net.announce()
	_refresh_rows()

func _refresh_rows() -> void:
	if rows.is_empty():
		return
	var pname := "Custom"
	for k in Character.PRESETS:
		if Character.pack(Character.PRESETS[k]) == Character.pack(look):
			pname = k
	rows.preset.text = pname
	rows.skin.text = "Tone %d" % (int(look.skin) + 1)
	rows.hair.text = str(look.hair).capitalize()
	rows.hair_col.text = ["Black", "Dark brown", "Dark blond", "Blond", "Grey", "Red"][int(look.hair_col) % 6]
	rows.beard.text = str(look.beard).capitalize()
	rows.glasses.text = "Yes" if look.glasses else "No"
	rows.top.text = str(look.top).capitalize()
	rows.top_col.text = "Colour %d" % (_nearest(Character.TOP_COLS, look.top_col) + 1)
	rows.pants.text = str(look.pants).capitalize()
	rows.pants_col.text = "Colour %d" % (_nearest(Character.PANTS_COLS, look.pants_col) + 1)
	rows.feet.text = str(look.feet).capitalize()
	for k in ["top_col", "pants_col"]:
		rows[k].add_theme_color_override("font_color", look[k].lightened(0.35))

# ---------------------------------------------------------------- mode, party, play
func _change_mode(d: int) -> void:
	mode_i = (mode_i + d + MODES.size()) % MODES.size()
	Net.set_mode(MODES[mode_i][0])
	_refresh_mode()

func _refresh_mode() -> void:
	mode_title.text = MODES[mode_i][1]
	mode_desc.text = MODES[mode_i][2]
	var can := not Net.is_online() or Net.is_host()
	mode_prev.disabled = not can
	mode_next.disabled = not can

func _on_slot() -> void:
	if not Net.is_online():
		Net.host_party()

func _open_party_demo() -> void:
	party_status.text = "Party code (demo screenshot). Your friends type it under Join."
	code_label.text = "K7QXM"
	_show_other(0, -1, {"name": "Friend", "look": Character.pack(Character.PRESETS["Car dealer"])})

func _refresh_party() -> void:
	if not is_instance_valid(party_status):
		return
	party_status.modulate = Color.WHITE
	var online := Net.is_online()
	host_btn.visible = not online and Net.state != Net.CONNECTING
	code_edit.get_parent().visible = not online and Net.state != Net.CONNECTING
	leave_btn.visible = online or Net.state == Net.CONNECTING
	code_label.text = Net.code if online else ""
	match Net.state:
		Net.OFFLINE: party_status.text = "Play alone, or create a party and give your friends the code. Up to 8 players."
		Net.CONNECTING: party_status.text = "Connecting to pixelescape.notnow.no ..."
		Net.HOSTING: party_status.text = "You are the host (%d in party). Friends type this code under Join:" % Net.members.size()
		Net.JOINED: party_status.text = "In %s's party (%d players). The host picks the mode and presses PLAY." % [Net._name_of(1), Net.members.size()]
	if online and not Net.is_host():
		mode_i = maxi(0, MODES.map(func(m): return m[0]).find(Net.mode))
	_refresh_mode()
	play_btn.disabled = online and not Net.is_host()
	play_btn.text = "PLAY" if not play_btn.disabled else "WAITING"
	# side pedestals: the first two other members
	var ids: Array = Net.members.keys().filter(func(i): return i != Net.my_id)
	ids.sort()
	for s in 2:
		if s < ids.size():
			_show_other(s, ids[s], Net.members[ids[s]])
		else:
			_show_other(s, 0, {})
	if ids.size() > 2:
		party_status.text += "  (+%d more)" % (ids.size() - 2)

func _show_other(s: int, id: int, m: Dictionary) -> void:
	var key := str(m)
	if key == other_keys[s]:
		return
	other_keys[s] = key
	other_ids[s] = id
	if others[s]:
		others[s].queue_free()
		others[s] = null
	slot_names[s].text = ""
	if m.is_empty():
		slot_buttons[s].visible = true
		return
	slot_buttons[s].visible = false
	slot_names[s].text = str(m.get("name", "..."))
	if not m.get("look", {}).is_empty():
		var c := Game.make_character(Character.unpack(m.look))
		stage.add_child(c)
		c.position = SLOT_POS[s] + Vector3(0, 0.16, 0)
		c.scale = Vector3.ONE * 0.92
		c.rotation.y = PI - SLOT_POS[s].x * 0.3
		others[s] = c

func _on_play() -> void:
	var m: String = MODES[mode_i][0]
	if Net.is_online():
		Net.start_game(m)
		Game.seed_override = Net.game_seed
	else:
		Game.seed_override = -1
	_start(m)

func _on_started(seed: int, m: String) -> void:
	Game.seed_override = seed
	_start(m)

func _start(mode: String) -> void:
	Game.mode = mode
	Game.storm_enabled = mode == "last_standing"
	Game.zombies_enabled = mode == "zombie"
	if Net.started.is_connected(_on_started):
		Net.started.disconnect(_on_started)
	if Net.status_changed.is_connected(_refresh_party):
		Net.status_changed.disconnect(_refresh_party)
	if ui:
		ui.queue_free()
		ui = null
	if stage:
		stage.queue_free()
		stage = null
	var w := Node3D.new()
	w.set_script(load("res://game/world.gd"))
	w.name = "World"
	add_child(w)

# ---------------------------------------------------------------- per frame
func _input(e: InputEvent) -> void:
	if stage == null:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		dragging = e.pressed and e.position.x > 330 and e.position.x < get_viewport().get_visible_rect().size.x - 370
	elif e is InputEventMouseMotion and dragging:
		spin += e.relative.x * 0.01

func _process(dt: float) -> void:
	if stage == null:
		return
	t += dt
	me.rotation.y = lerp_angle(me.rotation.y, spin, minf(dt * 10.0, 1.0))
	me.idle(t)
	for c in others:
		if c:
			c.idle(t + 1.3)
	_place_labels()

func _place_labels() -> void:
	if cam == null or slot_buttons.is_empty():
		return
	for s in 2:
		var sp := cam.unproject_position(SLOT_POS[s] + Vector3(0, 1.0, 0))
		slot_buttons[s].position = sp - slot_buttons[s].size / 2.0
		var np := cam.unproject_position(SLOT_POS[s] + Vector3(0, 2.0, 0))
		slot_names[s].position = np - Vector2(slot_names[s].size.x / 2.0, 0)
	var mn: Label = ui.get_child(0).get_node("MeName")
	mn.text = Game.my_name()
	var mp := cam.unproject_position(Vector3(0, 2.05, 0))
	mn.position = mp - Vector2(mn.size.x / 2.0, 0)
