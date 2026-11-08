extends Node3D
## Block character built from a "look" dictionary. Used for the lobby, the player's own body in
## vehicles, and other players in multiplayer. Faces -Z, feet at y = 0.
## Joints: hips > torso > head, shoulders > arms, hips > thighs > knees > shins.

const PRESETS := {
	# Default playable skin (reference photos from the family, 2026-11-08): navy hoodie with white
	# drawstrings and a kangaroo pocket, loose grey joggers with cuffs, swept dark-blond hair, barefoot.
	"Hoodie": {"skin": 0, "hair": "swept", "hair_col": 2, "top": "hoodie", "top_col": Color(0.07, 0.09, 0.16),
		"tie": null, "pants": "joggers", "pants_col": Color(0.64, 0.64, 0.63), "feet": "barefoot", "glasses": false, "beard": "none", "height": 0.97},
	# The original player look (seated driver body up to v0.7).
	"Suit": {"skin": 2, "hair": "short", "hair_col": 1, "top": "suit", "top_col": Color(0.035, 0.05, 0.10),
		"tie": Color(0.45, 0.04, 0.04), "pants": "straight", "pants_col": Color(0.035, 0.05, 0.10), "feet": "shoes", "glasses": false, "beard": "none", "height": 1.0},
	# The eight zombie outfits (game/zombie.gd OUTFITS), alive.
	"Car dealer": {"skin": 2, "hair": "short", "hair_col": 4, "top": "suit", "top_col": Color(0.32, 0.30, 0.28),
		"tie": Color(0.15, 0.35, 0.20), "pants": "straight", "pants_col": Color(0.25, 0.24, 0.22), "feet": "shoes", "glasses": true, "beard": "moustache", "height": 1.0},
	"Office worker": {"skin": 1, "hair": "short", "hair_col": 1, "top": "suit", "top_col": Color(0.12, 0.14, 0.22),
		"tie": Color(0.45, 0.05, 0.05), "pants": "straight", "pants_col": Color(0.10, 0.11, 0.16), "feet": "shoes", "glasses": false, "beard": "none", "height": 1.0},
	"Grey-blue shirt": {"skin": 3, "hair": "short", "hair_col": 1, "top": "shirt", "top_col": Color(0.33, 0.37, 0.44),
		"tie": null, "pants": "straight", "pants_col": Color(0.22, 0.20, 0.18), "feet": "boots", "glasses": false, "beard": "moustache", "height": 1.0},
	"Rust and jeans": {"skin": 0, "hair": "long", "hair_col": 0, "top": "shirt", "top_col": Color(0.52, 0.30, 0.24),
		"tie": null, "pants": "straight", "pants_col": Color(0.18, 0.22, 0.30), "feet": "sneakers", "glasses": false, "beard": "none", "height": 0.98},
	"Pensioner": {"skin": 1, "hair": "short", "hair_col": 4, "top": "jacket", "top_col": Color(0.56, 0.54, 0.46),
		"tie": null, "pants": "straight", "pants_col": Color(0.28, 0.27, 0.22), "feet": "shoes", "glasses": true, "beard": "none", "height": 0.96},
	"Green jacket": {"skin": 4, "hair": "short", "hair_col": 3, "top": "jacket", "top_col": Color(0.20, 0.30, 0.22),
		"tie": null, "pants": "straight", "pants_col": Color(0.12, 0.12, 0.13), "feet": "boots", "glasses": false, "beard": "beard", "height": 1.02},
	"Red hoodie": {"skin": 3, "hair": "short", "hair_col": 0, "top": "hoodie", "top_col": Color(0.62, 0.22, 0.20),
		"tie": null, "pants": "joggers", "pants_col": Color(0.30, 0.32, 0.36), "feet": "sneakers", "glasses": false, "beard": "none", "height": 0.99},
	"Blue tie": {"skin": 2, "hair": "swept", "hair_col": 1, "top": "suit", "top_col": Color(0.40, 0.38, 0.34),
		"tie": Color(0.20, 0.20, 0.45), "pants": "straight", "pants_col": Color(0.30, 0.28, 0.26), "feet": "shoes", "glasses": false, "beard": "none", "height": 1.0},
}
const PRESET_ORDER := ["Hoodie", "Suit", "Car dealer", "Office worker", "Grey-blue shirt", "Rust and jeans", "Pensioner", "Green jacket", "Red hoodie", "Blue tie"]
const SKINS := [Color(0.93, 0.76, 0.66), Color(0.88, 0.68, 0.55), Color(0.62, 0.44, 0.33), Color(0.45, 0.30, 0.20), Color(0.30, 0.20, 0.13)]
const HAIR_COLS := [Color(0.10, 0.07, 0.05), Color(0.22, 0.14, 0.08), Color(0.42, 0.30, 0.17), Color(0.75, 0.60, 0.35), Color(0.55, 0.55, 0.52), Color(0.45, 0.16, 0.08)]
const HAIRS := ["swept", "short", "long", "buzz", "bald"]
const TOPS := ["hoodie", "suit", "shirt", "jacket", "vest"]
const PANTS := ["joggers", "straight"]
const FEET := ["barefoot", "sneakers", "shoes", "boots"]
const BEARDS := ["none", "moustache", "beard"]
const TOP_COLS := [Color(0.07, 0.09, 0.16), Color(0.035, 0.05, 0.10), Color(0.12, 0.12, 0.13), Color(0.62, 0.22, 0.20),
	Color(0.20, 0.30, 0.22), Color(0.33, 0.37, 0.44), Color(0.52, 0.30, 0.24), Color(0.56, 0.54, 0.46), Color(0.85, 0.85, 0.82), Color(0.80, 0.62, 0.15)]
