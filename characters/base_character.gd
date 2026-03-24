extends CharacterBody3D

# ============================================================
# STATS
# ============================================================
var health = 1000
var max_health = 1000
var defense = 0.0

# ============================================================
# METERS
# ============================================================
var primary_meter = 0.0
var primary_meter_max = 100.0

# ============================================================
# MODEL + ANIMATION
# ============================================================
var model_node: Node3D = null
var anim_player: AnimationPlayer = null

# ============================================================
# STATE FLAGS
# ============================================================
var is_invincible = false
var is_suppressed = false
var is_airborne = false
var is_powered = false
var is_cc_immune = false
var is_blocking = false
var is_grabbing = false
var is_countering = false
var is_grounded = true
var is_silenced = false
var is_shielded = false
var is_charged = false
var is_interrupted = false
var is_staggered = false
var is_dashing = false

# ============================================================
# DOT STACKS
# ============================================================
var burn_stacks = 0
var burn_max_stacks = 3
var burn_timer = 0.0
var burn_tick_timer = 0.0
var burn_tick_rate = 1.0
var burn_damage_per_stack = 0.0

var bleed_active = false
var bleed_timer = 0.0
var bleed_duration = 5.0
var bleed_damage = 0.0

var corrode_stacks = 0
var corrode_max_stacks = 3
var corrode_timer = 0.0
var corrode_tick_timer = 0.0
var corrode_tick_rate = 1.0
var corrode_damage_per_stack = 0.0

var sear_active = false
var sear_timer = 0.0
var sear_duration = 3.0
var sear_damage = 0.0
var sear_tick_rate = 1.0
var sear_tick_timer = 0.0

# ============================================================
# TIMERS
# ============================================================
var blink_timer = 0.0
var grab_cooldown = 0.0
var counter_cooldown = 0.0
var stun_timer = 0.0
var stagger_timer = 0.0
var silence_timer = 0.0
var suppressed_timer = 0.0
var shielded_timer = 0.0
var stun_immunity_timer = 0.0
var stun_count = 0
var stun_dr_window = 3.0
var jump_count = 0
var max_jumps = 2
var dash_timer = 0.0
var dash_cooldown = 0.0
const DASH_DURATION = 0.2
var DASH_COOLDOWN_MAX = 0.8
var DASH_SPEED = 13.0

# ============================================================
# CONSTANTS
# ============================================================
var SPEED = 6.0
const JUMP_VELOCITY = 12.0
const GRAVITY = 25.0
const BLINK_DURATION = 2.0
const BLINK_SPEED = 0.1
const GRAB_COOLDOWN_MAX = 1.0
const COUNTER_COOLDOWN_MAX = 1.0
const STAGGER_DURATION = 0.4
var last_tap_direction = Vector3.ZERO
var last_tap_time = 0.0
const DOUBLE_TAP_WINDOW = 0.3

# ============================================================
# MAIN LOOP
# ============================================================
func _physics_process(delta):
	handle_blink(delta)
	handle_gravity(delta)
	handle_dash(delta)
	handle_movement()
	handle_jump()
	handle_universal_combat(delta)
	handle_dot_ticks(delta)
	handle_state_timers(delta)
	handle_facing()
	detect_dash()
	handle_animation()
	move_and_slide()

# ============================================================
# MOVEMENT
# ============================================================
func handle_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		is_grounded = false
	else:
		is_grounded = true
		if is_airborne:
			land()

func handle_movement():
	if stun_timer > 0:
		return
	if is_staggered:
		return
	if is_dashing:
		return
	if is_blocking:
		velocity.x = 0
		velocity.z = 0
		return
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_right"):
		direction.x = 1
	if Input.is_action_pressed("move_left"):
		direction.x = -1
	if Input.is_action_pressed("move_up"):
		direction.z = -1
	if Input.is_action_pressed("move_down"):
		direction.z = 1
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

