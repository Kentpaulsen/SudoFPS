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
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

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
		["tree", 190, 5.0, 2.2, 18.0, tree_d],
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
func _vehicles(spawn: Vector3) -> void:
	var specs := [["res://assets/glb/vehicle_tike.glb", "tike", Vector3(5, 0, -4), 2.4],
				  ["res://assets/glb/vehicle_bike.glb", "bike", Vector3(8, 0, -1), 1.2]]
	for sp in specs:
		var p: Vector3 = spawn + sp[2]
		p.y = height_at(p.x, p.z) + 0.2
		var v := CharacterBody3D.new()
		v.set_script(load("res://game/vehicle.gd"))
		add_child(v)
		v.setup(sp[0], sp[1])
		v.global_position = p
		v.rotation.y = sp[3]
		vehicles.append(v)