const PANTS_COLS := [Color(0.64, 0.64, 0.63), Color(0.18, 0.22, 0.30), Color(0.12, 0.12, 0.13), Color(0.035, 0.05, 0.10),
	Color(0.28, 0.27, 0.22), Color(0.45, 0.38, 0.25), Color(0.30, 0.32, 0.36)]

const HIP := 0.92
const THIGH := 0.46
const SHIN := 0.46

var look := {}
var rig: Node3D
var torso: Node3D
var head: Node3D
var arms: Array = []      # [left, right] shoulder joints
var legs: Array = []      # [left, right] hip joints
var knees: Array = []
var _phase := 0.0
var _mats := {}

static func default_look() -> Dictionary:
	return PRESETS["Hoodie"].duplicate()

## Looks travel over the network and into the settings file; colours as arrays, nothing else.
static func pack(l: Dictionary) -> Dictionary:
	var out := {}
	for k in l:
		var val = l[k]
		out[k] = [val.r, val.g, val.b] if val is Color else val
	return out

static func unpack(d: Dictionary) -> Dictionary:
	var out := default_look()
	for k in d:
		var val = d[k]
		if val is Array and val.size() == 3:
			val = Color(val[0], val[1], val[2])
		out[k] = val
	return out

func _m(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	_mats[key] = m
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _m(col)
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j

func build(l: Dictionary) -> void:
	look = l
	for c in get_children():
		c.queue_free()
	arms.clear()
	legs.clear()
	knees.clear()
	var skin: Color = SKINS[int(l.get("skin", 0)) % SKINS.size()]
	var hair_c: Color = HAIR_COLS[int(l.get("hair_col", 1)) % HAIR_COLS.size()]
	var top: Color = l.get("top_col", Color(0.1, 0.1, 0.2))
	var pants: Color = l.get("pants_col", Color(0.5, 0.5, 0.5))
	var style: String = l.get("top", "hoodie")
	rig = _joint(self, Vector3.ZERO)
	var s: float = l.get("height", 1.0)
	rig.scale = Vector3(s, s, s)
	var hips := _joint(rig, Vector3(0, HIP, 0))
	# ---- torso
	torso = _joint(hips, Vector3.ZERO)
	var loose: bool = l.get("pants", "straight") == "joggers"
	_box(torso, Vector3(0.38 if loose else 0.36, 0.14, 0.22), Vector3(0, 0.02, 0), pants)    # seat of the trousers
	match style:
		"hoodie":
			_box(torso, Vector3(0.42, 0.56, 0.25), Vector3(0, 0.33, 0), top)
			_box(torso, Vector3(0.43, 0.06, 0.26), Vector3(0, 0.06, 0), top.darkened(0.15))       # ribbed hem
			_box(torso, Vector3(0.26, 0.15, 0.012), Vector3(0, 0.17, -0.128), top.darkened(0.12))  # kangaroo pocket
			_box(torso, Vector3(0.24, 0.012, 0.014), Vector3(0, 0.245, -0.129), top.darkened(0.25))
			for x in [-0.045, 0.045]:                                                              # drawstrings
				_box(torso, Vector3(0.022, 0.20, 0.012), Vector3(x, 0.47, -0.13), Color(0.90, 0.88, 0.82))
			_box(torso, Vector3(0.30, 0.10, 0.14), Vector3(0, 0.62, 0.07), top.darkened(0.05))   # hood lying on the back
			_box(torso, Vector3(0.24, 0.16, 0.05), Vector3(0, 0.52, 0.14), top.darkened(0.08))
			for x in [-0.12, 0.12]:
				_box(torso, Vector3(0.06, 0.08, 0.18), Vector3(x, 0.62, -0.02), top.darkened(0.05))
		"suit":
			_box(torso, Vector3(0.40, 0.55, 0.24), Vector3(0, 0.33, 0), top)
			_box(torso, Vector3(0.12, 0.30, 0.01), Vector3(0, 0.45, -0.122), Color(0.92, 0.92, 0.90))
			for x in [-0.075, 0.075]:
				_box(torso, Vector3(0.05, 0.26, 0.012), Vector3(x, 0.46, -0.124), top.darkened(0.2), Vector3(0, 0, -x * 2.0))
			if l.get("tie") != null:
				_box(torso, Vector3(0.045, 0.28, 0.012), Vector3(0, 0.43, -0.128), l.tie)
		"shirt":
			_box(torso, Vector3(0.38, 0.55, 0.23), Vector3(0, 0.33, 0), top)
			for k in 4:
				_box(torso, Vector3(0.02, 0.02, 0.01), Vector3(0, 0.18 + k * 0.12, -0.118), top.darkened(0.35))
			_box(torso, Vector3(0.20, 0.05, 0.20), Vector3(0, 0.60, 0), top.lightened(0.1))
			if l.get("tie") != null:
				_box(torso, Vector3(0.045, 0.28, 0.012), Vector3(0, 0.43, -0.122), l.tie)
		"jacket":
			_box(torso, Vector3(0.36, 0.52, 0.21), Vector3(0, 0.33, 0), Color(0.85, 0.85, 0.82))  # shirt under
			_box(torso, Vector3(0.42, 0.56, 0.25), Vector3(0, 0.33, 0.012), top)
			_box(torso, Vector3(0.10, 0.50, 0.03), Vector3(0, 0.33, -0.118), Color(0.85, 0.85, 0.82))  # open front
			_box(torso, Vector3(0.30, 0.06, 0.24), Vector3(0, 0.61, 0.01), top.darkened(0.1))   # collar
		"vest":
			_box(torso, Vector3(0.38, 0.55, 0.23), Vector3(0, 0.33, 0), top.lightened(0.15))
			_box(torso, Vector3(0.44, 0.40, 0.29), Vector3(0, 0.38, 0), Color(0.26, 0.32, 0.20))  # tactical vest
			for x in [-0.1, 0.1]:
				_box(torso, Vector3(0.12, 0.12, 0.04), Vector3(x, 0.30, -0.16), Color(0.22, 0.27, 0.17))
	# ---- head
	head = _joint(torso, Vector3(0, 0.62, 0))
	_box(head, Vector3(0.10, 0.08, 0.10), Vector3(0, 0.03, 0), skin)
	_box(head, Vector3(0.22, 0.25, 0.23), Vector3(0, 0.19, 0), skin)
	_box(head, Vector3(0.035, 0.05, 0.03), Vector3(0, 0.17, -0.125), skin.darkened(0.08))     # nose
	for x in [-0.05, 0.05]:
		_box(head, Vector3(0.035, 0.03, 0.01), Vector3(x, 0.21, -0.117), Color(0.95, 0.95, 0.95))
		_box(head, Vector3(0.018, 0.022, 0.01), Vector3(x, 0.21, -0.121), Color(0.25, 0.18, 0.12))
		_box(head, Vector3(0.05, 0.012, 0.01), Vector3(x, 0.245, -0.118), hair_c.darkened(0.2))  # eyebrows
		_box(head, Vector3(0.02, 0.05, 0.04), Vector3(x * 2.3, 0.19, 0.0), skin.darkened(0.05))   # ears
	_box(head, Vector3(0.07, 0.012, 0.01), Vector3(0, 0.115, -0.117), skin.darkened(0.3))      # mouth
	var hl := hair_c.lightened(0.25)
	match l.get("hair", "short"):
		"swept":   # medium-length, swept over the forehead from a side parting, lighter ends
			_box(head, Vector3(0.25, 0.07, 0.26), Vector3(0, 0.33, 0.005), hair_c)
			_box(head, Vector3(0.25, 0.20, 0.06), Vector3(0, 0.22, 0.11), hair_c)                # back, to the neck
			_box(head, Vector3(0.24, 0.06, 0.05), Vector3(0, 0.11, 0.105), hair_c.darkened(0.1))
			for x in [-0.12, 0.12]:
				_box(head, Vector3(0.03, 0.15, 0.20), Vector3(x, 0.25, 0.02), hair_c)             # sides over the ears
			_box(head, Vector3(0.20, 0.06, 0.05), Vector3(0.02, 0.29, -0.115), hl, Vector3(0, 0, -0.18))  # fringe
			_box(head, Vector3(0.10, 0.05, 0.04), Vector3(-0.07, 0.31, -0.12), hl, Vector3(0, 0, 0.3))
			_box(head, Vector3(0.18, 0.04, 0.12), Vector3(0.03, 0.375, -0.04), hl, Vector3(0.2, 0, -0.1))  # messy top
		"short":
			_box(head, Vector3(0.24, 0.06, 0.25), Vector3(0, 0.33, 0.005), hair_c)
			_box(head, Vector3(0.24, 0.15, 0.04), Vector3(0, 0.26, 0.11), hair_c)
			for x in [-0.115, 0.115]:
				_box(head, Vector3(0.02, 0.08, 0.16), Vector3(x, 0.28, 0.03), hair_c)
		"long":
			_box(head, Vector3(0.25, 0.07, 0.26), Vector3(0, 0.33, 0.005), hair_c)
			_box(head, Vector3(0.26, 0.38, 0.07), Vector3(0, 0.15, 0.11), hair_c)
			for x in [-0.125, 0.125]:
				_box(head, Vector3(0.03, 0.32, 0.20), Vector3(x, 0.17, 0.02), hair_c)
			_box(head, Vector3(0.22, 0.05, 0.04), Vector3(0, 0.30, -0.115), hair_c)
		"buzz":
			_box(head, Vector3(0.23, 0.03, 0.24), Vector3(0, 0.32, 0.003), hair_c.darkened(0.1))
	match l.get("beard", "none"):
		"moustache":
			_box(head, Vector3(0.12, 0.025, 0.02), Vector3(0, 0.135, -0.12), hair_c)
		"beard":
			_box(head, Vector3(0.23, 0.12, 0.08), Vector3(0, 0.10, -0.085), hair_c)
			_box(head, Vector3(0.12, 0.025, 0.02), Vector3(0, 0.14, -0.125), hair_c)
	if l.get("glasses", false):
		_box(head, Vector3(0.20, 0.018, 0.02), Vector3(0, 0.215, -0.127), Color(0.08, 0.08, 0.08))
		for x in [-0.05, 0.05]:
			_box(head, Vector3(0.06, 0.045, 0.006), Vector3(x, 0.21, -0.13), Color(0.6, 0.75, 0.85, 1.0))
	# ---- arms (hang along -Y from the shoulder)
	var sleeve := top if style != "vest" else top.lightened(0.15)
	for side in [-1.0, 1.0]:
		var a := _joint(torso, Vector3(side * 0.27, 0.56, 0))
		_box(a, Vector3(0.11, 0.56, 0.11), Vector3(0, -0.26, 0), sleeve)
		if style == "hoodie":
			_box(a, Vector3(0.115, 0.06, 0.115), Vector3(0, -0.52, 0), sleeve.darkened(0.15))    # cuff
		_box(a, Vector3(0.09, 0.10, 0.09), Vector3(0, -0.60, 0), skin)
		arms.append(a)
	# ---- legs
	var feet: String = l.get("feet", "shoes")
	for side in [-1.0, 1.0]:
		var hip := _joint(hips, Vector3(side * 0.1, 0, 0))
		var w := 0.17 if loose else 0.15
		_box(hip, Vector3(w, THIGH, w + 0.01), Vector3(0, -THIGH / 2.0, 0), pants)
		var knee := _joint(hip, Vector3(0, -THIGH, 0))
		_box(knee, Vector3(w - 0.01, SHIN - 0.06, w), Vector3(0, -(SHIN - 0.06) / 2.0, 0), pants)
		if loose:
			_box(knee, Vector3(w - 0.03, 0.05, w - 0.02), Vector3(0, -SHIN + 0.08, 0), pants.darkened(0.12))   # cuff
		match feet:
			"barefoot":
				_box(knee, Vector3(0.10, 0.06, 0.22), Vector3(0, -SHIN + 0.03, -0.04), skin)
				_box(knee, Vector3(0.10, 0.025, 0.03), Vector3(0, -SHIN + 0.012, -0.16), skin.darkened(0.06))  # toes
			"sneakers":
				_box(knee, Vector3(0.12, 0.08, 0.26), Vector3(0, -SHIN + 0.04, -0.05), Color(0.92, 0.92, 0.90))
				_box(knee, Vector3(0.125, 0.025, 0.27), Vector3(0, -SHIN + 0.012, -0.05), Color(0.2, 0.2, 0.22))
			"shoes":
				_box(knee, Vector3(0.11, 0.07, 0.25), Vector3(0, -SHIN + 0.035, -0.05), Color(0.04, 0.03, 0.03))
			"boots":
				_box(knee, Vector3(0.13, 0.16, 0.15), Vector3(0, -SHIN + 0.10, 0), Color(0.28, 0.18, 0.10))
				_box(knee, Vector3(0.13, 0.08, 0.27), Vector3(0, -SHIN + 0.04, -0.06), Color(0.28, 0.18, 0.10))
		legs.append(hip)
		knees.append(knee)

## Walking: speed in m/s. Swings legs and arms; blends back to standing when still.
func animate(dt: float, speed: float) -> void:
	if legs.size() < 2:
		return
	var k := clampf(speed / 5.0, 0.0, 1.4)
	_phase += dt * (3.0 + speed * 1.6)
	var sw := sin(_phase) * 0.6 * k
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		legs[i].rotation.x = lerpf(legs[i].rotation.x, sgn * sw, minf(dt * 12.0, 1.0))
		knees[i].rotation.x = lerpf(knees[i].rotation.x, -maxf(0.0, -sgn * sin(_phase + 0.6)) * 0.8 * k, minf(dt * 12.0, 1.0))
		arms[i].rotation.x = lerpf(arms[i].rotation.x, -sgn * sw * 0.8, minf(dt * 12.0, 1.0))
		arms[i].rotation.z = 0.0
	rig.position.y = absf(sin(_phase)) * 0.03 * k

## Seated, hips at the node origin, hands forward on a wheel or handlebars.
func sit() -> void:
	var s: float = look.get("height", 1.0)
	rig.position = Vector3(0, -HIP * s, 0)
	for i in 2:
		legs[i].rotation.x = PI / 2.0
		knees[i].rotation.x = -PI / 2.0
		arms[i].rotation.x = 1.15
		arms[i].rotation.z = 0.0

## Lobby idle: slight breathing, arms a little out (like the A-pose in the photos).
func idle(t: float) -> void:
	if arms.size() < 2:
		return
	for i in 2:
		legs[i].rotation.x = 0.0
		knees[i].rotation.x = 0.0
		arms[i].rotation.x = 0.0
		arms[i].rotation.z = (-1.0 if i == 0 else 1.0) * (0.18 + sin(t * 1.6) * 0.02)
	torso.position.y = sin(t * 1.6) * 0.006
	head.rotation.y = sin(t * 0.5) * 0.25
