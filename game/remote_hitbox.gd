extends AnimatableBody3D
## Hit box on another player in Last Standing. A hit is sent to that player, who applies it.

var owner_id := 0

func take_damage(dmg: float, _knock: Vector3, _dir: Vector3) -> void:
	Net.send(owner_id, "dmg", [dmg])
