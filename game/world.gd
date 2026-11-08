extends Node3D
## The island and everything on it. Gameplay changes go through the server_* functions:
## that is the boundary that becomes network calls when multiplayer arrives.

const SIZE := 384.0
const RES := 2.0
var N := int(SIZE / RES) + 1
var heights := PackedFloat32Array()
var seed_value := 0

var trees: Array = []        # [root, pos]
var bushes: Array = []
var rocks: Array = []
var pieces := {}             # edge key -> piece root
var map_texture: ImageTexture
var vehicles: Array = []
var sites: Array = []          # buildings: {kind, pos, rot, half}
var ramps: Array = []
var lamps: Array = []          # [OmniLight3D]
var doors: Array = []
var hangar = null
var npc: Node3D
var lamp_mat: StandardMaterial3D
var lamps_on := false
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var day_t := 0.32              # 0.25 sunrise, 0.5 noon, 0.75 sunset
var grass_mm: Array = []       # [MultiMesh, full count]
var grass_chunks: Array = []  # [MultiMeshInstance3D, centre]
var _dirt_n: FastNoiseLite
var _rock_n: FastNoiseLite
var _tone_n: FastNoiseLite

var player: CharacterBody3D
var hud: CanvasLayer
var storm: Node3D
var director: Node3D

var _holes: Array[MeshInstance3D] = []
var _hole_i := 0
var _hole_mesh: QuadMesh
var _fx_mat: StandardMaterial3D

const PIECES := [
	{"id": "wall", "name": "Wall", "glb": "res://assets/glb/build_wall.glb", "cost": 10},
	{"id": "window", "name": "Wall with window", "glb": "res://assets/glb/build_wallwindow.glb", "cost": 9},
	{"id": "door", "name": "Wall with doorway", "glb": "res://assets/glb/build_walldoor.glb", "cost": 8},
	{"id": "corner", "name": "L-shaped corner", "glb": "res://assets/glb/build_walll.glb", "cost": 18},
]

func _ready() -> void:
	Game.world = self
	seed_value = 4242 if Game.smoke else randi()
	_environment()
	_terrain()
	_water()
	_bounds()
	_scatter()
	_town()
	_lamps()
	_ramps()
	_grass()
	_map_image()
	_fx_setup()
	var spawn := find_spawn(Vector3.ZERO, 60.0)
	player = CharacterBody3D.new()
	player.set_script(load("res://game/player.gd"))
	add_child(player)
	player.global_position = spawn + Vector3(0, 0.2, 0)
	_vehicles(spawn)
	if Game.zombies_enabled:
		director = Node3D.new()
		director.set_script(load("res://game/zombies.gd"))
		add_child(director)
	if Game.storm_enabled:
		storm = Node3D.new()
		storm.set_script(load("res://game/storm.gd"))
		add_child(storm)
	var menu := CanvasLayer.new()
	menu.set_script(load("res://game/menu.gd"))
	add_child(menu)
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	_update_sky()
	hud = CanvasLayer.new()
	hud.set_script(load("res://game/hud.gd"))
	add_child(hud)
	Game.msg("Welcome to the island. Press H for controls.", Color(0.8, 0.95, 1))
	if Game.smoke:
		var sm := Node.new()
		sm.set_script(load("res://game/smoke.gd"))
		add_child(sm)

# ---------------------------------------------------------------- environment
func _environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky_mat = sm
	sm.sky_top_color = Color(0.32, 0.52, 0.82)
	sm.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sm.ground_horizon_color = Color(0.72, 0.80, 0.88)
	sm.ground_bottom_color = Color(0.25, 0.32, 0.38)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.66, 0.62)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.70, 0.78, 0.86)
	env.fog_density = 0.0028
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-60, 140, 0)
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	add_child(moon)

# ---------------------------------------------------------------- terrain
func _terrain() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.007
	noise.fractal_octaves = 4
	var detail := FastNoiseLite.new()
	detail.seed = seed_value + 7
	detail.frequency = 0.03
	heights.resize(N * N)
	for j in N:
		for i in N:
			var x := -SIZE / 2.0 + i * RES
			var z := -SIZE / 2.0 + j * RES
			var d := Vector2(x, z).length() / (SIZE * 0.46)
			d += noise.get_noise_2d(x * 0.7 + 900.0, z * 0.7) * 0.22
			var fall := clampf(1.0 - pow(maxf(d, 0.0), 2.6), 0.0, 1.0)
			var h := (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 20.0 + detail.get_noise_2d(x, z) * 1.5
			heights[j * N + i] = h * fall + 3.5 * fall - 7.0 * (1.0 - fall)
	_patch_noise()
	_plan_town()
	# mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := PackedColorArray()
	cols.resize(N * N)
	for j in N:
		for i in N:
			cols[j * N + i] = _ground_color(i, j)
	for j in N - 1:
		for i in N - 1:
			var a := j * N + i
			var quad := [a, a + 1, a + N, a + 1, a + N + 1, a + N]
			for k in quad:
				var ii: int = k % N
				var jj: int = k / N
				st.set_color(cols[k])
				st.add_vertex(Vector3(-SIZE / 2.0 + ii * RES, heights[k], -SIZE / 2.0 + jj * RES))
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	# collision: heightmap at 2 m spacing, uniform scale keeps it exact
	var shape := HeightMapShape3D.new()
	shape.map_width = N
	shape.map_depth = N
	var data := PackedFloat32Array()
	data.resize(N * N)
	for k in N * N:
		data[k] = heights[k] / RES
	shape.map_data = data
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(RES, RES, RES)
	body.add_child(cs)
	add_child(body)

func _patch_noise() -> void:
	_dirt_n = FastNoiseLite.new()
	_dirt_n.seed = seed_value + 21
	_dirt_n.frequency = 0.035
	_dirt_n.fractal_octaves = 3
	_rock_n = FastNoiseLite.new()
	_rock_n.seed = seed_value + 37
	_rock_n.frequency = 0.03
	_rock_n.fractal_octaves = 3
	_tone_n = FastNoiseLite.new()
	_tone_n.seed = seed_value + 53
	_tone_n.frequency = 0.05

## "water", "sand", "grass", "dirt" or "rock" at a world position.
func ground_type(x: float, z: float) -> String:
	var h := height_at(x, z)
	if h < 0.0:
		return "water"
	if h < 1.5:
		return "sand"
	if in_site(x, z, 2.5):
		return "dirt"
	if on_road(x, z, 0.5):
		return "road"
	var slope := Vector2(height_at(x + 1.0, z) - h, height_at(x, z + 1.0) - h).length()
	if slope > 0.75 or _rock_n.get_noise_2d(x, z) > 0.5 or h > 17.0:
		return "rock"
	if _dirt_n.get_noise_2d(x, z) > 0.38:
		return "dirt"
	return "grass"

func _type_color(t: String, x: float, z: float) -> Color:
	var v := _tone_n.get_noise_2d(x, z)
	match t:
		"water": return Color(0.50, 0.46, 0.33)
		"sand": return Color(0.80, 0.73, 0.50).darkened(v * 0.05)
		"rock": return Color(0.42, 0.41, 0.39).lerp(Color(0.33, 0.32, 0.31), v * 0.5 + 0.5)
		"dirt": return Color(0.40, 0.29, 0.18).lerp(Color(0.33, 0.24, 0.15), v * 0.5 + 0.5)
		"road": return Color(0.22, 0.21, 0.20)
	return Color(0.24, 0.50, 0.15).lerp(Color(0.33, 0.58, 0.18), v * 0.5 + 0.5)

func _ground_color(i: int, j: int) -> Color:
	var x := -SIZE / 2.0 + i * RES
	var z := -SIZE / 2.0 + j * RES
	var h := heights[j * N + i]
	var c := _type_color(ground_type(x, z), x, z)
	if h < 0.0:
		c = c.darkened(clampf(-h / 8.0, 0.0, 0.6))
	return c

func height_at(x: float, z: float) -> float:
	var fx := (x + SIZE / 2.0) / RES
	var fz := (z + SIZE / 2.0) / RES
	if fx < 0.0 or fz < 0.0 or fx >= N - 1 or fz >= N - 1:
		return -7.0
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := heights[j * N + i]
	var b := heights[j * N + i + 1]
	var c := heights[(j + 1) * N + i]
	var d := heights[(j + 1) * N + i + 1]
	# matches the triangle split used by the mesh and collision
	if tx + tz <= 1.0:
		return a + (b - a) * tx + (c - a) * tz
	return d + (c - d) * (1.0 - tx) + (b - d) * (1.0 - tz)

func is_land(x: float, z: float, min_h := 1.0, max_h := 30.0) -> bool:
	var h := height_at(x, z)
	return h >= min_h and h <= max_h

func find_spawn(near: Vector3, radius: float) -> Vector3:
	for i in 400:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius
		var x := near.x + cos(a) * r
		var z := near.z + sin(a) * r
		if is_land(x, z, 2.0, 14.0):
			return Vector3(x, height_at(x, z), z)
	for i in 4000:
		var x := randf_range(-SIZE * 0.4, SIZE * 0.4)
		var z := randf_range(-SIZE * 0.4, SIZE * 0.4)
		if is_land(x, z, 2.0, 18.0):
			return Vector3(x, height_at(x, z), z)
	return Vector3(0, height_at(0, 0) + 1.0, 0)

func _water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2400, 2400)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.38, 0.55, 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic_specular = 0.8
	mi.material_override = m
	mi.position.y = 0.0
	add_child(mi)

