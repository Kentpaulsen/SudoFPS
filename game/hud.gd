extends CanvasLayer
## HUD, map, crafting panel and overlays.

const PIECE_COL := Color(0.95, 0.9, 0.7)
var canvas: Control
var fx: ColorRect
var fx_mat: ShaderMaterial
var craft_panel: PanelContainer
var death_panel: PanelContainer
var dev_panel: PanelContainer
var talk_panel: PanelContainer
var cam_fx: ColorRect
var cam_mat: ShaderMaterial
var talk_text: Label
var talk_buttons: VBoxContainer
var msgs: Array = []          # [text, color, time]
var show_help := false
var show_stats := true
var font: Font
var _fps_t := 0.0
var _fps := 0



func _ready() -> void:
	font = ThemeDB.fallback_font
	fx = ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform vec4 tint = vec4(0.0);
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(g) * vec3(0.8, 1.0, 0.75), amount * 0.8);
	float v = distance(UV, vec2(0.5));
	c *= 1.0 - smoothstep(0.3, 0.75, v) * amount * 0.9;
	c = mix(c, tint.rgb, tint.a * (0.4 + 0.6 * smoothstep(0.2, 0.75, v)));
	COLOR = vec4(c, 1.0);
}
"""
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = sh
	fx.material = fx_mat
	add_child(fx)
	cam_fx = ColorRect.new()
	cam_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csh := Shader.new()
	csh.code = """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float distort = 0.0;
