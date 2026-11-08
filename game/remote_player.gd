extends Node3D
## Another player in the party, as seen on this machine. Smoothly follows the states that arrive
## over the relay (15 per second). Visual only in this version: no collision, no damage.

const VEHICLE_GLB := {"tike": "res://assets/glb/vehicle_tike.glb", "bike": "res://assets/glb/vehicle_bike.glb",
	"atv": "res://assets/glb/vehicle_atv.glb", "sedan": "res://assets/glb/vehicle_sedan.glb", "heli": "res://assets/glb/vehicle_heli.glb"}

var id := 0
var body: Node3D
var tag: Label3D
var look_key := ""
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var speed := 0.0
var vkind := ""
var vmodel: Node3D
var rotor: Node3D
var _first := true

func setup(pid: int) -> void:
	id = pid
	tag = Label3D.new()
	tag.font_size = 48
	tag.pixel_size = 0.004
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.outline_size = 10
	tag.modulate = Color(0.6, 0.9, 1.0)
	tag.position = Vector3(0, 2.15, 0)
	add_child(tag)
	refresh_member()

## Name and look come from the party list (they can change in the lobby).
func refresh_member() -> void:
	var m: Dictionary = Net.members.get(id, {})
	tag.text = str(m.get("name", "Player %d" % id))
	var key := str(m.get("look", {}))
	if key != look_key or body == null:
		look_key = key
		if body:
			body.queue_free()
		body = Game.make_character(Game.Character.unpack(m.get("look", {})))
		add_child(body)
		if vkind != "":
			_seat()

func apply_state(d: Dictionary) -> void:
	target_pos = d.get("p", target_pos)
	target_yaw = d.get("y", target_yaw)
	speed = d.get("s", 0.0)
	visible = not d.get("d", false)
	var vk: String = d.get("v", "")
	if vk != vkind:
		_set_vehicle(vk)
	if _first:
		_first = false
		global_position = target_pos
		rotation.y = target_yaw

func _set_vehicle(k: String) -> void:
	vkind = k
	if vmodel:
		vmodel.queue_free()
		vmodel = null
		rotor = null
	if body and body.get_parent() != self:
		body.get_parent().remove_child(body)
		add_child(body)
	if k == "" or not VEHICLE_GLB.has(k):
		vkind = ""
		body.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		body.build(body.look)
		tag.position.y = 2.15
		return
	vmodel = load(VEHICLE_GLB[k]).instantiate()
	add_child(vmodel)
	for sb in vmodel.find_children("*", "StaticBody3D", true, false):
		sb.free()
	rotor = vmodel.find_child("Rotor", true, false)
	_seat()
	tag.position.y = 3.2 if k == "heli" else 2.3

func _seat() -> void:
	if vmodel == null:
		return
	var seat: Node3D = vmodel.find_child("SEAT", true, false)
	if body.get_parent():
		body.get_parent().remove_child(body)
	vmodel.add_child(body)
	body.position = vmodel.to_local(seat.global_position) if seat else Vector3(0, 0.6, 0)
	body.rotation.y = PI          # vehicles drive towards +Z, characters face -Z
	body.sit()

func _process(dt: float) -> void:
	var k := minf(dt * 10.0, 1.0)
	if global_position.distance_to(target_pos) > 25.0:
		global_position = target_pos          # teleport / respawn
	else:
		global_position = global_position.lerp(target_pos, k)
	if vkind == "":
		rotation.y = lerp_angle(rotation.y, target_yaw, k)   # the player looks down -Z; the body faces -Z too
		if body:
			body.animate(dt, speed)
	else:
		rotation.y = lerp_angle(rotation.y, target_yaw, k)
	if rotor:
		rotor.rotate_object_local(Vector3.UP, 28.0 * dt)