func _bounds() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	add_child(body)
	var half := SIZE / 2.0
	for k in 4:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(SIZE + 4, 80, 2) if k < 2 else Vector3(2, 80, SIZE + 4)
		cs.shape = bs
		cs.position = [Vector3(0, 20, -half), Vector3(0, 20, half), Vector3(-half, 20, 0), Vector3(half, 20, 0)][k]
		body.add_child(cs)

# ---------------------------------------------------------------- vegetation and rocks
func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	var forest := FastNoiseLite.new()
	forest.seed = seed_value + 3
	forest.frequency = 0.012
	var grid := {}
	var tree_d := Game.asset("res://assets/glb/tree.glb")
	var rock_d := Game.asset("res://assets/glb/rock.glb")
	var bush_d := Game.asset("res://assets/glb/bush.glb")
	var bush_shape := BoxShape3D.new()
	bush_shape.size = Vector3(1.4, 1.0, 1.2)
	var specs := [
		["tree", 140, 5.0, 2.2, 18.0, tree_d],
		["rock", 85, 6.0, 0.8, 26.0, rock_d],
		["bush", 230, 3.0, 1.6, 16.0, bush_d],
	]
	for spec in specs:
		var kind: String = spec[0]
		var placed := 0
		var tries := 0
		while placed < spec[1] and tries < 20000:
			tries += 1
			var x := rng.randf_range(-SIZE * 0.47, SIZE * 0.47)
			var z := rng.randf_range(-SIZE * 0.47, SIZE * 0.47)
			var h := height_at(x, z)
			if h < spec[3] or h > spec[4]:
				continue
			if kind != "rock" and forest.get_noise_2d(x, z) < -0.15 and rng.randf() < 0.8:
				continue
			if in_site(x, z, 3.0) or on_road(x, z, 2.5):
				continue
			if not _free(grid, x, z, spec[2]):
				continue
			grid[Vector2i(int(x / 6.0), int(z / 6.0))] = grid.get(Vector2i(int(x / 6.0), int(z / 6.0)), []) + [Vector2(x, z)]
			var s := rng.randf_range(0.8, 1.25)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, h - 0.05, z))
			var vis := 230.0 if kind == "tree" else (160.0 if kind == "rock" else 110.0)
			var root := Game.place_static(spec[5], xf, self, Game.L_WORLD, vis)
			var res: String = {"tree": "wood", "rock": "stone", "bush": "fibre"}[kind]
			root.set_meta("res", res)
			root.set_meta("hp", {"tree": 5, "rock": 8, "bush": 2}[kind])
			if kind == "bush":
				var sb := StaticBody3D.new()
				sb.collision_layer = Game.L_HARVEST
				sb.collision_mask = 0
				var cs := CollisionShape3D.new()
				cs.shape = bush_shape
				cs.position.y = 0.5
				sb.add_child(cs)
				root.add_child(sb)
			for c in root.get_children():
				if c is StaticBody3D:
					c.set_meta("owner_root", root)
			var entry := [root, Vector3(x, h, z)]
			if kind == "tree":
				trees.append(entry)
			elif kind == "rock":
				rocks.append(entry)
			else:
				bushes.append(entry)
			placed += 1
	_pines(grid, rng)

# ---------------------------------------------------------------- structure spawner
## Data-driven: every island rolls a count between min and max for each structure type.
## "central" structures cluster round the town centre; parking lots go in front of the entrance.
const STRUCTURES := [
	{"kind": "supermarket", "min": 1, "max": 1, "ring": Vector2(0, 0)},
	{"kind": "church", "min": 1, "max": 1, "ring": Vector2(28, 60)},
	{"kind": "dealership", "min": 1, "max": 1, "ring": Vector2(45, 110)},
	{"kind": "house", "min": 5, "max": 9, "ring": Vector2(25, 105)},
	{"kind": "hangar", "min": 1, "max": 1, "ring": Vector2(60, 130)},
]
const BUILDINGS := {
	"supermarket": {"glb": "res://assets/glb/bld_supermarket.glb", "half": Vector2(12.4, 8.8), "off": Vector2(0, 0.5), "front": 9.3, "park": Vector2(22, 12)},
	"church": {"glb": "res://assets/glb/bld_church.glb", "half": Vector2(5.8, 11.6), "off": Vector2(0, 1.2), "front": 12.8, "park": Vector2(14, 10)},
	"dealership": {"glb": "res://assets/glb/bld_dealership.glb", "half": Vector2(11.4, 7.4), "off": Vector2(0, 0), "front": 7.5, "park": Vector2(22, 12)},
	"hangar": {"glb": "", "half": Vector2(17.0, 12.5), "off": Vector2(0, 0), "front": 12.5, "park": Vector2.ZERO},
	"house": {"glb": "res://assets/glb/bld_house.glb", "half": Vector2(4.6, 4.5), "off": Vector2(0, 0.3), "front": 4.5, "park": Vector2.ZERO},
}
const HOUSE_COLOURS := [Color(0.85, 0.78, 0.62), Color(0.70, 0.22, 0.15), Color(0.95, 0.93, 0.88), Color(0.55, 0.65, 0.72),
	Color(0.80, 0.68, 0.35), Color(0.45, 0.55, 0.40), Color(0.35, 0.30, 0.28)]
const ROOF_COLOURS := [Color(0.35, 0.10, 0.07), Color(0.18, 0.18, 0.20), Color(0.30, 0.22, 0.15), Color(0.20, 0.28, 0.35)]
const ROAD_W := 6.0

var roads: Array = []          # {pts: PackedVector2Array, w: float}
var _road_grid := {}           # Vector2i(8 m cell) -> Array of [a, b, half width]

func _rot_rect(pos: Vector2, rot: int, off: Vector2, half: Vector2) -> Rect2:
	if rot % 2 == 1:
		half = Vector2(half.y, half.x)
	return Rect2(pos + off.rotated(-rot * PI / 2.0) - half, half * 2.0)

func _local_to_world(st: Dictionary, local: Vector2) -> Vector2:
	var l := local.rotated(-st.rot * PI / 2.0)
	return Vector2(st.pos.x, st.pos.z) + l

func in_site(x: float, z: float, margin := 0.0) -> bool:
	for st in sites:
		for r in st.rects:
			if (r as Rect2).grow(margin).has_point(Vector2(x, z)):
				return true
	return false

func on_road(x: float, z: float, margin := 0.0) -> bool:
	var p := Vector2(x, z)
	for seg in _road_grid.get(Vector2i(floori(x / 8.0), floori(z / 8.0)), []):
		if Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1]).distance_to(p) < seg[2] + margin:
			return true
	return false

func _raw_h(x: float, z: float) -> float:
	var i := clampi(roundi((x + SIZE / 2.0) / RES), 0, N - 1)
	var j := clampi(roundi((z + SIZE / 2.0) / RES), 0, N - 1)
	return heights[j * N + i]

func _flatten_rect(r: Rect2, target: float) -> void:
	for j in N:
		var zz := -SIZE / 2.0 + j * RES
		if zz < r.position.y - 8.0 or zz > r.end.y + 8.0:
			continue
		for i in N:
			var xx := -SIZE / 2.0 + i * RES
			var dx := maxf(maxf(r.position.x - 1.5 - xx, xx - r.end.x - 1.5), 0.0)
			var dz := maxf(maxf(r.position.y - 1.5 - zz, zz - r.end.y - 1.5), 0.0)
			var d := Vector2(dx, dz).length()
			if d < 6.0:
				var k := j * N + i
				heights[k] = lerpf(target, heights[k], smoothstep(0.0, 6.0, d))

func _try_site(kind: String, pos: Vector2, rot: int) -> bool:
	var b: Dictionary = BUILDINGS[kind]
	var rects: Array = [_rot_rect(pos, rot, b.off, b.half)]
	var park: Vector2 = b.park
	var reach: float = b.front
	if park != Vector2.ZERO:
		rects.append(_rot_rect(pos, rot, Vector2(0, b.front + 0.5 + park.y / 2.0), park / 2.0))
		reach += 0.5 + park.y
	var lo := 999.0
	var hi := -999.0
	for r in rects:
		var x: float = r.position.x
		while x <= r.end.x:
			var z: float = r.position.y
			while z <= r.end.y:
				var h := _raw_h(x, z)
				lo = minf(lo, h)
				hi = maxf(hi, h)
				z += 2.0
			x += 2.0
	if lo < 2.2 or hi > 18.0 or hi - lo > 4.5:
		return false
	for st in sites:
		for r1 in st.rects:
			for r2 in rects:
				if (r1 as Rect2).grow(5.0).intersects(r2):
					return false
	var target := (lo + hi) / 2.0
	var st := {"kind": kind, "pos": Vector3(pos.x, target, pos.y), "rot": rot, "rects": rects,
		"rect": rects[0], "park": rects[1] if rects.size() > 1 else null}
	st["door"] = _local_to_world(st, Vector2(0, b.front + 0.3))
	st["connect"] = _local_to_world(st, Vector2(0, reach + 4.0))
	sites.append(st)
	for r in rects:
		_flatten_rect(r, target)
	return true

