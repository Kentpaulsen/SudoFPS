extends Node
## Player settings, saved to user://settings.cfg (browser: stored by the browser). Autoloaded as "Settings".

signal changed

const PRESETS := {
	"Low": {"render_scale": 0.6, "shadows": false, "grass": 0.25, "view_distance": 150.0},
	"Medium": {"render_scale": 0.8, "shadows": true, "grass": 0.6, "view_distance": 250.0},
	"High": {"render_scale": 1.0, "shadows": true, "grass": 1.0, "view_distance": 400.0},
}
const DEFAULTS := {
	"preset": "Medium", "render_scale": 0.8, "shadows": true, "grass": 0.6, "view_distance": 250.0,
	"fullscreen": false, "vsync": true, "max_fps": 0, "fov": 75.0,
	"sensitivity": 1.0, "invert_y": false, "bodycam": false, "master_volume": 0.9, "day_length_min": 14.0,
}
## Actions the player can rebind, in the order shown in the Controls tab.
const BINDABLE := [
	["move_forward", "Forward"], ["move_back", "Back"], ["move_left", "Left"], ["move_right", "Right"],
	["jump", "Jump / brake"], ["sprint", "Sprint"], ["crouch", "Crouch"], ["reload", "Reload / rotate piece"],
	["interact", "Use / enter vehicle"], ["build", "Build wheel"], ["craft", "Crafting"], ["map", "Map"],
	["ping", "Team ping"], ["broadcast", "Open broadcast"], ["horn", "Horn"], ["camera", "Vehicle camera"],
	["help", "Help"], ["dev", "Developer panel"], ["nightvision", "Night vision"],
]

var v := {}
var _default_keys := {}
const PATH := "user://settings.cfg"

func _ready() -> void:
	v = DEFAULTS.duplicate()
	# Game (autoloaded first) has built the input map; remember it for "reset controls"
	for b in BINDABLE:
		_default_keys[b[0]] = InputMap.action_get_events(b[0]).duplicate()
	load_settings()
	apply()

func get_v(key: String):
	return v.get(key, DEFAULTS.get(key))

func set_v(key: String, value) -> void:
	v[key] = value
	if key in ["render_scale", "shadows", "grass", "view_distance"]:
		v["preset"] = "Custom"
	apply()
	save_settings()

func set_preset(name: String) -> void:
	for k in PRESETS[name]:
		v[k] = PRESETS[name][k]
	v["preset"] = name
	apply()
	save_settings()

func apply() -> void:
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = clampf(v.render_scale, 0.4, 1.0)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if v.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode and not Game.smoke:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(v.max_fps)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v.master_volume, 0.0001)))
	changed.emit()

func toggle_fullscreen() -> void:
	set_v("fullscreen", not v.fullscreen)

# ---------------------------------------------------------------- key bindings
func key_name(action: String) -> String:
	var names: Array = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			names.append(OS.get_keycode_string(e.physical_keycode) if e.physical_keycode else e.as_text())
		elif e is InputEventMouseButton:
			names.append(["", "Left mouse", "Right mouse", "Middle mouse"][clampi(e.button_index, 0, 3)])
	return ", ".join(names) if not names.is_empty() else "(none)"

func rebind(action: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_settings()

func reset_keys() -> void:
	for a in _default_keys:
		InputMap.action_erase_events(a)
		for e in _default_keys[a]:
			InputMap.action_add_event(a, e)
	save_settings()

# ---------------------------------------------------------------- persistence
func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in v:
		cf.set_value("settings", k, v[k])
	for b in BINDABLE:
		var codes: Array = []
		for e in InputMap.action_get_events(b[0]):
			if e is InputEventKey:
				codes.append(e.physical_keycode)
		cf.set_value("keys", b[0], codes)
	cf.save(PATH)

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in DEFAULTS:
		v[k] = cf.get_value("settings", k, DEFAULTS[k])
	for b in BINDABLE:
		var codes = cf.get_value("keys", b[0], null)
		if codes is Array and not codes.is_empty():
			InputMap.action_erase_events(b[0])
			for c in codes:
				var e := InputEventKey.new()
				e.physical_keycode = int(c)
				InputMap.action_add_event(b[0], e)
