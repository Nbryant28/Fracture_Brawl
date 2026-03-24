extends "res://characters/base_character.gd"

var move_speed = 6.0
var attack_range = 2.5
var detection_range = 15.0
var attack_cooldown = 0.0
const ATTACK_COOLDOWN_MAX = 1.5

var player = null

func _ready():
	# Find player dynamically — works regardless of scene structure
	await get_tree().process_frame
	var characters = get_tree().get_nodes_in_group("characters")
	for c in characters:
		if c.name == "Paladin":
			player = c
			break
	print("CPU found player: ", player)

func _physics_process(delta):
	super(delta)
	handle_cpu_behavior(delta)

func handle_movement():
	pass

func handle_jump():
	pass

func handle_cpu_behavior(delta):
	pass

func move_toward_player():
	if player == null:
		return
	var direction = (player.global_position - global_position).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

func stop_moving():
	velocity.x = 0
	velocity.z = 0

func cpu_attack():
	if is_staggered:
		return
	attack_cooldown = ATTACK_COOLDOWN_MAX
	player.take_damage(50)
	print("CPU attacks! Player health: ", player.health)