func _plan_town() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 501
	var plan: Array = []
	for e in STRUCTURES:
		for i in rng.randi_range(e.min, e.max):
			plan.append(e)
	var centre := Vector2.INF
	for e in plan:
		for t in 900:
			var p: Vector2
			if centre == Vector2.INF:
				p = Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70))
			else:
				var ring: Vector2 = e.ring
				var a := rng.randf() * TAU
				p = centre + Vector2(cos(a), sin(a)) * rng.randf_range(ring.x, ring.y + t * 0.05)
			# face the entrance towards the town centre
			var rot := rng.randi() % 4
			if centre != Vector2.INF:
				var to := centre - p
				var best := -2.0
				for r in 4:
					var f := Vector2(sin(r * PI / 2.0), cos(r * PI / 2.0))
					var dd := f.dot(to.normalized())
					if dd > best:
						best = dd
						rot = r
			if _try_site(e.kind, p, rot):
				if centre == Vector2.INF:
					centre = p
				break
	_plan_roads()
	_seat_sites()

## Roads: a minimum spanning tree between the entrances, each link routed round water, steep
## ground and other buildings, then the ground is smoothed under it.
## Final pass: the ground inside every footprint and lot is set just under the floor, so later
## flattening (neighbours, roads) can never push terrain up through a building.
func _seat_sites() -> void:
	for st in sites:
		var target: float = st.pos.y - 0.03
		for r in st.rects:
			var rr := (r as Rect2).grow(1.0)
			var i0 := clampi(floori((rr.position.x + SIZE / 2.0) / RES), 0, N - 1)
			var i1 := clampi(ceili((rr.end.x + SIZE / 2.0) / RES), 0, N - 1)
			var j0 := clampi(floori((rr.position.y + SIZE / 2.0) / RES), 0, N - 1)
			var j1 := clampi(ceili((rr.end.y + SIZE / 2.0) / RES), 0, N - 1)
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					heights[j * N + i] = minf(heights[j * N + i], target) if rr.has_point(Vector2(-SIZE / 2.0 + i * RES, -SIZE / 2.0 + j * RES)) else heights[j * N + i]

func _plan_roads() -> void:
	var n := sites.size()
	if n < 2:
		return
	var pts: Array = []
	for st in sites:
		pts.append(st.connect)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 611
	var linked := [0]
	var bad := {}
	var links := {}
	while linked.size() < n:
		var best := INF
		var bi := -1
		var bj := -1
		for i in linked:
			for j in n:
				if j in linked or bad.has(Vector2i(i, j)):
					continue
				var d: float = pts[i].distance_to(pts[j])
				if d < best:
					best = d
					bi = i
					bj = j
		if bj < 0:
			break
		var path := _route(pts[bi], pts[bj], rng)
		if path.is_empty():
			bad[Vector2i(bi, bj)] = true
			continue
		roads.append({"pts": path, "w": ROAD_W, "kind": "link"})
		links[Vector2i(mini(bi, bj), maxi(bi, bj))] = true
		linked.append(bj)
	# a few extra links so the town has loops
	var extra := 0
	for i in n:
		for j in range(i + 1, n):
			if extra >= 3 or links.has(Vector2i(i, j)):
				continue
			if pts[i].distance_to(pts[j]) < 85.0 and rng.randf() < 0.45:
				var path := _route(pts[i], pts[j], rng)
				if not path.is_empty():
					roads.append({"pts": path, "w": ROAD_W, "kind": "link"})
					links[Vector2i(i, j)] = true
					extra += 1
	# roads out of town to the coast (dead ends)
	var centre: Vector2 = pts[0]
	var outs := 0
	for t in 60:
		if outs >= 3:
			break
		var a := rng.randf() * TAU
		var far := centre + Vector2(cos(a), sin(a)) * rng.randf_range(110.0, 165.0)
		if _raw_h(far.x, far.y) < 2.5 or _raw_h(far.x, far.y) > 12.0:
			continue
		var from_i := 0
		var best := INF
		for i in n:
			var dd: float = pts[i].distance_to(far)
			if dd < best:
				best = dd
				from_i = i
		var path := _route(pts[from_i], far, rng)
		if not path.is_empty():
			roads.append({"pts": path, "w": ROAD_W, "kind": "out"})
			outs += 1
	# driveways from each link point to the entrance
	for st in sites:
		var w := 4.0 if st.kind == "house" else ROAD_W
		roads.append({"pts": PackedVector2Array([st.connect, st.door]), "w": w, "kind": "drive", "site": st.kind})
	for rd in roads:
		_index_road(rd)
		_flatten_road(rd)

func _route(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	for attempt in 12:
		var side := (b - a).orthogonal().normalized()
		var j1 := 0.0 if attempt == 0 else rng.randf_range(-1.0, 1.0) * a.distance_to(b) * 0.35
		var j2 := 0.0 if attempt == 0 else rng.randf_range(-1.0, 1.0) * a.distance_to(b) * 0.35
		var ctrl := [a, a.lerp(b, 0.33) + side * j1, a.lerp(b, 0.66) + side * j2, b]
		var path := PackedVector2Array()
		var steps := maxi(4, int(a.distance_to(b) / 2.0))
		for k in steps + 1:
			path.append(_bezier(ctrl, float(k) / steps))
		var ok := true
		var prev_h := _raw_h(a.x, a.y)
		for k in path.size():
			var p := path[k]
			var h := _raw_h(p.x, p.y)
			if h < 1.4 or absf(h - prev_h) > 0.7:
				ok = false
				break
			prev_h = h
			if k > 2 and k < path.size() - 3 and in_site(p.x, p.y, 2.0):
				ok = false
				break
		if ok:
			return path
	return PackedVector2Array()

func _bezier(c: Array, t: float) -> Vector2:
	var u := 1.0 - t
	return c[0] * u * u * u + c[1] * 3.0 * u * u * t + c[2] * 3.0 * u * t * t + c[3] * t * t * t

func _index_road(rd: Dictionary) -> void:
	var p: PackedVector2Array = rd.pts
	for k in p.size() - 1:
		var a := p[k]
		var b := p[k + 1]
		var hw: float = rd.w / 2.0
		for cx in range(floori((minf(a.x, b.x) - hw - 3) / 8.0), floori((maxf(a.x, b.x) + hw + 3) / 8.0) + 1):
			for cz in range(floori((minf(a.y, b.y) - hw - 3) / 8.0), floori((maxf(a.y, b.y) + hw + 3) / 8.0) + 1):
				var key := Vector2i(cx, cz)
				if not _road_grid.has(key):
					_road_grid[key] = []
				_road_grid[key].append([a, b, hw])

func _flatten_road(rd: Dictionary) -> void:
	var p: PackedVector2Array = rd.pts
	var hs := PackedFloat32Array()
	for q in p:
		hs.append(_raw_h(q.x, q.y))
	var smooth := PackedFloat32Array()
	for k in p.size():
		var sum := 0.0
		var cnt := 0
		for o in range(-3, 4):
			var kk := clampi(k + o, 0, p.size() - 1)
			sum += hs[kk]
			cnt += 1
		smooth.append(sum / cnt)
	var hw: float = rd.w / 2.0
	for k in p.size() - 1:
		var a := p[k]
		var b := p[k + 1]
		var i0 := clampi(floori((minf(a.x, b.x) - hw - 3 + SIZE / 2.0) / RES), 0, N - 1)
		var i1 := clampi(ceili((maxf(a.x, b.x) + hw + 3 + SIZE / 2.0) / RES), 0, N - 1)
		var j0 := clampi(floori((minf(a.y, b.y) - hw - 3 + SIZE / 2.0) / RES), 0, N - 1)
		var j1 := clampi(ceili((maxf(a.y, b.y) + hw + 3 + SIZE / 2.0) / RES), 0, N - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var q := Vector2(-SIZE / 2.0 + i * RES, -SIZE / 2.0 + j * RES)
				if in_site(q.x, q.y):
					continue
				var c := Geometry2D.get_closest_point_to_segment(q, a, b)
				var d := c.distance_to(q)
				if d > hw + 3.0:
					continue
				var t := clampf(a.distance_to(c) / maxf(a.distance_to(b), 0.01), 0.0, 1.0)
				var target := lerpf(smooth[k], smooth[k + 1], t)
				var kk := j * N + i
				heights[kk] = lerpf(target, heights[kk], smoothstep(hw + 0.6, hw + 3.5, d))

func _town() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 777
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.16, 0.16, 0.17)
	asphalt.roughness = 0.95
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.85, 0.80)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for st in sites:
		var b: Dictionary = BUILDINGS[st.kind]
		var xf := Transform3D(Basis(Vector3.UP, st.rot * PI / 2.0), st.pos)
		if st.kind == "hangar":
			hangar = Node3D.new()
			hangar.set_script(load("res://game/hangar.gd"))
			add_child(hangar)
			hangar.global_transform = xf
			hangar.build()
			st["node"] = hangar
			doors.append(hangar)
			continue
		var d := Game.asset(b.glb)
		var root := Game.place_static(d, xf, self, Game.L_WORLD, 280.0)
		st["node"] = root
		_doors_for(st)
		if st.kind == "dealership":
			npc = StaticBody3D.new()
			npc.set_script(load("res://game/npc.gd"))
			add_child(npc)
			npc.setup()
			npc.global_transform = Transform3D(Basis(Vector3.UP, st.rot * PI / 2.0), st.pos + Basis(Vector3.UP, st.rot * PI / 2.0) * Vector3(-6.5, 0, -0.5))
		if st.kind == "house":
			var wall: Color = HOUSE_COLOURS[rng.randi() % HOUSE_COLOURS.size()]
			var roof: Color = ROOF_COLOURS[rng.randi() % ROOF_COLOURS.size()]
			for mi in root.get_children():
				if mi is MeshInstance3D:
					for si in mi.mesh.get_surface_count():
						var m = mi.mesh.surface_get_material(si)
						if m == null:
							continue
						var nm: String = m.resource_name
						if nm == "Wall" or nm == "Roof":
							var c := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
							c.albedo_color = wall if nm == "Wall" else roof
							mi.set_surface_override_material(si, c)
		if st.park != null:
			_parking(st, b, asphalt, paint, rng)
	_road_meshes(asphalt, paint)
	_road_signs()