func handle_jump():
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jump_count = 1
			play_anim("jump")
		elif jump_count < max_jumps:
			velocity.y = JUMP_VELOCITY
			jump_count += 1
			play_anim("jump")
	
	# Reset jump count on landing
	if is_on_floor() and jump_count > 0 and velocity.y <= 0:
		jump_count = 0

# ============================================================
# DASH
# ============================================================
func handle_dash(delta):
	if dash_cooldown > 0:
		dash_cooldown -= delta
	
	if not is_dashing:
		return
	
	# Continue dash while any direction key is held
	var direction = Vector3.ZERO
	
	if Input.is_action_pressed("move_right"):
		direction.x = 1
	if Input.is_action_pressed("move_left"):
		direction.x = -1
	if Input.is_action_pressed("move_up"):
		direction.z = -1
	if Input.is_action_pressed("move_down"):
		direction.z = 1
	
	if direction != Vector3.ZERO:
		# Normalize so diagonal speed equals straight speed
		direction = direction.normalized()
		velocity.x = direction.x * DASH_SPEED
		velocity.z = direction.z * DASH_SPEED
	else:
		# No keys held — end dash
		is_dashing = false

func try_dash(direction: Vector3):
	if dash_cooldown > 0:
		return
	if is_staggered or is_airborne:
		return
	is_dashing = true
	dash_cooldown = DASH_COOLDOWN_MAX
	play_anim("dash")

# ============================================================
# FACING DIRECTION — universal for all characters
# ============================================================
func handle_facing():
	if model_node == null:
		return
	
	# Only rotate if actually moving
	var move_vec = Vector2(velocity.x, velocity.z)
	if move_vec.length() < 0.1:
		return
	
	# Calculate angle from movement direction
	var target_angle = atan2(move_vec.x, move_vec.y)
	
	# Smooth rotation — lerp toward target
	model_node.rotation.y = lerp_angle(
		model_node.rotation.y, 
		target_angle, 
		0.2
	)

# ============================================================
# ANIMATION — universal for all characters
# ============================================================
func handle_animation():
	if anim_player == null:
		return
	# Priority order — highest first
	if is_staggered:
		play_anim("hit")
		return
	if is_dashing:
		play_anim("dash")
		return
	if not is_on_floor():
		play_anim("jump")
		return
	var moving = abs(velocity.x) > 0.1 or abs(velocity.z) > 0.1
	if moving:
		play_anim("walk")
	else:
		play_anim("idle")

func play_anim(anim_name: String):
	if anim_player == null:
		return
	if not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation == anim_name:
		return
	anim_player.play(anim_name)
func detect_dash():
	var current_time = Time.get_ticks_msec() / 1000.0
	var direction = Vector3.ZERO
	
	if Input.is_action_just_pressed("move_right"):
		direction = Vector3(1, 0, 0)
	elif Input.is_action_just_pressed("move_left"):
		direction = Vector3(-1, 0, 0)
	elif Input.is_action_just_pressed("move_up"):
		direction = Vector3(0, 0, -1)
	elif Input.is_action_just_pressed("move_down"):
		direction = Vector3(0, 0, 1)
	
	if direction != Vector3.ZERO:
		if direction == last_tap_direction and (current_time - last_tap_time) < DOUBLE_TAP_WINDOW:
			# Double tap detected
			try_dash(direction)
			last_tap_direction = Vector3.ZERO
		else:
			last_tap_direction = direction
			last_tap_time = current_time

# ============================================================
# UNIVERSAL COMBAT
# ============================================================
func handle_universal_combat(delta):
	handle_cooldowns(delta)
	
	if Input.is_action_pressed("block") and not is_airborne:
		is_blocking = true
	else:
		is_blocking = false
	
	if Input.is_action_pressed("block") and Input.is_action_just_pressed("attack_2"):
		if counter_cooldown <= 0 and not is_suppressed:
			use_counter()
			if is_staggered:
				is_staggered = false
				stagger_timer = 0.0
	
	if Input.is_action_pressed("attack_1") and Input.is_action_just_pressed("attack_2"):
		if grab_cooldown <= 0 and not is_suppressed and not is_staggered:
			use_grab()

