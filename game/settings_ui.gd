extends PanelContainer
## Settings screen: Graphics, Audio, Controls (rebindable keys), Gameplay. Used by the start menu and the pause menu.

signal closed

var _widgets := {}
var _waiting := ""
var _waiting_btn: Button
var _key_buttons := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.center(self, Vector2(660, 540))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.add_child(_graphics())
	tabs.add_child(_audio())
	tabs.add_child(_controls())
	tabs.add_child(_gameplay())
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(func(): _waiting = ""; closed.emit())
	root.add_child(back)
	Settings.changed.connect(_refresh)
	_refresh()

func _page(name: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = name
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	sc.add_child(box)
	return box

func _row(box: VBoxContainer, label: String, ctl: Control) -> void:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(250, 0)
	hb.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ctl)
	box.add_child(hb)

func _slider(box: VBoxContainer, label: String, key: String, lo: float, hi: float, step: float, fmt := "%.2f") -> void:
	var hb := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new()
	val.custom_minimum_size = Vector2(60, 0)
	s.value_changed.connect(func(x): val.text = fmt % (x * 100.0 if fmt == "%.0f%%" else x))
	s.drag_ended.connect(func(_c): Settings.set_v(key, s.value))
	hb.add_child(s)
	hb.add_child(val)
	_row(box, label, hb)
	_widgets[key] = [s, val, fmt]

func _check(box: VBoxContainer, label: String, key: String) -> void:
	var c := CheckButton.new()
	c.toggled.connect(func(on): if on != Settings.get_v(key): Settings.set_v(key, on))
	_row(box, label, c)
	_widgets[key] = [c]

func _graphics() -> Control:
	var box := _page("Graphics")
	var preset := OptionButton.new()
	for p in ["Low", "Medium", "High"]:
		preset.add_item(p)
	preset.add_item("Custom")
	preset.item_selected.connect(func(i): if i < 3: Settings.set_preset(preset.get_item_text(i)))
	_row(box, "Quality preset", preset)
	_widgets["preset"] = [preset]
	_slider(box, "Render scale (lower = faster)", "render_scale", 0.4, 1.0, 0.05, "%.0f%%")
	_check(box, "Shadows", "shadows")
	_slider(box, "Grass density", "grass", 0.0, 1.0, 0.05, "%.0f%%")
	_slider(box, "View distance (m)", "view_distance", 100.0, 500.0, 10.0, "%.0f")
	_check(box, "Fullscreen", "fullscreen")
	_check(box, "VSync", "vsync")
	var fps := OptionButton.new()
	for f in ["Unlimited", "30", "60", "120", "144"]:
		fps.add_item(f)
	fps.item_selected.connect(func(i): Settings.set_v("max_fps", [0, 30, 60, 120, 144][i]))
	_row(box, "Frame rate limit", fps)
	_widgets["max_fps"] = [fps]
	var tip := Label.new()
	tip.text = "Slow PC or Chromebook: pick Low, then lower the render scale until it runs smoothly."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.modulate = Color(0.7, 0.75, 0.8)
	box.add_child(tip)
	return box.get_parent()

func _audio() -> Control:
	var box := _page("Audio")
	_slider(box, "Master volume", "master_volume", 0.0, 1.0, 0.05, "%.0f%%")
	return box.get_parent()

func _gameplay() -> Control:
	var box := _page("Gameplay")
	_slider(box, "Field of view", "fov", 60.0, 100.0, 1.0, "%.0f")
	_slider(box, "Mouse sensitivity", "sensitivity", 0.2, 3.0, 0.05, "%.2f")
	_check(box, "Invert mouse Y", "invert_y")
	_slider(box, "Day length (minutes)", "day_length_min", 4.0, 40.0, 1.0, "%.0f")
	return box.get_parent()

func _controls() -> Control:
	var box := _page("Controls")
	var info := Label.new()
	info.text = "Click a key, then press the new key. Esc cancels. Mouse: left fire, right aim/exit build, wheel switch."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.modulate = Color(0.7, 0.75, 0.8)
	box.add_child(info)
	for b in Settings.BINDABLE:
		var btn := Button.new()
		btn.pressed.connect(func():
			_waiting = b[0]
			_waiting_btn = btn
			btn.text = "Press a key...")
		_row(box, b[1], btn)
		_key_buttons[b[0]] = btn
	var reset := Button.new()
	reset.text = "Reset controls to default"
	reset.pressed.connect(func(): Settings.reset_keys(); _refresh())
	box.add_child(reset)
	return box.get_parent()

func _input(event: InputEvent) -> void:
	if _waiting == "" or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			var e := InputEventKey.new()
			e.physical_keycode = event.physical_keycode
			Settings.rebind(_waiting, e)
		_waiting = ""
		_refresh()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	for key in _widgets:
		var w: Array = _widgets[key]
		var val = Settings.get_v(key)
		var c = w[0]
		if c is HSlider:
			c.set_value_no_signal(val)
			var shown: float = val * 100.0 if w[2] == "%.0f%%" else val
			w[1].text = w[2] % shown
		elif c is CheckButton:
			c.set_pressed_no_signal(val)
		elif key == "preset":
			c.select(["Low", "Medium", "High", "Custom"].find(val))
		elif key == "max_fps":
			c.select(maxi([0, 30, 60, 120, 144].find(int(val)), 0))
	for a in _key_buttons:
		_key_buttons[a].text = Settings.key_name(a)