## Hinged doors: double doors in the church tower, a front door on every house.
func _doors_for(st: Dictionary) -> void:
	var specs: Array = []   # [hinge position (local), leaf width, height, swing side, wood colour]
	match st.kind:
		"church": specs = [[Vector3(-0.8, 0, 12.2), 0.8, 3.0, 1.0, Color(0.36, 0.20, 0.10)],
						   [Vector3(0.8, 0, 12.2), 0.8, 3.0, -1.0, Color(0.36, 0.20, 0.10)]]
		"house": specs = [[Vector3(-0.5, 0, 3.375), 1.0, 2.1, 1.0, Color(0.45, 0.30, 0.18)]]
	var b := Basis(Vector3.UP, st.rot * PI / 2.0)
	for sp in specs:
		var frame := Node3D.new()
		add_child(frame)
		frame.global_transform = Transform3D(b, st.pos + b * (sp[0] as Vector3))
		var d := StaticBody3D.new()
		d.set_script(load("res://game/door.gd"))
		frame.add_child(d)
		d.setup(sp[1], sp[2], sp[3], sp[4])
		doors.append(d)

const VEHICLE_GLB := {"tike": "res://assets/glb/vehicle_tike.glb", "bike": "res://assets/glb/vehicle_bike.glb",
	"atv": "res://assets/glb/vehicle_atv.glb", "sedan": "res://assets/glb/vehicle_sedan.glb"}

## Bjørn hands out vehicles. The chosen one rolls out in the middle of the showroom, facing the big door;
## any other unused vehicle standing in the showroom goes back to stock. One of each kind in the world.
func give_vehicle(kind: String) -> Node3D:
	var dealer = site_of("dealership")
	var p := Vector3.ZERO
	var yaw := 0.0
	if dealer:
		var b := Basis(Vector3.UP, dealer.rot * PI / 2.0)
		p = dealer.pos + b * Vector3(0.0, 0.2, 1.5)
		yaw = dealer.rot * PI / 2.0
		for v in vehicles.duplicate():
			if v.driver == null and v.kind != kind and (dealer.rect as Rect2).has_point(Vector2(v.global_position.x, v.global_position.z)):
				vehicles.erase(v)
				v.queue_free()
	else:
		p = player.global_position + Vector3(4, 0.5, 0)
		p.y = height_at(p.x, p.z) + 0.3
	for v in vehicles:
		if v.kind == kind and v.driver == null:
			v.global_position = p
			v.rotation = Vector3(0, yaw, 0)
			v.speed = 0.0
			v.velocity = Vector3.ZERO
			return v
	var v := CharacterBody3D.new()
	v.set_script(load("res://game/vehicle.gd"))
	add_child(v)
	v.setup(VEHICLE_GLB[kind], kind)
	v.global_position = p
	v.rotation.y = yaw
	vehicles.append(v)
	return v

## Developer mode: the helicopter is parked on the pad in the hangar (or 14 m in front of the
## player if this island has no hangar). Only one helicopter exists; asking again brings it back.
func spawn_heli() -> Node3D:
	var p: Vector3
	var yaw: float
	var st = site_of("hangar")
	if st:
		yaw = st.rot * PI / 2.0
		p = st.pos + Basis(Vector3.UP, yaw) * Vector3(0, 0.15, 2.5)
	else:
		var fwd: Vector3 = -player.global_transform.basis.z
		p = player.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 14.0
		p.y = height_at(p.x, p.z) + 0.5
		yaw = player.rotation.y + PI
	var h = null
	for v in vehicles:
		if v.kind == "heli":
			h = v
	if h != null and h.driver != null:
		return h
	if h == null:
		h = CharacterBody3D.new()
		h.set_script(load("res://game/heli.gd"))
		add_child(h)
		h.setup("res://assets/glb/vehicle_heli.glb")
		vehicles.append(h)
	h.global_position = p
	h.rotation = Vector3(0, yaw, 0)
	h.velocity = Vector3.ZERO
	h.speed = 0.0
	if st:
		Game.msg("Helicopter is in the hangar at %s. Press the red button by the door to open the roof" % Game.sector(st.pos), Color(0.8, 0.95, 1.0))
	else:
		Game.msg("Helicopter ready. E to get in: Space climb, Shift/C descend, W/S fly, A/D turn", Color(0.8, 0.95, 1.0))
	return h

func _parking(st: Dictionary, b: Dictionary, asphalt: Material, paint: Material, rng: RandomNumberGenerator) -> void:
	var r: Rect2 = st.park
	var y: float = st.pos.y
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(r.size.x, 0.04, r.size.y)
	bm.material = asphalt
	mi.mesh = bm
	add_child(mi)
	mi.global_position = Vector3(r.get_center().x, y + 0.02, r.get_center().y)
	# bays along the far edge, leaving a lane in front of the entrance
	var park: Vector2 = b.park
	var basis := Basis(Vector3.UP, st.rot * PI / 2.0)
	var far: float = b.front + 0.5 + park.y
	var bays := int(park.x / 2.6)
	for i in bays + 1:
		var lx := -park.x / 2.0 + 0.4 + i * (park.x - 0.8) / bays
		var line := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.12, 0.01, 4.8)
		lm.material = paint
		line.mesh = lm
		add_child(line)
		line.global_transform = Transform3D(basis, st.pos + basis * Vector3(lx, 0.05, far - 2.6))
	# a few abandoned cars
	var rust := StandardMaterial3D.new()
	rust.albedo_color = [Color(0.40, 0.18, 0.08), Color(0.25, 0.30, 0.35), Color(0.45, 0.42, 0.30)][rng.randi() % 3]
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.1, 0.12)
	for k in rng.randi_range(0, 3):
		var lx := -park.x / 2.0 + 0.4 + (rng.randi() % bays + 0.5) * (park.x - 0.8) / bays
		var car := StaticBody3D.new()
		car.collision_layer = Game.L_WORLD
		add_child(car)
		car.global_transform = Transform3D(basis.rotated(Vector3.UP, rng.randf_range(-0.15, 0.15)), st.pos + basis * Vector3(lx, 0.0, far - 2.5))
		for prt in [[Vector3(1.8, 0.8, 4.2), Vector3(0, 0.55, 0), rust], [Vector3(1.6, 0.6, 2.0), Vector3(0, 1.25, -0.2), glass]]:
			var m2 := MeshInstance3D.new()
			var bm2 := BoxMesh.new()
			bm2.size = prt[0]
			bm2.material = prt[2]
			m2.mesh = bm2
			m2.position = prt[1]
			car.add_child(m2)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.8, 1.5, 4.2)
		cs.shape = bs
		cs.position.y = 0.75
		car.add_child(cs)