func handle_cooldowns(delta):
	if grab_cooldown > 0:
		grab_cooldown -= delta
	if counter_cooldown > 0:
		counter_cooldown -= delta

func use_counter():
	counter_cooldown = COUNTER_COOLDOWN_MAX
	is_countering = true
	await get_tree().create_timer(0.5).timeout
	is_countering = false

func use_grab():
	if is_suppressed:
		return
	grab_cooldown = GRAB_COOLDOWN_MAX
	is_grabbing = true
	spawn_grab_hitbox()
	await get_tree().create_timer(0.3).timeout
	is_grabbing = false


func spawn_grab_hitbox():
	pass

# ============================================================
# DAMAGE
# ============================================================
func take_damage(amount, damage_type = "physical", flags = []):
	if is_invincible:
		return
	
	var final_damage = amount
	
	if "Interrupt" in flags:
		apply_interrupt()
	
	if is_blocking and not "GuardBypass" in flags:
		final_damage *= 0.2
	
	if is_shielded and damage_type == "magic" and not "Burn" in flags:
		final_damage = 0
		shielded_timer = 0.0
		is_shielded = false
		return
	
	if damage_type == "physical" and not "Bleed" in flags:
		final_damage *= (1.0 - defense)
	
	if "Airborne" in flags:
		apply_airborne()
	if "Suppressed" in flags:
		apply_suppressed(2.0)
	if "Silence" in flags:
		apply_silence(3.0)
	if "Stun" in flags:
		apply_stun(0.5)
	
	health -= final_damage
	if health <= 0:
		health = 0
		die()

func calculate_true_damage(amount):
	health -= amount
	if health <= 0:
		health = 0
		die()

# ============================================================
# DOT APPLICATION
# ============================================================
func apply_burn(stacks, damage_percent):
	burn_stacks = min(burn_stacks + stacks, burn_max_stacks)
	burn_damage_per_stack = damage_percent * max_health
	burn_timer = 6.0
	burn_tick_timer = burn_tick_rate

func apply_bleed(damage, duration):
	bleed_active = true
	bleed_damage = damage
	bleed_timer = duration

func apply_corrode(stacks, damage_per_stack):
	corrode_stacks = min(corrode_stacks + stacks, corrode_max_stacks)
	corrode_damage_per_stack = damage_per_stack
	corrode_timer = 4.0
	corrode_tick_timer = corrode_tick_rate

func apply_sear(damage, duration):
	sear_active = true
	sear_damage = damage
	sear_timer = duration
	sear_tick_timer = sear_tick_rate

func remove_corrode_stack():
	corrode_stacks = max(corrode_stacks - 1, 0)

# ============================================================
# DOT TICKS
# ============================================================
func handle_dot_ticks(delta):
	handle_burn_tick(delta)
	handle_bleed_tick(delta)
	handle_corrode_tick(delta)
	handle_sear_tick(delta)

func handle_burn_tick(delta):
	if burn_stacks <= 0:
		return
	burn_timer -= delta
	if burn_timer <= 0:
		burn_stacks = 0
		return
	burn_tick_timer -= delta
	if burn_tick_timer <= 0:
		burn_tick_timer = burn_tick_rate
		var burn_damage = burn_damage_per_stack * burn_stacks
		health -= burn_damage
		if health <= 0:
			health = 0
			die()

func handle_bleed_tick(delta):
	if not bleed_active:
		return
	bleed_timer -= delta
	if bleed_timer <= 0:
		bleed_active = false
		return
	health -= bleed_damage * delta
	if health <= 0:
		health = 0
		die()

