extends Camera3D

@onready var target = get_node("../Paladin")

const OFFSET = Vector3(0, 8, 14)
const SMOOTH = 5.0
const FALL_THRESHOLD = -15.0  # Y position where camera stops following
const STAGE_POSITION = Vector3(0, 8, 14)  # where camera returns to

var following = true

func _physics_process(delta):
	if target.global_position.y < FALL_THRESHOLD:
		# Player is falling toward blast zone
		# Camera smoothly returns to stage center
		following = false
		global_position = global_position.lerp(STAGE_POSITION, SMOOTH * delta)
	else:
		# Player is on stage — follow them
		following = true
		var target_pos = target.global_position + OFFSET
		global_position = global_position.lerp(target_pos, SMOOTH * delta)