func _road_meshes(asphalt: Material, paint: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := SurfaceTool.new()
	white.begin(Mesh.PRIMITIVE_TRIANGLES)
	var yellow := SurfaceTool.new()
	yellow.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rd in roads:
		var pts := _resample(rd.pts, 1.5)
		var hw: float = rd.w / 2.0
		var main_road := hw >= 2.5
		var along := 0.0
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var sa := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized().orthogonal()
			var sb := (pts[mini(k + 2, pts.size() - 1)] - pts[k]).normalized().orthogonal()
			for lane in 4:
				_strip(st, a, b, sa, sb, -hw + lane * hw / 2.0, -hw + (lane + 1) * hw / 2.0, 0.07)
			if main_road:
				# white edge lines (solid) on both sides
				_strip(white, a, b, sa, sb, -hw + 0.2, -hw + 0.35, 0.085)
				_strip(white, a, b, sa, sb, hw - 0.35, hw - 0.2, 0.085)
				# yellow centre line: 3 m dash, 6 m gap
				if fmod(along, 9.0) < 3.0:
					_strip(yellow, a, b, sa, sb, -0.07, 0.07, 0.085)
			along += a.distance_to(b)
	# zebra crossings on the road leaving the supermarket, church and dealership
	for site in sites:
		if site.kind in ["supermarket", "church", "dealership"]:
			for rd in roads:
				var p: PackedVector2Array = rd.pts
				if rd.w < 5.0 or p.size() < 4:
					continue
				var at := -1
				if p[0].distance_to(site.connect) < 0.5:
					at = 0
				elif p[p.size() - 1].distance_to(site.connect) < 0.5:
					at = p.size() - 1
				if at >= 0:
					_crossing(white, p, at, rd.w / 2.0)
					break
	for pair in [[st, asphalt], [white, paint], [yellow, _yellow_mat()]]:
		var m: ArrayMesh = pair[0].commit()
		if m.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

## Norwegian signs: 50 km/h at the ends of town roads, forkjørsvei, vikeplikt and blindvei on the roads out
## of town, parking signs at the lots, 30 km/h by the church.
func _road_signs() -> void:
	var flip := false
	for rd in roads:
		var p: PackedVector2Array = rd.pts
		if p.size() < 6:
			continue
		var hw: float = rd.w / 2.0
		var kind: String = rd.get("kind", "")
		for end in [0, 1]:
			var a: Vector2 = p[0] if end == 0 else p[p.size() - 1]
			var nxt: Vector2 = p[2] if end == 0 else p[p.size() - 3]
			var d := (nxt - a).normalized()           # direction of travel into the road
			var right := Vector2(-d.y, d.x)
			var at := a + d * 11.0 + right * (hw + 0.8)
			if kind == "link":
				_road_sign(at, -d, "priority" if flip and end == 0 else "speed50")
			elif kind == "out" and end == 0:
				_road_sign(at, -d, "deadend")
				_road_sign(a + d * 11.0 - right * (hw + 0.8), d, "yield")
			elif kind == "out" and end == 1:
				_road_sign(at, -d, "speed50")
		flip = not flip
	for st in sites:
		if st.park != null:
			var d: Vector2 = (st.door - st.connect).normalized()
			_road_sign(st.connect + Vector2(-d.y, d.x) * 3.8, -d, "parking")
		if st.kind == "church":
			var d2: Vector2 = (st.connect - st.door).normalized()
			_road_sign(st.connect + d2 * 4.0 + Vector2(-d2.y, d2.x) * 4.0, -d2, "speed30")

func _road_sign(pos: Vector2, facing: Vector2, kind: String) -> void:
	if height_at(pos.x, pos.y) < 0.5 or in_site(pos.x, pos.y, -0.3):
		return
	var root := StaticBody3D.new()
	root.collision_layer = Game.L_WORLD
	add_child(root)
	root.global_position = Vector3(pos.x, height_at(pos.x, pos.y), pos.y)
	root.rotation.y = atan2(facing.x, facing.y)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.6, 0.6, 0.62)
	grey.metallic = 0.6
	_part(root, CylinderMesh.new(), Vector3(0.05, 2.3, 0.05), Vector3(0, 1.15, 0), grey)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.08
	cyl.height = 2.3
	cs.shape = cyl
	cs.position.y = 1.15
	root.add_child(cs)
	var y := 2.35
	match kind:
		"speed50", "speed30":
			_disc(root, 0.34, Vector3(0, y, 0.0), Color(0.80, 0.08, 0.06))
			_disc(root, 0.27, Vector3(0, y, 0.012), Color(0.95, 0.95, 0.95))
			_label(root, "50" if kind == "speed50" else "30", Vector3(0, y, 0.03), 46, Color(0.05, 0.05, 0.05))
		"priority":
			var w := _part(root, BoxMesh.new(), Vector3(0.5, 0.5, 0.03), Vector3(0, y, 0), _flat(Color(0.95, 0.95, 0.95)))
			w.rotation.z = PI / 4.0
			var yl := _part(root, BoxMesh.new(), Vector3(0.36, 0.36, 0.03), Vector3(0, y, 0.01), _flat(Color(0.98, 0.78, 0.05)))
			yl.rotation.z = PI / 4.0
		"yield":
			_tri(root, 0.42, Vector3(0, y, 0.0), Color(0.80, 0.08, 0.06), true)
			_tri(root, 0.31, Vector3(0, y + 0.03, 0.012), Color(0.95, 0.95, 0.95), true)
		"deadend":
			_part(root, BoxMesh.new(), Vector3(0.6, 0.6, 0.03), Vector3(0, y, 0), _flat(Color(0.05, 0.25, 0.65)))
			_part(root, BoxMesh.new(), Vector3(0.1, 0.38, 0.01), Vector3(0, y - 0.07, 0.02), _flat(Color(0.95, 0.95, 0.95)))
			_part(root, BoxMesh.new(), Vector3(0.3, 0.1, 0.01), Vector3(0, y + 0.15, 0.02), _flat(Color(0.80, 0.08, 0.06)))
		"parking":
			_part(root, BoxMesh.new(), Vector3(0.6, 0.6, 0.03), Vector3(0, y, 0), _flat(Color(0.05, 0.25, 0.65)))
			_label(root, "P", Vector3(0, y, 0.02), 56, Color(0.97, 0.97, 0.97))

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _disc(root: Node3D, r: float, pos: Vector3, c: Color) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 24
	cm.material = _flat(c)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = pos
	mi.rotation.x = PI / 2.0
	root.add_child(mi)

func _tri(root: Node3D, r: float, pos: Vector3, c: Color, down: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k := -1.0 if down else 1.0
	for v in [Vector3(-r, 0.3 * r * k, 0), Vector3(r, 0.3 * r * k, 0), Vector3(0, -0.9 * r * k, 0)]:
		st.set_normal(Vector3.BACK)
		st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _flat(c)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	root.add_child(mi)

func _label(root: Node3D, text: String, pos: Vector3, size: int, c: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = c
	l.outline_size = 0
	l.double_sided = false
	l.position = pos
	root.add_child(l)

func _yellow_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.72, 0.10)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _resample(p: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in p.size() - 1:
		var n := maxi(1, int(p[k].distance_to(p[k + 1]) / step))
		for i in n:
			out.append(p[k].lerp(p[k + 1], float(i) / n))
	out.append(p[p.size() - 1])
	return out

## Quad between offsets o0..o1 across the road, draped on the terrain.
func _strip(st: SurfaceTool, a: Vector2, b: Vector2, sa: Vector2, sb: Vector2, o0: float, o1: float, lift: float) -> void:
	var q := [a + sa * o0, a + sa * o1, b + sb * o0, b + sb * o1]
	var v: Array = []
	for c in q:
		v.append(Vector3(c.x, height_at(c.x, c.y) + lift, c.y))
	for idx in [0, 1, 2, 1, 3, 2]:   # clockwise seen from above = front face in Godot
		st.set_normal(Vector3.UP)
		st.add_vertex(v[idx])

## Norwegian zebra crossing: white bars along the road, 0.5 m wide with 0.5 m gaps, 3 m long, plus signs.
func _crossing(white: SurfaceTool, p: PackedVector2Array, at: int, hw: float) -> void:
	var dir := (p[1] - p[0]).normalized() if at == 0 else (p[p.size() - 2] - p[p.size() - 1]).normalized()
	var c := p[at] + dir * 9.0
	var side := dir.orthogonal()
	var x := -hw + 0.5
	while x + 0.5 <= hw - 0.4:
		var a := c - dir * 1.5 + side * x
		var b := c + dir * 1.5 + side * x
		_strip(white, a, b, side, side, 0.0, 0.5, 0.09)
		x += 1.0
	for s2 in [-1, 1]:
		_sign(c + side * s2 * (hw + 0.8), dir)

func _sign(pos: Vector2, facing: Vector2) -> void:
	var y := height_at(pos.x, pos.y)
	var root := StaticBody3D.new()
	root.collision_layer = Game.L_WORLD
	add_child(root)
	root.global_position = Vector3(pos.x, y, pos.y)
	root.rotation.y = atan2(facing.x, facing.y)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.6, 0.6, 0.62)
	grey.metallic = 0.6
	_part(root, CylinderMesh.new(), Vector3(0.06, 2.6, 0.06), Vector3(0, 1.3, 0), grey)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.05, 0.25, 0.65)
	_part(root, BoxMesh.new(), Vector3(0.65, 0.65, 0.04), Vector3(0, 2.45, 0), blue)
	# white triangle with a dark walking figure (simplified), both faces
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [0.025, -0.025]:
		for v in [Vector3(-0.26, 2.2, z), Vector3(0.26, 2.2, z), Vector3(0, 2.68, z)]:
			st.set_normal(Vector3(0, 0, signf(z)))
			st.add_vertex(v)
	var tri := MeshInstance3D.new()
	tri.mesh = st.commit()
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.95, 0.95, 0.95)
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tri.material_override = wm
	root.add_child(tri)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.05)
	for z in [0.03, -0.03]:
		_part(root, BoxMesh.new(), Vector3(0.05, 0.18, 0.01), Vector3(0, 2.36, z), dark)
		_part(root, BoxMesh.new(), Vector3(0.06, 0.06, 0.01), Vector3(0, 2.49, z), dark)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.08
	cyl.height = 2.6
	cs.shape = cyl
	cs.position.y = 1.3
	root.add_child(cs)