func handle_corrode_tick(delta):
	if corrode_stacks <= 0:
		return
	corrode_timer -= delta
	if corrode_timer <= 0:
		corrode_stacks = 0
		return
	corrode_tick_timer -= delta
	if corrode_tick_timer <= 0:
		corrode_tick_timer = corrode_tick_rate
		var corrode_damage = corrode_damage_per_stack * corrode_stacks
		health -= corrode_damage
		if health <= 0:
			health = 0
			die()

func handle_sear_tick(delta):
	if not sear_active:
		return
	sear_timer -= delta
	if sear_timer <= 0:
		sear_active = false
		return
	sear_tick_timer -= delta
	if sear_tick_timer <= 0:
		sear_tick_timer = sear_tick_rate
		health -= sear_damage
		if health <= 0:
			health = 0
			die()

# ============================================================
# KEYWORD STATES
# ============================================================
func apply_suppressed(duration):
	if is_cc_immune:
		return
	is_suppressed = true
	suppressed_timer = duration

func apply_silence(duration):
	if is_cc_immune:
		return
	is_silenced = true
	silence_timer = duration

func apply_stun(duration):
	if is_cc_immune:
		return
	stun_count += 1
	if stun_count >= stun_dr_window:
		stun_immunity_timer = 2.0
		stun_count = 0
		return
	stun_timer = duration

func apply_stagger():
	if is_cc_immune:
		return
	if is_staggered:
		return
	if is_blocking:
		return
	is_staggered = true
	stagger_timer = STAGGER_DURATION
	var push_dir = -global_transform.basis.z
	velocity.x += push_dir.x * 3.0
	velocity.z += push_dir.z * 3.0

func apply_airborne():
	if is_cc_immune:
		return
	is_airborne = true

func apply_shielded(duration):
	is_shielded = true
	shielded_timer = duration

func apply_interrupt():
	is_interrupted = true
	await get_tree().create_timer(0.1).timeout
	is_interrupted = false

func apply_knockback(direction, force):
	if is_cc_immune:
		return
	if is_blocking:
		force *= 0.2
	velocity.x = direction.x * force
	velocity.z = direction.z * force
	velocity.y = force * 0.3
	if force > 5.0:
		apply_airborne()

func land():
	is_airborne = false
	is_grounded = true

# ============================================================
# STATE TIMERS
# ============================================================
func handle_state_timers(delta):
	if suppressed_timer > 0:
		suppressed_timer -= delta
		if suppressed_timer <= 0:
			is_suppressed = false
	if silence_timer > 0:
		silence_timer -= delta
		if silence_timer <= 0:
			is_silenced = false
	if stun_timer > 0:
		stun_timer -= delta
	if stagger_timer > 0:
		stagger_timer -= delta
		if stagger_timer <= 0:
			is_staggered = false
	if stun_immunity_timer > 0:
		stun_immunity_timer -= delta
	if shielded_timer > 0:
		shielded_timer -= delta
		if shielded_timer <= 0:
			is_shielded = false

# ============================================================
# BLINK
# ============================================================
func start_blink():
	is_invincible = true
	blink_timer = BLINK_DURATION

func handle_blink(delta):
	if blink_timer > 0:
		blink_timer -= delta
		var blink_cycle = fmod(blink_timer, BLINK_SPEED * 2)
		if model_node:
			model_node.visible = blink_cycle > BLINK_SPEED
		if blink_timer <= 0:
			if model_node:
				model_node.visible = true
			is_invincible = false

# ============================================================
# DEATH
# ============================================================
func die():
	position = Vector3(0, 4, 0)
	velocity = Vector3.ZERO
	health = max_health
	burn_stacks = 0
	bleed_active = false
	corrode_stacks = 0
	sear_active = false
	is_suppressed = false
	is_silenced = false
	is_airborne = false
	is_shielded = false
	is_staggered = false
	is_dashing = false
	stagger_timer = 0.0
	stun_timer = 0.0
	start_blink()
