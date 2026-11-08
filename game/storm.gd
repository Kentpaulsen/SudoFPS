extends Node3D
## Hex Horizon: a shrinking hexagonal storm. Pointy-top hex; two edges run parallel to the X axis.

# [wait seconds, shrink seconds, size factor]
const PHASES := [[45.0, 40.0, 0.62], [40.0, 35.0, 0.6], [35.0, 30.0, 0.55], [30.0, 28.0, 0.5], [25.0, 25.0, 0.45], [20.0, 20.0, 0.0]]
const NORMALS := [Vector2(0.8660254, 0.5), Vector2(0.0, 1.0), Vector2(-0.8660254, 0.5)]

var center := Vector2.ZERO
var radius := 235.0        # circumradius in metres
var from_c := Vector2.ZERO
var from_r := 0.0
var next_c := Vector2.ZERO
var next_r := 0.0
var phase := 0
var state := "wait"
var timer := 0.0
var wall: MeshInstance3D
var _veg_t := 0.0
var _crackle_t := 0.0

func _ready() -> void:
	wall = MeshInstance3D.new()
	wall.mesh = _hex_mesh()
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(0.62, 0.25, 1.0, 0.32);
void fragment() {
	float bands = smoothstep(0.35, 0.5, fract(UV.y * 40.0 - TIME * 0.35)) * smoothstep(0.65, 0.5, fract(UV.y * 40.0 - TIME * 0.35));
	float grid = smoothstep(0.96, 1.0, fract(UV.x * 30.0));
	float fade = smoothstep(1.0, 0.6, UV.y) * smoothstep(0.0, 0.02, UV.y);
	ALBEDO = col.rgb + vec3(0.25, 0.4, 0.45) * (bands + grid);
	ALPHA = col.a * (0.55 + 0.45 * bands + 0.6 * grid) * fade;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	wall.material_override = m
	add_child(wall)
	_plan_next()
	timer = PHASES[0][0]
	_apply()

func _hex_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lo := -30.0
	var hi := 160.0
	for i in 6:
		var a0 := deg_to_rad(60.0 * i)
		var a1 := deg_to_rad(60.0 * (i + 1))
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		var u0 := float(i) / 6.0
		var u1 := float(i + 1) / 6.0
		var quad := [[p0, lo, u0, 0.0], [p1, lo, u1, 0.0], [p1, hi, u1, 1.0], [p0, lo, u0, 0.0], [p1, hi, u1, 1.0], [p0, hi, u0, 1.0]]
		for q in quad:
			st.set_uv(Vector2(q[2], q[3]))
			st.add_vertex(q[0] + Vector3(0, q[1], 0))
	return st.commit()

func apothem(r: float) -> float:
	return r * 0.8660254

func inside(p: Vector2) -> bool:
	return edge_distance(p) >= 0.0

## Metres inside the zone (negative = outside).
func edge_distance(p: Vector2) -> float:
	var q := p - center
	var m := 0.0
	for n in NORMALS:
		m = maxf(m, absf(q.dot(n)))
	return apothem(radius) - m

func _plan_next() -> void:
	if phase >= PHASES.size():
		state = "done"
		return
	next_r = maxf(radius * PHASES[phase][2], 0.0)
	var room := maxf(apothem(radius) - apothem(next_r), 0.0) * 0.85
	var w = Game.world
	next_c = center
	for i in 40:
		var off := Vector2.from_angle(randf() * TAU) * randf() * room
		var c := center + off
		if w.is_land(c.x, c.y, 0.5, 40.0) or i == 39:
			next_c = c
			break

func _process(dt: float) -> void:
	timer -= dt
	if state == "wait" and timer <= 0.0:
		state = "shrink"
		from_c = center
		from_r = radius
		timer = PHASES[phase][1]
		Game.msg("Hex Horizon is closing in", Color(0.8, 0.5, 1.0))
	elif state == "shrink":
		var t := 1.0 - clampf(timer / PHASES[phase][1], 0.0, 1.0)
		center = from_c.lerp(next_c, t)
		radius = lerpf(from_r, next_r, t)
		if timer <= 0.0:
			phase += 1
			_plan_next()
			if state != "done":
				state = "wait"
				timer = PHASES[phase][0]
	_apply()
	_veg_t += dt
	if _veg_t > 1.0:
		_veg_t = 0.0
		Game.world.kill_vegetation(inside, 40)
	var pl = Game.player
	if pl and not pl.dead:
		var pd = edge_distance(Vector2(pl.global_position.x, pl.global_position.z))
		if pd < 0.0:
			pl.damage((1.0 + phase * 1.5) * dt)
		_crackle_t -= dt
		if absf(pd) < 8.0 and _crackle_t <= 0.0:
			_crackle_t = randf_range(0.25, 0.7)
			Sfx.play("crackle", lerpf(-2.0, -18.0, absf(pd) / 8.0))

func _apply() -> void:
	wall.position = Vector3(center.x, 0, center.y)
	wall.scale = Vector3(maxf(radius, 0.05), 1, maxf(radius, 0.05))

func status() -> String:
	match state:
		"wait": return "Hex Horizon closes in %d s" % ceili(timer)
		"shrink": return "Hex Horizon closing: %d s" % ceili(timer)
	return "Hex Horizon: final zone"