uniform float nv = 0.0;
uniform float time = 0.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + time * 37.0) * 43758.5453); }
void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float r2 = dot(c, c);
	vec2 uv = 0.5 + c * (1.0 - distort * 0.32 * r2);           // barrel lens
	float ca = distort * 0.006 * r2 * 4.0;
	vec3 col = vec3(texture(screen, uv + c * ca).r, texture(screen, uv).g, texture(screen, uv - c * ca).b);
	float g = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(g), distort * 0.25);
	col = (col - 0.5) * (1.0 + distort * 0.15) + 0.5;
	if (nv > 0.5) {
		float l = clamp(pow(g * 3.2, 0.9) + 0.03, 0.0, 1.2);
		col = vec3(0.12, 1.0, 0.28) * l;
		col *= 0.92 + 0.08 * sin(SCREEN_UV.y * 900.0);
	}
	float grain = (rnd(SCREEN_UV * 731.0) - 0.5) * (0.06 * distort + 0.12 * nv);
	col += grain;
	col *= 1.0 - smoothstep(0.18, 0.55, r2) * (0.75 * distort + 0.4 * nv);
	COLOR = vec4(col, 1.0);
}
"""
	cam_mat = ShaderMaterial.new()
	cam_mat.shader = csh
	cam_fx.material = cam_mat
	cam_fx.visible = false
	add_child(cam_fx)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_paint)
	add_child(canvas)
	_make_craft_panel()
	_make_death_panel()
	_make_dev_panel()
	_make_talk_panel()
	Game.message.connect(func(t, c): msgs.append([t, c, Time.get_ticks_msec() / 1000.0]))

func _make_craft_panel() -> void:
	craft_panel = PanelContainer.new()
	Game.center(craft_panel, Vector2(400, 300))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	craft_panel.add_child(box)
	var t := Label.new()
	t.text = "CRAFTING"
	t.add_theme_font_size_override("font_size", 26)
	box.add_child(t)
	var r := Label.new()
	r.text = "Sandbag = 1 fibre + 2 stone"
	box.add_child(r)
	for n in [1, 5, 20]:
		var b := Button.new()
		b.text = "Craft %d sandbag%s" % [n, "" if n == 1 else "s"]
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(func(): Game.player.craft("sandbag", n))
		box.add_child(b)
	var close := Button.new()
	close.text = "Close (Q)"
	close.pressed.connect(func():
		Game.player.craft_open = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	box.add_child(close)
	craft_panel.visible = false
	add_child(craft_panel)

func _make_talk_panel() -> void:
	talk_panel = PanelContainer.new()
	talk_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	talk_panel.custom_minimum_size = Vector2(620, 0)
	talk_panel.offset_left = -310
	talk_panel.offset_right = 310
	talk_panel.offset_top = -280
	talk_panel.offset_bottom = -40
	talk_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	talk_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	talk_panel.add_child(box)
	talk_text = Label.new()
	talk_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	talk_text.add_theme_font_size_override("font_size", 18)
	box.add_child(talk_text)
	talk_buttons = VBoxContainer.new()
	box.add_child(talk_buttons)
	talk_panel.visible = false
	add_child(talk_panel)

## Dialogue with Bjørn: pick the Tike or the motorbike and it appears in the showroom.
func _show_talk(n) -> void:
	for c in talk_buttons.get_children():
		c.queue_free()
	talk_text.text = "%s (car dealer):\n\"Hei! You're the first customer since the dead started walking. Everything here is free now. What do you fancy?\"" % n.npc_name
	for opt in [["The Tike  (tough little 4x4, 54 km/h)", "tike"], ["The motorbike  (leans in the turns, 68 km/h)", "bike"], ["The ATV  (quad bike, 61 km/h)", "atv"], ["The sport sedan  (80s rocket, 108 km/h)", "sedan"], ["Nothing, thanks. Bye!", ""]]:
		var b := Button.new()
		b.text = opt[0]
		b.custom_minimum_size = Vector2(0, 42)
		b.pressed.connect(_choose.bind(n, opt[1]))
		talk_buttons.add_child(b)

func _choose(n, kind: String) -> void:
	if kind == "":
		Game.player.end_talk()
		return
	Game.world.give_vehicle(kind)
	Game.msg("%s: \"Good choice! It's waiting by the big door. Mind the zombies.\"" % n.npc_name, Color(1, 0.9, 0.6))
	Sfx.play("craft")
	Game.player.end_talk()

func _make_dev_panel() -> void:
	dev_panel = PanelContainer.new()
	Game.center(dev_panel, Vector2(440, 340))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	dev_panel.add_child(box)
	var t := Label.new()
	t.text = "DEVELOPER MODE"
	t.add_theme_font_size_override("font_size", 26)
	box.add_child(t)
	var opts := [["Zombies chase me", "dev_zombies_chase"], ["God mode (no damage, no infection)", "dev_god"],
				 ["Free building (no sandbag cost)", "dev_free_build"]]
	for o in opts:
		var cb := CheckButton.new()
		cb.text = o[0]
		cb.button_pressed = Game.get(o[1])
		cb.toggled.connect(func(on): Game.set(o[1], on))
		box.add_child(cb)
	var stats := CheckButton.new()
	stats.text = "Show stats (FPS, zombie count)"
	stats.button_pressed = show_stats
	stats.toggled.connect(func(on): show_stats = on)
	box.add_child(stats)
	var row := HBoxContainer.new()
	box.add_child(row)
	for b in [["+10 zombies", 10], ["+50 zombies", 50]]:
		var bt := Button.new()
		bt.text = b[0]
		bt.pressed.connect(func(): if Game.world.director: Game.world.director.stress(b[1]))
		row.add_child(bt)
	var heli := Button.new()
	heli.text = "Spawn helicopter"
	heli.pressed.connect(func():
		Game.world.spawn_heli()
		Game.player.dev_open = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	box.add_child(heli)
	var clr := Button.new()
	clr.text = "Remove zombies"
	clr.pressed.connect(func(): if Game.world.director: Game.world.director.clear_all())
	row.add_child(clr)
	var close := Button.new()
	close.text = "Close (P)"
	close.pressed.connect(func():
		Game.player.dev_open = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	box.add_child(close)
	dev_panel.visible = false
	add_child(dev_panel)

func _make_death_panel() -> void:
	death_panel = PanelContainer.new()
	Game.center(death_panel, Vector2(340, 150))
	var box := VBoxContainer.new()
	death_panel.add_child(box)
	var t := Label.new()
	t.text = "YOU DIED"
	t.add_theme_font_size_override("font_size", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b := Button.new()
	b.text = "Respawn"
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(func(): Game.player.respawn())
	box.add_child(b)
	death_panel.visible = false
	add_child(death_panel)

func _process(dt: float) -> void:
	var pl = Game.player
	if pl == null:
		return
	if Input.is_action_just_pressed("help"):
		show_help = not show_help
	if Input.is_action_just_pressed("debug_stats"):
		show_stats = not show_stats
	_fps_t += dt
	if _fps_t > 0.5:
		_fps_t = 0.0
		_fps = int(Engine.get_frames_per_second())
	craft_panel.visible = pl.craft_open
	death_panel.visible = pl.dead
	dev_panel.visible = pl.dev_open
	if pl.talk_open and not talk_panel.visible:
		_show_talk(pl.talk_npc)
	talk_panel.visible = pl.talk_open
	# screen effects
	var amount = clampf((pl.zomb - 40.0) / 60.0, 0.0, 1.0) if Game.zombies_enabled else 0.0
	var tint := Color(0, 0, 0, 0)
	var st = Game.world.storm
	if st and st.edge_distance(Vector2(pl.global_position.x, pl.global_position.z)) < 0.0:
		tint = Color(0.45, 0.15, 0.7, 0.35)
	if pl.head.global_position.y < 0.0:
		tint = Color(0.05, 0.25, 0.4, 0.55)
	if pl.hurt_flash > 0.0:
		tint = tint.lerp(Color(0.7, 0.0, 0.0, 0.5), clampf(pl.hurt_flash, 0.0, 1.0))
	fx_mat.set_shader_parameter("amount", amount)
	fx_mat.set_shader_parameter("tint", tint)
	fx.visible = amount > 0.0 or tint.a > 0.0
	var body: bool = Settings.get_v("bodycam") and pl.vehicle == null
	cam_fx.visible = body or pl.nightvision
	cam_mat.set_shader_parameter("distort", 1.0 if body else 0.0)
	cam_mat.set_shader_parameter("nv", 1.0 if pl.nightvision else 0.0)
	cam_mat.set_shader_parameter("time", fmod(Time.get_ticks_msec() / 1000.0, 100.0))
	canvas.queue_redraw()

# ---------------------------------------------------------------- drawing helpers
func _text(pos: Vector2, s: String, size := 16, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	canvas.draw_string(font, pos + Vector2(1, 1), s, align, width, size, Color(0, 0, 0, 0.7 * col.a))
	canvas.draw_string(font, pos, s, align, width, size, col)

func _bar(pos: Vector2, size: Vector2, frac: float, col: Color, label: String) -> void:
	canvas.draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.5))
	canvas.draw_rect(Rect2(pos, Vector2(size.x * clampf(frac, 0.0, 1.0), size.y)), col)
	_text(pos + Vector2(6, size.y - 5), label, 14)

func _paint() -> void:
	var pl = Game.player
	if pl == null:
		return
	var vs := canvas.size
	var c := vs / 2.0
	var now := Time.get_ticks_msec() / 1000.0
	# crosshair
	if not pl.build_mode and not pl.dead and pl.vehicle == null:
		var g = 4.0 if pl.aiming else 7.0
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			canvas.draw_line(c + d * g, c + d * (g + 6.0), Color(1, 1, 1, 0.85), 2.0)
		if pl.hit_marker > 0.0:
			var hc = Color(1, 0.2, 0.15) if pl.head_marker else Color(1, 1, 1)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				canvas.draw_line(c + d * 6.0, c + d * 13.0, hc, 2.5)
	# bars
	_bar(Vector2(20, vs.y - 62), Vector2(240, 20), pl.hp / 100.0, Color(0.8, 0.2, 0.2), "Health %d" % ceili(pl.hp))
	if Game.dev_god:
		_text(Vector2(20, vs.y - 74), "GOD MODE", 14, Color(1, 0.85, 0.3))
	if not Game.dev_zombies_chase:
		_text(Vector2(110, vs.y - 74), "ZOMBIES IGNORE YOU", 14, Color(0.6, 1, 0.6))
	if Game.zombies_enabled:
		_bar(Vector2(20, vs.y - 36), Vector2(240, 20), pl.zomb / 100.0, Color(0.4, 0.75, 0.25), "Zombification %d%%" % int(pl.zomb))
	# weapon
	var w: Dictionary = pl.W[pl.cur]
	var ammo_s = "" if w.mode == "melee" else ("RELOADING" if pl.reloading > 0.0 else "%d / %d" % [pl.ammo[pl.cur], w.mag])
	_text(Vector2(vs.x - 320, vs.y - 46), w.name, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 300)
	_text(Vector2(vs.x - 320, vs.y - 20), ammo_s, 18, Color(1, 0.9, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 300)
	# inventory
	var y := vs.y / 2.0 - 60.0
	_text(Vector2(20, y), "MATERIALS", 14, Color(0.8, 0.85, 0.9))
	for k in ["wood", "stone", "metal", "fibre", "sandbags"]:
		y += 22.0
		_text(Vector2(20, y), "%s  %d" % [k.capitalize(), pl.inv[k]], 16, PIECE_COL if k == "sandbags" else Color.WHITE)
	# build mode
	if pl.build_mode:
		var p: Dictionary = Game.world.PIECES[pl.build_kind]
		_text(Vector2(0, vs.y - 110), "BUILD: %s  (%d sandbags)" % [p.name, p.cost], 20, PIECE_COL, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_text(Vector2(0, vs.y - 86), "Left click place   R rotate   Mouse wheel change piece   Right click exit", 14, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if pl.vehicle:
		_text(Vector2(0, vs.y - 110), "%d km/h" % roundi(absf(pl.vehicle.speed) * 3.6), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_text(Vector2(0, vs.y - 84), "G horn    E get out    V camera (test key until the camera stick exists)", 14, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	elif pl.interact_label != "" and not pl.talk_open:
		_text(Vector2(0, c.y + 60), "E  " + pl.interact_label, 20, Color(1, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if pl.wheel_open:
		_wheel(c, pl)
	# minimap and sector
	var mm := Rect2(Vector2(vs.x - 230, 20), Vector2(210, 210))
	_map(mm, false)
	_text(Vector2(mm.position.x, mm.end.y + 22), "Sector  %s" % Game.sector(pl.global_position), 18, Color(0.9, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, mm.size.x)
	_text(Vector2(mm.position.x - 70, 38), Game.world.clock(), 15, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 60)
	var st = Game.world.storm
	if st:
		_text(Vector2(mm.position.x - 100, mm.end.y + 46), st.status(), 15, Color(0.85, 0.6, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, mm.size.x + 100)
	if pl.map_open:
		var s := minf(vs.x, vs.y) - 120.0
		_map(Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), true)
	# stats
	if show_stats:
		var d = Game.world.director
		var lines := ["FPS %d" % _fps, "Mode: %s" % ("Last Standing" if Game.mode == "last_standing" else "Zombie Royale")]
		if d:
			lines.append("Zombies %d  (chasing %d)" % [d.zombies.size(), d.active_count()])
			lines.append("Kills %d   Hordes %d" % [d.kills, d.horde_count])
		for i in lines.size():
			_text(Vector2(20, 30 + i * 20), lines[i], 15, Color(0.85, 0.9, 0.95))
	# messages
	var my := 70.0
	var keep: Array = []
	for m in msgs:
		var age: float = now - m[2]
		if age < 6.0:
			keep.append(m)
	msgs = keep.slice(maxi(0, keep.size() - 5))
	for m in msgs:
		var a := clampf(6.0 - (now - m[2]), 0.0, 1.0)
		var col: Color = m[1]
		col.a = a
		_text(Vector2(0, my), m[0], 18, col, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		my += 26.0
	if Settings.get_v("bodycam") and pl.vehicle == null:
		var blink := int(now * 2.0) % 2 == 0
		if blink:
			canvas.draw_circle(Vector2(vs.x / 2.0 - 170, 32), 7.0, Color(0.9, 0.1, 0.1))
		_text(Vector2(vs.x / 2.0 - 155, 38), "REC   BODYCAM 01   DAY 1  %s%s" % [Game.world.clock(), "   NV" if pl.nightvision else ""], 16, Color(1, 1, 1, 0.9))
	# overlays
	if show_help:
		_panel_text(c, Game.HELP_TEXT)
	elif not pl.captured() and not pl.dead and not pl.craft_open and not pl.dev_open and not pl.talk_open and not Game.smoke and not Game.menu_open:
		canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.45))
		_text(Vector2(0, c.y - 150), "CLICK TO PLAY", 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_panel_text(c + Vector2(0, 40), Game.HELP_TEXT)

func _panel_text(center: Vector2, s: String) -> void:
	var lines := s.split("\n")
	var h := lines.size() * 24.0 + 24.0
	var wdt := 900.0
	canvas.draw_rect(Rect2(center - Vector2(wdt / 2.0, h / 2.0), Vector2(wdt, h)), Color(0.05, 0.06, 0.07, 0.85))
	for i in lines.size():
		_text(Vector2(center.x - wdt / 2.0 + 20, center.y - h / 2.0 + 30 + i * 24), lines[i], 15)

func _wheel(c: Vector2, pl) -> void:
	var r := 120.0
	var sel := -1
	if pl.wheel_vec.length() > 40.0:
		sel = posmod(roundi((pl.wheel_vec.angle() + PI / 2.0) / (PI / 2.0)), 4)
	canvas.draw_circle(c, r + 20.0, Color(0, 0, 0, 0.45))
	var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for i in 4:
		var p: Dictionary = Game.world.PIECES[i]
		var pos: Vector2 = c + dirs[i] * r * 0.72
		var col := PIECE_COL if i == sel else Color(0.75, 0.75, 0.75)
		if i == sel:
			canvas.draw_circle(pos, 46.0, Color(1, 0.9, 0.5, 0.25))
		_text(pos + Vector2(-80, -2), p.name, 15, col, HORIZONTAL_ALIGNMENT_CENTER, 160)
		_text(pos + Vector2(-80, 18), "%d bags" % p.cost, 13, col, HORIZONTAL_ALIGNMENT_CENTER, 160)
	canvas.draw_line(c, c + pl.wheel_vec.limit_length(r * 0.5), Color(1, 1, 1, 0.6), 2.0)

func _map(rect: Rect2, big: bool) -> void:
	var w = Game.world
	var pl = Game.player
	canvas.draw_rect(rect.grow(3), Color(0, 0, 0, 0.6))
	canvas.draw_texture_rect(w.map_texture, rect, false)
	var n := int(Game.MAP_SIZE / Game.TILE)
	var cell := rect.size.x / n
	for i in n + 1:
		var o := i * cell
		canvas.draw_line(rect.position + Vector2(o, 0), rect.position + Vector2(o, rect.size.y), Color(0, 0, 0, 0.35), 1.0)
		canvas.draw_line(rect.position + Vector2(0, o), rect.position + Vector2(rect.size.x, o), Color(0, 0, 0, 0.35), 1.0)
	if big:
		for i in n:
			for j in n:
				_text(rect.position + Vector2(i * cell + 4, j * cell + 16), "%s%d" % [char(65 + i), j + 1], 14, Color(1, 1, 1, 0.85))
	var to_map := func(p: Vector3) -> Vector2:
		return rect.position + Vector2((p.x + Game.MAP_SIZE / 2.0) / Game.MAP_SIZE, (p.z + Game.MAP_SIZE / 2.0) / Game.MAP_SIZE) * rect.size
	var st = w.storm
	if st:
		for pair in [[st.center, st.radius, Color(0.75, 0.35, 1.0)], [st.next_c, st.next_r, Color(1, 1, 1, 0.7)]]:
			if pair[1] <= 0.5 or (pair[2] == Color(1, 1, 1, 0.7) and st.state == "done"):
				continue
			var pts := PackedVector2Array()
			for k in 7:
				var a := deg_to_rad(60.0 * k)
				pts.append(to_map.call(Vector3(pair[0].x + cos(a) * pair[1], 0, pair[0].y + sin(a) * pair[1])))
			canvas.draw_polyline(pts, pair[2], 2.0)
	if pl.ping_t > 0.0:
		var pp: Vector2 = to_map.call(pl.ping_marker)
		canvas.draw_circle(pp, 6.0, Color(0.4, 0.9, 1.0))
	var pp: Vector2 = to_map.call(pl.global_position)
	var f = Vector2(-sin(pl.yaw), -cos(pl.yaw))
	var side := Vector2(f.y, -f.x)
	var sz := 9.0 if big else 7.0
	canvas.draw_colored_polygon(PackedVector2Array([pp + f * sz, pp - f * sz * 0.6 + side * sz * 0.6, pp - f * sz * 0.6 - side * sz * 0.6]), Color(1, 0.95, 0.3))
	if not big:
		for i in n:
			_text(rect.position + Vector2(i * cell + cell / 2.0 - 4, -4), char(65 + i), 11, Color(1, 1, 1, 0.8))
			_text(rect.position + Vector2(-12, i * cell + cell / 2.0 + 4), str(i + 1), 11, Color(1, 1, 1, 0.8))
