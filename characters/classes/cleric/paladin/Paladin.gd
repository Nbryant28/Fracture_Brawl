extends "res://characters/classes/cleric/cleric_base.gd"
# ============================================================
# CONSTANTS
# ============================================================

# ============================================================
# COOLDOWNS
# ============================================================
var attack_cooldown = 0.0
const ATTACK_COOLDOWN_MAX = 0.5
var retribution_cooldown = 0.0
const RETRIBUTION_COOLDOWN_MAX = 8.0

# ============================================================
# COMBO TRACKING
# ============================================================
var combo_count = 0
var combo_timer = 0.0
const COMBO_WINDOW = 0.8

# ============================================================
# INDOMITABLE
# ============================================================
var indomitable_used = false

# ============================================================
# READY — set model and animation references
# ============================================================
func _ready():
	SPEED = 6.5
	DASH_SPEED = 15.0
	model_node = $Model/Paladinv1
	var anim = $Model/Paladinv1.get_node_or_null("AnimationPlayer")
	if anim:
		anim_player = anim
		anim_player.play("idle")
		print("Animations found: ", anim_player.get_animation_list())
	else:
		print("No AnimationPlayer found in model")

# ============================================================
# MAIN LOOP
# ============================================================
func _physics_process(delta):
	super(delta)
	handle_paladin_abilities()
	handle_attack_cooldown(delta)
	handle_combo_timer(delta)
	handle_cleric_cooldowns(delta)
	check_indomitable()

# ============================================================
# COOLDOWN HANDLERS
# ============================================================
func handle_attack_cooldown(delta):
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if retribution_cooldown > 0:
		retribution_cooldown -= delta

func handle_combo_timer(delta):
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0

# ============================================================
# ABILITY HANDLER
# ============================================================
func handle_paladin_abilities():
	if is_blocking:
		return
	if is_silenced:
		return

	# Retribution usable ANY time — even staggered or airborne
	if Input.is_action_just_pressed("ability_2"):
		use_retribution()

	# Everything else blocked during stagger
	if is_staggered:
		return

	if Input.is_action_just_pressed("attack_1") and attack_cooldown <= 0:
		use_sword_strike()
	if Input.is_action_just_pressed("attack_2") and attack_cooldown <= 0:
		use_shield_slam()
	if Input.is_action_just_pressed("ability_1"):
		use_aegis()
	if Input.is_action_pressed("ability_1") and Input.is_action_just_pressed("ability_2"):
		use_crusade()

# ============================================================
# X — SWORD STRIKE
# ============================================================
func use_sword_strike():
	attack_cooldown = ATTACK_COOLDOWN_MAX
	combo_count += 1
	combo_timer = COMBO_WINDOW
	play_anim("attack")
	print("Sword Strike — combo count: ", combo_count)

	var hitbox = Area3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.5, 3.0, 2.0)
	shape.shape = box
	hitbox.add_child(shape)
	hitbox.position = Vector3(1.8, 1.0, 0)
	add_child(hitbox)
	hitbox.body_entered.connect(_on_sword_hit)
	await get_tree().create_timer(0.25).timeout
	hitbox.queue_free()

func _on_sword_hit(body):
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(80, "physical", [])
		body.apply_sear(5.0, 3.0)
		if not body.is_blocking:
			body.apply_stagger()
		primary_meter = min(primary_meter + 10.0, primary_meter_max)
		print("Sword Strike hit! Combo: ", combo_count, " Enemy HP: ", body.health)

# ============================================================
# C — SHIELD SLAM
# ============================================================
func use_shield_slam():
	attack_cooldown = ATTACK_COOLDOWN_MAX

	var is_combo_ender = combo_count >= 2
	combo_count = 0
	combo_timer = 0.0

	var hitbox = Area3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	shape.shape = box
	hitbox.add_child(shape)
	hitbox.position = Vector3(1.2, 0, 0)
	add_child(hitbox)

	if is_combo_ender:
		hitbox.body_entered.connect(_on_shield_slam_launch)
	else:
		hitbox.body_entered.connect(_on_shield_slam_basic)

	await get_tree().create_timer(0.2).timeout
	hitbox.queue_free()

func _on_shield_slam_basic(body):
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(60, "physical", [])
		if not body.is_blocking:
			body.apply_stagger()
		primary_meter = min(primary_meter + 8.0, primary_meter_max)
		print("Shield Slam hit!")

func _on_shield_slam_launch(body):
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(90, "physical", [])
		if not body.is_blocking:
			var dir_to_enemy = (body.global_position - global_position).normalized()
			body.velocity.x = dir_to_enemy.x * 3.0
			body.velocity.z = dir_to_enemy.z * 3.0
			body.velocity.y = 17.0
			body.apply_airborne()
			body.is_staggered = true
			body.stagger_timer = 1.8
		primary_meter = min(primary_meter + 15.0, primary_meter_max)
		print("LAUNCHER! Enemy airborne!")

# ============================================================
# B — SACRED WORD: RETRIBUTION
# ============================================================
func use_retribution():
	if retribution_cooldown > 0:
		return
	if is_silenced:
		return

	retribution_cooldown = RETRIBUTION_COOLDOWN_MAX

	if is_staggered:
		is_staggered = false
		stagger_timer = 0.0

	is_invincible = true

	var aoe_radius = 3.0
	if primary_meter >= 33:
		aoe_radius = 5.0
	if primary_meter >= 66:
		aoe_radius = 8.0

	var hitbox = Area3D.new()
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = aoe_radius
	shape.shape = sphere
	hitbox.add_child(shape)
	hitbox.position = Vector3.ZERO
	add_child(hitbox)
	hitbox.body_entered.connect(_on_retribution_hit)

	await get_tree().create_timer(0.3).timeout
	hitbox.queue_free()

	await get_tree().create_timer(0.2).timeout
	is_invincible = false

	print("Sacred Word: Retribution!")

func _on_retribution_hit(body):
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(70, "physical", ["Stun"])
		body.apply_sear(8.0, 3.0)
		body.apply_interrupt()
		primary_meter = min(primary_meter + 12.0, primary_meter_max)
		print("Retribution hit! Enemy HP: ", body.health)

# ============================================================
# V — SACRED WORD: AEGIS
# ============================================================
func use_aegis():
	pass

# ============================================================
# V + B — DIVINE WORD: CRUSADE
# ============================================================
func use_crusade():
	pass

# ============================================================
# INDOMITABLE PASSIVE
# ============================================================
func check_indomitable():
	if health < max_health * 0.15 and not indomitable_used:
		indomitable_used = true
		is_cc_immune = true
		is_staggered = false
		stagger_timer = 0.0
		is_invincible = true
		apply_shielded(3.0)
		primary_meter = min(primary_meter + 20.0, primary_meter_max)
		print("INDOMITABLE!")
		await get_tree().create_timer(3.0).timeout
		is_cc_immune = false
		is_invincible = false

# ============================================================
# GRAB
# ============================================================
func spawn_grab_hitbox():
	print("Holy Slam!")
