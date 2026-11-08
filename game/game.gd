extends Node
## Global state, input map, asset helpers. Autoloaded as "Game".

signal noise(pos: Vector3, radius: float)
signal message(text: String, color: Color)

const VERSION := "0.4.0"
const L_WORLD := 1
const L_STRUCT := 2
const L_PLAYER := 4
const L_ZOMBIE := 8
const L_HARVEST := 16

var mode := "zombie"            # "last_standing" | "zombie"
var storm_enabled := false
var zombies_enabled := true
var world
var player
var smoke := false              # automated test run (command line: -- --smoke)
# developer panel (P)
var dev_zombies_chase := true
var dev_god := false
var dev_free_build := false

var _cache := {}

func _ready() -> void:
	_setup_input()
	smoke = "--smoke" in OS.get_cmdline_user_args()

func make_noise(pos: Vector3, radius: float) -> void:
	noise.emit(pos, radius)

func msg(text: String, color := Color(1, 1, 1)) -> void:
	message.emit(text, color)

# ---------------------------------------------------------------- input
func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		if k is int and k >= MOUSE_BUTTON_LEFT and k <= MOUSE_BUTTON_XBUTTON2 and k < 32:
			var mb := InputEventMouseButton.new()
			mb.button_index = k
			InputMap.action_add_event(action, mb)
		else:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)

func _setup_input() -> void:
	_key("move_forward", [KEY_W]); _key("move_back", [KEY_S])
	_key("move_left", [KEY_A]); _key("move_right", [KEY_D])
	_key("jump", [KEY_SPACE]); _key("sprint", [KEY_SHIFT]); _key("crouch", [KEY_C])
	_key("fire", [MOUSE_BUTTON_LEFT]); _key("aim", [MOUSE_BUTTON_RIGHT])
	_key("reload", [KEY_R]); _key("build", [KEY_B]); _key("craft", [KEY_Q])
	_key("interact", [KEY_E]); _key("camera", [KEY_V]); _key("horn", [KEY_G]); _key("dev", [KEY_P])
	_key("map", [KEY_M]); _key("ping", [KEY_T]); _key("broadcast", [KEY_Y]); _key("help", [KEY_H])
	for i in 6:
		_key("weapon_%d" % (i + 1), [KEY_1 + i])
	_key("debug_spawn10", [KEY_K]); _key("debug_spawn50", [KEY_L]); _key("debug_clear", [KEY_O])
	_key("debug_stats", [KEY_I]); _key("debug_antidote", [KEY_U]); _key("debug_bags", [KEY_N])

# ---------------------------------------------------------------- assets
## Loads a .glb once and returns its meshes, collision shapes and marker transforms,
## all relative to the asset root. Models face +Z in Godot (Blender -Y).
func asset(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var scene: Node = load(path).instantiate()
	var d := {"meshes": [], "shapes": [], "markers": {}}
	_walk(scene, scene, d)
	scene.free()
	_cache[path] = d
	return d

func _rel(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

func _walk(n: Node, root: Node, d: Dictionary) -> void:
	if n is MeshInstance3D and n.mesh:
		d.meshes.append([n.mesh, _rel(n, root)])
	elif n is CollisionShape3D and n.shape:
		d.shapes.append([n.shape, _rel(n, root)])
	elif n is Node3D and n != root and n.get_child_count() == 0:
		d.markers[str(n.name)] = _rel(n, root)
	for c in n.get_children():
		_walk(c, root, d)

func place_static(d: Dictionary, xform: Transform3D, parent: Node, layer := L_WORLD, vis_range := 0.0) -> Node3D:
	var root := Node3D.new()
	root.transform = xform
	parent.add_child(root)
	for m in d.meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = m[0]
		mi.transform = m[1]
		if vis_range > 0.0:
			mi.visibility_range_end = vis_range
		root.add_child(mi)
	if d.shapes.size() > 0:
		var sb := StaticBody3D.new()
		sb.collision_layer = layer
		sb.collision_mask = 0
		root.add_child(sb)
		for s in d.shapes:
			var cs := CollisionShape3D.new()
			cs.shape = s[0]
			cs.transform = s[1]
			sb.add_child(cs)
	return root

# ---------------------------------------------------------------- map grid
const TILE := 64.0
const MAP_SIZE := 384.0

func sector(p: Vector3) -> String:
	var fx = (p.x + MAP_SIZE / 2.0) / TILE
	var fz = (p.z + MAP_SIZE / 2.0) / TILE
	var n := int(MAP_SIZE / TILE)
	var col := clampi(int(floor(fx)), 0, n - 1)
	var row := clampi(int(floor(fz)), 0, n - 1)
	var sx := clampi(int((fx - floor(fx)) * 3.0), 0, 2)
	var sz := clampi(int((fz - floor(fz)) * 3.0), 0, 2)
	var pad: int = [7, 8, 9, 4, 5, 6, 1, 2, 3][sz * 3 + sx]
	return "%s%d-%d" % [char(65 + col), row + 1, pad]
