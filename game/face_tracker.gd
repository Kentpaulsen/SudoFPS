extends Node3D
## Parked vehicle: gives it a collision box and makes its pupils follow the player.

var pupils: Array = []   # [node, rest position, max offset]

func setup() -> void:
	var aabb := AABB()
	var first := true
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var box: AABB = (global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
		if m.name.begins_with("Pupil"):
			pupils.append([m, m.position, m.get_aabb().size.x * 0.45])
	var sb := StaticBody3D.new()
	sb.collision_layer = Game.L_WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = aabb.size * Vector3(0.9, 0.95, 0.9)
	cs.shape = bs
	cs.position = aabb.get_center()
	sb.add_child(cs)
	add_child(sb)

func _process(_dt: float) -> void:
	var pl = Game.player
	if pl == null or pl.global_position.distance_to(global_position) > 40.0:
		return
	var target = pl.global_position + Vector3(0, 1.6, 0)
	for e in pupils:
		var p: Node3D = e[0]
		var local: Vector3 = p.get_parent().to_local(target) - e[1]
		var d := local.normalized()
		p.position = p.position.lerp(e[1] + Vector3(d.x, d.y, 0.0) * e[2], 0.15)