func _part(parent: Node3D, mesh: PrimitiveMesh, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		mesh.size = size
	elif mesh is CylinderMesh:
		mesh.top_radius = size.x
		mesh.bottom_radius = size.x
		mesh.height = size.y
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi

# ---------------------------------------------------------------- street lamps and day/night
func _lamps() -> void:
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.9, 0.85, 0.7)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.85, 0.55)
	lamp_mat.emission_energy_multiplier = 0.0
	var spots: Array = []   # [position, facing towards the road]
	for rd in roads:
		if rd.w < 5.0:
			continue
		var pts := _resample(rd.pts, 2.0)
		var hw: float = rd.w / 2.0
		var k := 6
		var flip := 1.0
		while k < pts.size() - 6:
			var dir := (pts[k + 1] - pts[k - 1]).normalized()
			var p := pts[k] + dir.orthogonal() * flip * (hw + 0.9)
			spots.append([p, -dir.orthogonal() * flip])
			flip = -flip
			k += 14
	for site in sites:
		if site.park != null:
			var r: Rect2 = site.park
			for corner in [r.position + Vector2(0.6, 0.6), r.end - Vector2(0.6, 0.6)]:
				spots.append([corner, (r.get_center() - corner).normalized()])
	for sp in spots:
		var p: Vector2 = sp[0]
		if height_at(p.x, p.y) < 1.0 or in_site(p.x, p.y, -0.5) and not _in_lot(p):
			continue
		_lamp(p, sp[1])

func _in_lot(p: Vector2) -> bool:
	for site in sites:
		if site.park != null and (site.park as Rect2).has_point(p):
			return true
	return false

func _lamp(p: Vector2, toward: Vector2) -> void:
	var y := height_at(p.x, p.y)
	var root := StaticBody3D.new()
	root.collision_layer = Game.L_WORLD
	add_child(root)
	root.global_position = Vector3(p.x, y, p.y)
	root.rotation.y = atan2(toward.x, toward.y)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.32, 0.33, 0.35)
	grey.metallic = 0.5
	_part(root, CylinderMesh.new(), Vector3(0.09, 6.0, 0.09), Vector3(0, 3.0, 0), grey)
	_part(root, BoxMesh.new(), Vector3(0.08, 0.08, 1.4), Vector3(0, 5.95, 0.65), grey)
	_part(root, BoxMesh.new(), Vector3(0.35, 0.12, 0.6), Vector3(0, 5.88, 1.25), grey)
	_part(root, BoxMesh.new(), Vector3(0.3, 0.03, 0.5), Vector3(0, 5.81, 1.25), lamp_mat)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 5.6, 1.25)
	light.omni_range = 15.0
	light.omni_attenuation = 1.2
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 2.2
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 70.0
	light.distance_fade_length = 20.0
	light.visible = false
	root.add_child(light)
	lamps.append(light)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.12
	cyl.height = 6.0
	cs.shape = cyl
	cs.position.y = 3.0
	root.add_child(cs)

func clock() -> String:
	var h := fmod(day_t * 24.0, 24.0)
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]

func _process(dt: float) -> void:
	day_t = fmod(day_t + dt / maxf(Settings.get_v("day_length_min") * 60.0, 30.0), 1.0)
	_update_sky()

func _update_sky() -> void:
	var ang := (day_t - 0.25) * TAU                 # 0 sunrise, PI/2 noon, PI sunset
	var elev := sin(ang)
	sun.basis = Basis.from_euler(Vector3(-ang, deg_to_rad(-35), 0))
	var day := smoothstep(-0.08, 0.22, elev)
	var dusk := clampf(1.0 - absf(elev) / 0.25, 0.0, 1.0) * smoothstep(-0.25, 0.0, elev)
	sun.visible = elev > -0.02
	sun.light_energy = 1.05 * smoothstep(-0.02, 0.25, elev)
	sun.light_color = Color(1.0, 0.62, 0.38).lerp(Color(1, 1, 0.97), smoothstep(0.05, 0.4, elev))
	sun.shadow_enabled = Settings.get_v("shadows") and elev > 0.05
	moon.light_energy = 0.16 * (1.0 - day)
	var night_top := Color(0.02, 0.03, 0.07)
	var night_hor := Color(0.05, 0.07, 0.12)
	sky_mat.sky_top_color = night_top.lerp(Color(0.32, 0.52, 0.82), day)
	var hor := night_hor.lerp(Color(0.72, 0.80, 0.88), day).lerp(Color(0.95, 0.55, 0.30), dusk * 0.7)
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = Color(0.02, 0.03, 0.05).lerp(Color(0.25, 0.32, 0.38), day)
	env.ambient_light_color = Color(0.30, 0.36, 0.55).lerp(Color(0.66, 0.66, 0.62), day)
	env.ambient_light_energy = lerpf(0.22, 0.75, day)
	env.fog_light_color = Color(0.06, 0.08, 0.13).lerp(Color(0.70, 0.78, 0.86), day).lerp(Color(0.9, 0.6, 0.45), dusk * 0.5)
	var want_on := elev < 0.08
	if want_on != lamps_on:
		lamps_on = want_on
		for l in lamps:
			l.visible = want_on
		lamp_mat.emission_energy_multiplier = 3.0 if want_on else 0.0

func _apply_settings() -> void:
	var g: float = Settings.get_v("grass")
	for e in grass_mm:
		(e[0] as MultiMesh).visible_instance_count = int(e[1] * g)
	env.fog_density = 0.7 / maxf(Settings.get_v("view_distance"), 50.0)
	if sun:
		sun.shadow_enabled = Settings.get_v("shadows")

## Interior spawn points (DayZ: zombies lurk inside buildings).
func interior_points() -> Array:
	var out: Array = []
	for st in sites:
		var b := Basis(Vector3.UP, st.rot * PI / 2.0)
		var pts: Array = []
		match st.kind:
			"supermarket": pts = [Vector3(-5, 0, 2), Vector3(4, 0, -1), Vector3(9, 0, 3), Vector3(-1, 0, -5)]
			"church": pts = [Vector3(0, 0, -2), Vector3(1.5, 0, -6)]
			"dealership": pts = [Vector3(0, 0, -3), Vector3(-7, 0, -4)]
			"house": pts = [Vector3(-1.5, 0, 1.5)] if randf() < 0.6 else []
		for p in pts:
			out.append(st.pos + b * p + Vector3(0, 0.3, 0))
	return out

func site_of(kind: String):
	for st in sites:
		if st.kind == kind:
			return st
	return null

# ---------------------------------------------------------------- ramps
func _ramps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 909
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.33, 0.20)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var made := 0
	for t in 400:
		if made >= 8:
			break
		var x := rng.randf_range(-130, 130)
		var z := rng.randf_range(-130, 130)
		var h := height_at(x, z)
		if h < 2.0 or h > 14.0 or in_site(x, z, 8.0) or on_road(x, z, 6.0):
			continue
		var yaw := rng.randf() * TAU
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var h2 := height_at(x + dir.x * 7.0, z + dir.z * 7.0)
		if absf(h2 - h) > 1.2:
			continue
		var hgt := rng.randf_range(1.3, 2.2)
		var L := 7.0
		var W := 4.0
		var pts := PackedVector3Array([Vector3(-W / 2, -0.6, 0), Vector3(W / 2, -0.6, 0), Vector3(-W / 2, -0.6, L),
			Vector3(W / 2, -0.6, L), Vector3(-W / 2, hgt, L), Vector3(W / 2, hgt, L), Vector3(-W / 2, 0, 0), Vector3(W / 2, 0, 0)])
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tris := [[6, 4, 7], [7, 4, 5], [2, 4, 0], [0, 4, 6], [1, 5, 3], [1, 7, 5], [2, 3, 5], [2, 5, 4], [0, 1, 3], [0, 3, 2], [0, 6, 7], [0, 7, 1]]
		for tri in tris:
			for k in tri:
				st.add_vertex(pts[k])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		var body := StaticBody3D.new()
		body.collision_layer = Game.L_WORLD
		var cs := CollisionShape3D.new()
		var cps := ConvexPolygonShape3D.new()
		cps.points = pts
		cs.shape = cps
		body.add_child(cs)
		body.add_child(mi)
		add_child(body)
		body.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, minf(h, h2), z))
		ramps.append(body)
		made += 1

