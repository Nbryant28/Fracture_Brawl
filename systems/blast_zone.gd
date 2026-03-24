extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is CharacterBody3D:
		body.position = Vector3(0, 4, 0)
		body.velocity = Vector3.ZERO
		# Reset airborne and stagger states
		body.is_airborne = false
		body.is_staggered = false
		body.stagger_timer = 0.0
		body.start_blink()
