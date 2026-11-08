extends CanvasLayer
## In-game menu. Opens with Esc, or by itself whenever the mouse is let go (browsers use Esc to release it).
## Zombie Royale pauses the game; Last Standing keeps running, as a multiplayer match will.

var panel: PanelContainer
var settings: Control
var help_panel: PanelContainer
var title: Label
var resume_btn: Button
var first := true

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	Game.center(panel, Vector2(380, 420))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	resume_btn = _btn(box, "Play", resume)
	_btn(box, "Settings", func(): panel.visible = false; settings.visible = true)
	_btn(box, "Controls", func(): panel.visible = false; help_panel.visible = true)
	_btn(box, "Toggle fullscreen", func(): Settings.toggle_fullscreen())
	_btn(box, "Main menu", func():
		get_tree().paused = false
		Game.menu_open = false
		get_tree().reload_current_scene())
	if not OS.has_feature("web"):
		_btn(box, "Quit game", func(): get_tree().quit())
	settings = load("res://game/settings_ui.gd").new()
	settings.visible = false
	settings.closed.connect(func(): settings.visible = false; panel.visible = true)
	add_child(settings)
	help_panel = PanelContainer.new()
	Game.center(help_panel, Vector2(940, 360))
	var hb := VBoxContainer.new()
	help_panel.add_child(hb)
	var hl := Label.new()
	hl.text = Game.HELP_TEXT
	hb.add_child(hl)
	_btn(hb, "Back", func(): help_panel.visible = false; panel.visible = true)
	help_panel.visible = false
	add_child(help_panel)
	_set_open(false)

func _btn(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	box.add_child(b)
	return b

func _set_open(open: bool) -> void:
	Game.menu_open = open
	visible = open
	panel.visible = open
	settings.visible = false
	help_panel.visible = false

func open_menu() -> void:
	if Game.menu_open:
		return
	_set_open(true)
	title.text = "SudoFPS" if first else ("PAUSED" if Game.mode == "zombie" else "MENU")
	resume_btn.text = "Play" if first else "Resume"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.mode == "zombie":
		get_tree().paused = true

func resume() -> void:
	first = false
	_set_open(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_dt: float) -> void:
	var pl = Game.player
	if Game.smoke or pl == null or Game.menu_open or pl.dead or pl.craft_open or pl.dev_open or pl.talk_open:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		open_menu()

func _unhandled_input(event: InputEvent) -> void:
	# On the web Esc only releases the mouse (handled above); on desktop it toggles the menu.
	if OS.has_feature("web") or Game.smoke:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if Game.menu_open:
			if settings.visible or help_panel.visible:
				settings.visible = false
				help_panel.visible = false
				panel.visible = true
			else:
				resume()
		else:
			open_menu()
		get_viewport().set_input_as_handled()