## Clusters of pines: a dozen small forests per island.
func _pines(grid: Dictionary, rng: RandomNumberGenerator) -> void:
	var pine_d := Game.asset("res://assets/glb/pine.glb")
	for c in rng.randi_range(10, 14):
		var centre := Vector2.INF
		for t in 200:
			var x := rng.randf_range(-SIZE * 0.42, SIZE * 0.42)
			var z := rng.randf_range(-SIZE * 0.42, SIZE * 0.42)
			var h := height_at(x, z)
			if h > 3.0 and h < 17.0 and not in_site(x, z, 10.0) and not on_road(x, z, 6.0):
				centre = Vector2(x, z)
				break
		if centre == Vector2.INF:
			continue
		var want := rng.randi_range(10, 22)
		var placed := 0
		for t in want * 4:
			if placed >= want:
				break
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 17.0
			var x := centre.x + cos(a) * r
			var z := centre.y + sin(a) * r
			var h := height_at(x, z)
			if h < 2.0 or h > 19.0 or in_site(x, z, 3.0) or on_road(x, z, 2.5) or not _free(grid, x, z, 3.2):
				continue
			var key := Vector2i(int(x / 6.0), int(z / 6.0))
			grid[key] = grid.get(key, []) + [Vector2(x, z)]
			var s2 := rng.randf_range(0.8, 1.35)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2, s2, s2)), Vector3(x, h - 0.05, z))
			var root := Game.place_static(pine_d, xf, self, Game.L_WORLD, 240.0)
			root.set_meta("res", "wood")
			root.set_meta("hp", 5)
			for ch in root.get_children():
				if ch is StaticBody3D:
					ch.set_meta("owner_root", root)
			trees.append([root, Vector3(x, h, z)])
			placed += 1

func _free(grid: Dictionary, x: float, z: float, r: float) -> bool:
	var cx := int(x / 6.0)
	var cz := int(z / 6.0)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for p in grid.get(Vector2i(cx + dx, cz + dz), []):
				if p.distance_to(Vector2(x, z)) < r:
					return false
	return true

## Melee hit on a resource. Returns {res: amount} gathered (empty if not a resource).
## Melee hit on a resource. power = hit points removed (the bat hits trees for 2).
## Returns {res: amount} gathered (empty if not a resource).
func server_harvest(body: Object, power := 1) -> Dictionary:
	if not (body is Node) or not body.has_meta("owner_root"):
		return {}
	var root: Node3D = body.get_meta("owner_root")
	if not is_instance_valid(root) or root.get_meta("hp", 0) <= 0:
		return {}
	var res: String = root.get_meta("res")
	var hp: int = root.get_meta("hp") - power
	root.set_meta("hp", hp)
	var out := {}
	match res:
		"wood": out = {"wood": 6 * power}
		"stone":
			out = {"stone": 6}
			if randf() < 0.4:
				out["metal"] = 1
		"fibre": out = {"fibre": 4}
	if hp <= 0:
		_remove_resource(root, res == "wood")
	else:
		var rest := root.basis
		var axis := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		var tw := create_tween()
		tw.tween_property(root, "basis", rest.rotated(axis, 0.06), 0.05)
		tw.tween_property(root, "basis", rest.rotated(axis, -0.03), 0.07)
		tw.tween_property(root, "basis", rest, 0.08)
	Game.make_noise(root.global_position, 18.0)
	return out

func _remove_resource(root: Node3D, fall: bool) -> void:
	for c in root.get_children():
		if c is StaticBody3D:
			c.queue_free()
	var tw := create_tween()
	if fall:
		var stump := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.26
		cm.height = 0.4
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.30, 0.20, 0.12)
		cm.material = sm
		stump.mesh = cm
		add_child(stump)
		stump.global_position = root.global_position + Vector3(0, 0.2, 0)
		var top := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.19
		tm.bottom_radius = 0.19
		tm.height = 0.02
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.78, 0.62, 0.40)
		tm.material = tmat
		top.mesh = tm
		top.position.y = 0.205
		stump.add_child(top)
		puff(root.global_position + Vector3(0, 1.0, 0), Color(0.62, 0.46, 0.26), 14)
		Sfx.play3d("chop", root.global_position + Vector3(0, 1, 0), 6.0, 0.55)
		var axis := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		tw.tween_property(root, "basis", root.basis.rotated(axis, PI / 2.1), 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Sfx.play3d("hit", root.global_position + Vector3(0, 0.5, 0), 6.0, 0.5))
		tw.tween_interval(2.0)
	tw.tween_property(root, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
	tw.tween_callback(root.queue_free)

## Storm: vegetation outside the zone dies.
func kill_vegetation(inside: Callable, budget: int) -> void:
	for g in grass_chunks:
		if g[0].visible:
			var c: Vector3 = g[1]
			var all_out := true
			for o in [Vector2(-12, -12), Vector2(12, -12), Vector2(-12, 12), Vector2(12, 12)]:
				if inside.call(Vector2(c.x, c.z) + o):
					all_out = false
			if all_out:
				g[0].visible = false
	for list in [trees, bushes]:
		var i: int = list.size() - 1
		while i >= 0 and budget > 0:
			var e = list[i]
			if not is_instance_valid(e[0]) or e[0].get_meta("hp", 0) <= 0:
				list.remove_at(i)
			elif not inside.call(Vector2(e[1].x, e[1].z)):
				budget -= 1
				e[0].set_meta("hp", 0)
				_wither(e[0])
				list.remove_at(i)
			i -= 1

func _wither(root: Node3D) -> void:
	for c in root.get_children():
		if c is StaticBody3D:
			c.queue_free()
		elif c is MeshInstance3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.25, 0.2, 0.18)
			c.material_override = m
	var tw := create_tween()
	tw.tween_interval(randf_range(0.2, 1.5))
	tw.tween_property(root, "scale", Vector3(root.scale.x * 1.2, 0.02, root.scale.z * 1.2), 1.2)
	tw.tween_callback(root.queue_free)

# ---------------------------------------------------------------- building
## Rust-style snapping on a 3 m grid. Walls sit on cell edges; the L corner sits on a cell corner.
func piece_slot(kind: int, aim: Vector3, rot: int) -> Dictionary:
	var g := 3.0
	var edges: Array = []
	var pos := Vector3.ZERO
	var basis := Basis(Vector3.UP, rot * PI / 2.0)
	if PIECES[kind].id == "corner":
		var cx := roundi(aim.x / g)
		var cz := roundi(aim.z / g)
		pos = Vector3(cx * g, 0, cz * g)
		for leg in [Vector3(1, 0, 0), Vector3(0, 0, -1)]:
			var d: Vector3 = (basis * leg).round()
			if d.x > 0.5: edges.append("X:%d:%d" % [cx, cz])
			elif d.x < -0.5: edges.append("X:%d:%d" % [cx - 1, cz])
			elif d.z > 0.5: edges.append("Z:%d:%d" % [cx, cz])
			else: edges.append("Z:%d:%d" % [cx, cz - 1])
	else:
		rot = rot % 2
		basis = Basis(Vector3.UP, rot * PI / 2.0)
		if rot == 0:
			var ex := int(floor(aim.x / g))
			var ez := roundi(aim.z / g)
			pos = Vector3(ex * g + 1.5, 0, ez * g)
			edges.append("X:%d:%d" % [ex, ez])
		else:
			var ex := roundi(aim.x / g)
			var ez := int(floor(aim.z / g))
			pos = Vector3(ex * g, 0, ez * g + 1.5)
			edges.append("Z:%d:%d" % [ex, ez])
	# sit on the lowest ground under the piece; the foundation fills the gap
	var samples: Array = [pos]
	if PIECES[kind].id == "corner":
		samples += [pos + basis * Vector3(2.8, 0, 0), pos + basis * Vector3(0, 0, -2.8)]
	else:
		samples += [pos + basis * Vector3(-1.4, 0, 0), pos + basis * Vector3(1.4, 0, 0)]
	var y := 999.0
	for s in samples:
		y = minf(y, height_at(s.x, s.z))
	pos.y = y
	var free := true
	for e in edges:
		if pieces.has(e):
			free = false
	return {"xform": Transform3D(basis, pos), "edges": edges, "free": free, "dry": y > 0.15}

