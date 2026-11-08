extends Node
## Start menu. Picks a sandbox mode and starts the world.

var ui: CanvasLayer

func _ready() -> void:
	if Game.smoke:
		_start("last_standing" if "--ls" in OS.get_cmdline_user_args() else "zombie")
		return
	ui = CanvasLayer.new()
	add_child(ui)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	ui.add_child(box)
	var title := Label.new()
	title.text = "SudoFPS"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Prototype v%s  -  offline sandbox" % Game.VERSION
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.7, 0.75, 0.8)
	box.add_child(sub)
	box.add_child(_button("Last Standing   (Hex Horizon storm, no zombies)", "last_standing"))
	box.add_child(_button("Zombie Royale   (zombies, no storm)", "zombie"))
	var help := Label.new()
	help.text = "Click the game to grab the mouse. Esc lets go of it.\nPress H in game for all controls."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate = Color(0.6, 0.65, 0.7)
	box.add_child(help)

func _button(text: String, mode: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 60)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(_start.bind(mode))
	return b

func _start(mode: String) -> void:
	Game.mode = mode
	Game.storm_enabled = mode == "last_standing"
	Game.zombies_enabled = mode == "zombie"
	if ui:
		ui.queue_free()
	var w := Node3D.new()
	w.set_script(load("res://game/world.gd"))
	w.name = "World"
	add_child(w)