func server_build(kind: int, slot: Dictionary) -> Node3D:
	var d := Game.asset(PIECES[kind].glb)
	var root := Game.place_static(d, slot.xform, self, Game.L_STRUCT)
	# foundation under the piece for sloped ground
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.50, 0.44, 0.31)
	var legs: Array = [[Vector3(0, -1.0, 0), Vector3(3.0, 2.0, 0.44)]]
	if PIECES[kind].id == "corner":
		legs = [[Vector3(1.4, -1.0, 0), Vector3(3.2, 2.0, 0.44)], [Vector3(0, -1.0, -1.4), Vector3(0.44, 2.0, 3.2)]]
	for l in legs:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = l[1]
		mi.mesh = bm
		mi.position = l[0]
		mi.material_override = fm
		root.add_child(mi)
	for e in slot.edges:
		pieces[e] = root
	root.scale = Vector3(1, 0.05, 1)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 2.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play3d("build", slot.xform.origin + Vector3(0, 1, 0))
	return root

# ---------------------------------------------------------------- combat
## Resolves a hit from a shot or melee swing. Returns 0 = scenery, 1 = body hit, 2 = headshot.
func server_shot_hit(hit: Dictionary, dmg: float, dir: Vector3, _spare := 0.0, knock := Vector3.ZERO) -> int:
	var col: Object = hit.collider
	if col and col.has_method("take_damage"):
		var head: bool = hit.position.y - (col as Node3D).global_position.y > 1.42
		col.take_damage(dmg * (2.2 if head else 1.0), knock, dir)
		puff(hit.position, Color(0.45, 0.05, 0.04), 7)
		return 2 if head else 1
	puff(hit.position, Color(0.55, 0.52, 0.46), 5)
	bullet_hole(hit.position, hit.normal)
	return 0

# ---------------------------------------------------------------- effects
func _fx_setup() -> void:
	_hole_mesh = QuadMesh.new()
	_hole_mesh.size = Vector2(0.09, 0.09)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.05, 0.05, 0.05)
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hole_mesh.material = hm
	for i in 64:
		var mi := MeshInstance3D.new()
		mi.mesh = _hole_mesh
		mi.visible = false
		add_child(mi)
		_holes.append(mi)
	_fx_mat = StandardMaterial3D.new()
	_fx_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fx_mat.vertex_color_use_as_albedo = true
	_fx_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func bullet_hole(pos: Vector3, normal: Vector3) -> void:
	var mi := _holes[_hole_i]
	_hole_i = (_hole_i + 1) % _holes.size()
	mi.visible = true
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(-normal, up), pos + normal * 0.01)

func puff(pos: Vector3, color: Color, amount := 8) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = m
	p.mesh = bm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func casing(pos: Vector3, dir: Vector3, shell := false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 1
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = dir
	p.spread = 12.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.2
	p.angular_velocity_min = 400.0
	p.angular_velocity_max = 900.0
	p.gravity = Vector3(0, -9.8, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, 0.05) if shell else Vector3(0.007, 0.007, 0.022)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.1, 0.08) if shell else Color(0.85, 0.62, 0.22)
	m.metallic = 0.6
	m.roughness = 0.35
	bm.material = m
	p.mesh = bm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func smoke(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 4
	p.lifetime = 0.7
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.4, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.09
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.75, 0.75, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = m
	p.mesh = bm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func tracer(from: Vector3, to: Vector3) -> void:
	var len := from.distance_to(to)
	if len < 1.0:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.015, 0.015, len)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.5, 0.8)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = m
	mi.mesh = bm
	add_child(mi)
	mi.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT), (from + to) / 2.0)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.07)
	tw.tween_callback(mi.queue_free)

# ---------------------------------------------------------------- map
func _map_image() -> void:
	var px := 256
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			var wx := -SIZE / 2.0 + (x + 0.5) * SIZE / px
			var wz := -SIZE / 2.0 + (y + 0.5) * SIZE / px
			var h := height_at(wx, wz)
			var c: Color
			if h < 0.0:
				c = Color(0.16, 0.36, 0.52).darkened(clampf(-h / 10.0, 0.0, 0.5))
			else:
				c = _type_color(ground_type(wx, wz), wx, wz).lightened(0.12)
				var shade := height_at(wx + 2.0, wz + 2.0) - h
				c = c.darkened(clampf(shade * 0.08, -0.15, 0.25))
			img.set_pixel(x, y, c)
	for rd in roads:
		var rp: PackedVector2Array = rd.pts
		for k in rp.size() - 1:
			for t in 6:
				var q := rp[k].lerp(rp[k + 1], t / 6.0)
				var mx := int((q.x + SIZE / 2.0) / SIZE * px)
				var my := int((q.y + SIZE / 2.0) / SIZE * px)
				for oy in range(-1, 1):
					for ox in range(-1, 1):
						if mx + ox >= 0 and my + oy >= 0 and mx + ox < px and my + oy < px:
							img.set_pixel(mx + ox, my + oy, Color(0.30, 0.29, 0.28))
	for st in sites:
		if st.park != null:
			var pr: Rect2 = st.park
			for yy in range(int((pr.position.y + SIZE / 2.0) / SIZE * px), int((pr.end.y + SIZE / 2.0) / SIZE * px) + 1):
				for xx in range(int((pr.position.x + SIZE / 2.0) / SIZE * px), int((pr.end.x + SIZE / 2.0) / SIZE * px) + 1):
					if xx >= 0 and yy >= 0 and xx < px and yy < px:
						img.set_pixel(xx, yy, Color(0.34, 0.33, 0.32))
	for st in sites:
		var r: Rect2 = st.rect
		for yy in range(int((r.position.y + SIZE / 2.0) / SIZE * px), int((r.end.y + SIZE / 2.0) / SIZE * px) + 1):
			for xx in range(int((r.position.x + SIZE / 2.0) / SIZE * px), int((r.end.x + SIZE / 2.0) / SIZE * px) + 1):
				if xx >= 0 and yy >= 0 and xx < px and yy < px:
					img.set_pixel(xx, yy, {"church": Color(0.45, 0.2, 0.18), "dealership": Color(0.2, 0.3, 0.55), "hangar": Color(0.3, 0.4, 0.25)}.get(st.kind, Color(0.22, 0.2, 0.2)))
	map_texture = ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- grass and pebbles
func _grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	var blade := _grass_mesh()
	var pebble := BoxMesh.new()
	pebble.size = Vector3(0.22, 0.12, 0.18)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.45, 0.44, 0.42)
	pebble.material = pm
	var chunk := 24.0
	var n := int(SIZE / chunk)
	for cj in n:
		for ci in n:
			var x0 := -SIZE / 2.0 + ci * chunk
			var z0 := -SIZE / 2.0 + cj * chunk
			var g: Array[Transform3D] = []
			var r: Array[Transform3D] = []
			for k in 380:
				var x := x0 + rng.randf() * chunk
				var z := z0 + rng.randf() * chunk
				var t := ground_type(x, z)
				var h := height_at(x, z)
				if t == "grass":
					var sc := rng.randf_range(0.7, 1.5)
					g.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc)), Vector3(x, h - 0.02, z)))
				elif (t == "rock" or t == "dirt") and rng.randf() < (0.12 if t == "rock" else 0.03):
					var sc := rng.randf_range(0.4, 1.6)
					var b := Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)).scaled(Vector3(sc, sc, sc))
					r.append(Transform3D(b, Vector3(x, h, z)))
			if not g.is_empty():
				var mmi := _multimesh(blade, g, 75.0)
				grass_mm.append([mmi.multimesh, g.size()])
				grass_chunks.append([mmi, Vector3(x0 + chunk / 2.0, 0, z0 + chunk / 2.0)])
			if not r.is_empty():
				_multimesh(pebble, r, 110.0)

func _multimesh(mesh: Mesh, xforms: Array[Transform3D], vis: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = vis
	mmi.visibility_range_end_margin = 10.0
	add_child(mmi)
	return mmi

func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a := k * TAU / 5.0 + randf() * 0.4
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.035
		var base := d * 0.05
		var tip := d * 0.16 + Vector3(0, 0.42 + randf() * 0.15, 0)
		for v in [[base - side, Color(0.13, 0.30, 0.08)], [base + side, Color(0.13, 0.30, 0.08)], [tip, Color(0.42, 0.66, 0.22)]]:
			st.set_normal(Vector3.UP)
			st.set_color(v[1])
			st.add_vertex(v[0])
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	mesh.surface_set_material(0, m)
	return mesh

# ---------------------------------------------------------------- props
## With a dealership the vehicles come from Bjørn; without one they are parked near the spawn.
func _vehicles(spawn: Vector3) -> void:
	var dealer = site_of("dealership")
	if dealer:
		Game.msg("Bjørn at the old car dealership (%s) has a Tike and a motorbike for you" % Game.sector(dealer.pos), Color(1, 0.9, 0.6))
		return
	for kind in ["tike", "bike"]:
		var v := give_vehicle(kind)
		v.global_position = spawn + (Vector3(5, 0.3, -4) if kind == "tike" else Vector3(9, 0.3, -1))
		v.global_position.y = height_at(v.global_position.x, v.global_position.z) + 0.2
