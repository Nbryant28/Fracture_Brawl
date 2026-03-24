extends "res://characters/classes/cleric/cleric_base.gd"

# ============================================================
# PALADIN — COMPLETE KIT
# Fantasy: Holy warrior. Shield and sword. Tier B. Easy.
# Inspiration: Reinhard van Astrea + Escanor
# ============================================================

# ============================================================
# COOLDOWNS
# ============================================================
var attack_cooldown = 0.0
const ATTACK_COOLDOWN_MAX = 0.5

var retribution_cooldown = 0.0
const RETRIBUTION_COOLDOWN_MAX = 8.0

var aegis_cooldown = 0.0
const AEGIS_COOLDOWN_MAX = 10.0

var crusade_cooldown = 0.0
const CRUSADE_COOLDOWN_MAX = 30.0  # hard lock — shared with global ult system

var grab_active_cooldown = 0.0
const GRAB_ACTIVE_COOLDOWN_MAX = 1.2

# ============================================================
# COMBO TRACKING
# ============================================================
var combo_count = 0
var combo_timer = 0.0
const COMBO_WINDOW = 0.8

# ============================================================
# SANCTITY METER — tier thresholds
# ============================================================
# Uses primary_meter from base_character (0-100)
# Tier 1: 0-33 | Tier 2: 33-66 | Tier 3: 66-100
var sanctity_idle_timer = 0.0
const SANCTITY_DECAY_DELAY = 5.0
const SANCTITY_DECAY_RATE = 4.0  # points per second after idle

func get_sanctity_tier() -> int:
	if primary_meter >= 66.0:
		return 3
	elif primary_meter >= 33.0:
		return 2
	else:
		return 1
# ============================================================
# Ability Data
# ============================================================
func get_ability_data() -> Array:
	return [
		{
			"name": "Indomitable", "icon": "res://ui/hud/icons/paladin/indomitable.png",
			"type": "passive", "cooldown_var": "indomitable_used", "key": ""
		},
		{
			"name": "Holy Presence", "icon": "res://ui/hud/icons/paladin/holy_presence.png",
			"type": "passive", "cooldown_var": "", "key": ""
		},
		{
			"name": "Bulwark", "icon": "res://ui/hud/icons/paladin/bulwark.png",
			"type": "passive", "cooldown_var": "", "key": ""
		},
		{
			"name": "Divine Retaliation", "icon": "res://ui/hud/icons/paladin/divine_retaliation.png",
			"type": "passive", "cooldown_var": "", "key": ""
		},
		{
			"name": "Hallowed Ground", "icon": "res://ui/hud/icons/paladin/hallowed_ground.png",
			"type": "passive", "cooldown_var": "", "key": ""
		},
		{
			"name": "Aegis", "icon": "res://ui/hud/icons/paladin/aegis.png",
			"type": "ability", "cooldown_var": "aegis_cooldown",
			"cooldown_max": 10.0, "key": "V"
		},
		{
			"name": "Retribution", "icon": "res://ui/hud/icons/paladin/retribution.png",
			"type": "ability", "cooldown_var": "retribution_cooldown",
			"cooldown_max": 8.0, "key": "B"
		},
		{
			"name": "Crusade", "icon": "res://ui/hud/icons/paladin/crusade.png",
			"type": "ultimate", "cooldown_var": "crusade_cooldown",
			"cooldown_max": 30.0, "key": "V+B"
		},
	]

# ============================================================
# INDOMITABLE — once per match
# ============================================================
var indomitable_used = false

# ============================================================
# CRUSADE STATE
# ============================================================
var is_crusading = false
var divine_surge_timer = 0.0
const DIVINE_SURGE_DURATION = 8.0
var crusade_bonus_damage = 0.0  # +25% during Divine Surge

# ============================================================
# PASSIVE: DIVINE RETALIATION
# Every blocked hit — allies get +3% attack boost 4s (stacks x3)
# ============================================================
var divine_retaliation_stacks = 0
const DIVINE_RETALIATION_MAX_STACKS = 3
const DIVINE_RETALIATION_BOOST = 0.03  # 3% per stack
var divine_retaliation_timer = 0.0
const DIVINE_RETALIATION_DURATION = 4.0

# ============================================================
# PASSIVE: HALLOWED GROUND
# Consecrates position for 4s while blocking
# ============================================================
var hallowed_ground_active = false
var hallowed_ground_timer = 0.0
const HALLOWED_GROUND_DURATION = 4.0
const HALLOWED_GROUND_RANGE = 3.5
var hallowed_ground_tick_timer = 0.0
const HALLOWED_GROUND_TICK_RATE = 1.0

# ============================================================
# PASSIVE: CONSECRATED BLADE
# Every sword strike applies Sear DOT (already on sword hit — tracked here)
# ============================================================
# Implemented directly in _on_sword_hit

# ============================================================
# PASSIVE: BULWARK
# 15% DR while blocking
# Tier 3: blocked damage builds Sanctity Meter
# ============================================================
const BULWARK_DR = 0.15

# ============================================================
# PASSIVE: HOLY PRESENCE AURA
# Scales with Sanctity tier
# Tier 1 — close range: allies 5% DR, opponents minor Sear
# Tier 2 — mid range: allies 10% DR + 5% atk boost, opponents Sear + 8% reduced dmg
# Tier 3 — full stage: allies 15% DR + 10% atk boost + 1% HP/3s, opponents Sear + Suppressed
# ============================================================
var aura_tick_timer = 0.0
const AURA_TICK_RATE = 3.0  # tick every 3s for regen

const AURA_RANGE_T1 = 3.5   # close
const AURA_RANGE_T2 = 7.0   # mid
const AURA_RANGE_T3 = 999.0 # full stage

# ============================================================
# READY
# ============================================================
func _ready():
	SPEED = 6.5
	DASH_SPEED = 15.0
	defense = 0.10
	model_node = $Model/Paladinv1
	var anim = $Model/Paladinv1.get_node_or_null("AnimationPlayer")
	if anim:
		anim_player = anim
		anim_player.play("idle")
		print("Paladin ready — animations: ", anim_player.get_animation_list())
	else:
		print("No AnimationPlayer found in Paladin model")

# ============================================================
# MAIN LOOP
# ============================================================
func _physics_process(delta):
	super(delta)
	handle_paladin_abilities()
	handle_paladin_cooldowns(delta)
	handle_combo_timer(delta)
	handle_cleric_cooldowns(delta)
	check_indomitable()
	handle_sanctity_decay(delta)
	handle_holy_presence_aura(delta)
	handle_hallowed_ground(delta)
	handle_divine_surge(delta)
	handle_blocking_passives(delta)

# ============================================================
# COOLDOWN HANDLERS
# ============================================================
func handle_paladin_cooldowns(delta):
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if retribution_cooldown > 0:
		retribution_cooldown -= delta
	if aegis_cooldown > 0:
		aegis_cooldown -= delta
	if crusade_cooldown > 0:
		crusade_cooldown -= delta
	if grab_active_cooldown > 0:
		grab_active_cooldown -= delta

func handle_combo_timer(delta):
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0

# ============================================================
# SANCTITY METER DECAY
# ============================================================
func handle_sanctity_decay(delta):
	var moving = abs(velocity.x) > 0.1 or abs(velocity.z) > 0.1
	var in_combat = attack_cooldown > 0 or retribution_cooldown > (RETRIBUTION_COOLDOWN_MAX - 0.5)
	if moving or in_combat or is_blocking:
		sanctity_idle_timer = 0.0
		return
	sanctity_idle_timer += delta
	if sanctity_idle_timer >= SANCTITY_DECAY_DELAY:
		primary_meter = max(primary_meter - SANCTITY_DECAY_RATE * delta, 0.0)

# ============================================================
# ABILITY INPUT HANDLER
# ============================================================
func handle_paladin_abilities():
	# Retribution is always available — mid-juggle, airborne, staggered
	if Input.is_action_just_pressed("ability_2") and not is_silenced:
		if not (Input.is_action_pressed("ability_1")):  # not V+B combo
			use_retribution()

	# Block inputs during stagger except Retribution above
	if is_staggered:
		return
	if is_crusading:
		return
	if is_blocking:
		return

	if Input.is_action_just_pressed("attack_1") and attack_cooldown <= 0:
		use_sword_strike()

	if Input.is_action_just_pressed("attack_2") and attack_cooldown <= 0:
		use_shield_slam()

	if Input.is_action_just_pressed("ability_1") and not is_silenced:
		if not Input.is_action_pressed("ability_2"):  # not V+B
			use_aegis()

	# V+B — Divine Word: Crusade
	if Input.is_action_pressed("ability_1") and Input.is_action_just_pressed("ability_2"):
		if not is_silenced:
			use_crusade()

# ============================================================
# X — SWORD STRIKE
# Wide arc. Sear DOT (Consecrated Blade). Builds Sanctity.
# ============================================================
func use_sword_strike():
	attack_cooldown = ATTACK_COOLDOWN_MAX
	combo_count += 1
	combo_timer = COMBO_WINDOW
	play_anim("attack_1")

	var offset = get_facing_offset(Vector3(0, 1.0, -1.8))
	print("Sword hitbox offset: ", offset, " facing_angle degrees: ", rad_to_deg(facing_angle))
	var hitbox = Area3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 3.0)
	shape.shape = box
	hitbox.add_child(shape)
	hitbox.position = offset
	add_child(hitbox)
	hitbox.body_entered.connect(_on_sword_hit)
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()

func _on_sword_hit(body):
	if body == self:
		return
	if not body.has_method("take_damage"):
		return
	var dmg = 80.0
	# +25% during Divine Surge
	dmg *= (1.0 + crusade_bonus_damage)
	body.take_damage(dmg, "physical", [])
	# CONSECRATED BLADE — always applies Sear on sword strike
	var sear_dmg = 5.0
	# Tier 2+: Sear 50% bonus vs dark energy classes
	if get_sanctity_tier() >= 2 and body.has_method("take_damage"):
		sear_dmg *= 1.5
	body.apply_sear(sear_dmg, 3.0)
	if not body.is_blocking:
		body.apply_stagger()
	primary_meter = min(primary_meter + 10.0, primary_meter_max)
	sanctity_idle_timer = 0.0
	print("Sword Strike — tier ", get_sanctity_tier(), " combo: ", combo_count)

# ============================================================
# C — SHIELD SLAM
# Basic: stagger. XXC: launch + Airborne.
# ============================================================
func use_shield_slam():
	attack_cooldown = ATTACK_COOLDOWN_MAX
	var is_launcher = combo_count >= 2
	combo_count = 0
	combo_timer = 0.0
	play_anim("attack_2")

	var hitbox = Area3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	shape.shape = box
	hitbox.add_child(shape)
	hitbox.position = get_facing_offset(Vector3(0, 1.0, -1.8))
	add_child(hitbox)

	if is_launcher:
		hitbox.body_entered.connect(_on_shield_slam_launch)
	else:
		hitbox.body_entered.connect(_on_shield_slam_basic)

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()

func _on_shield_slam_basic(body):
	if body == self:
		return
	if not body.has_method("take_damage"):
		return
	var dmg = 60.0 * (1.0 + crusade_bonus_damage)
	body.take_damage(dmg, "physical", [])
	if not body.is_blocking:
		body.apply_stagger()
	primary_meter = min(primary_meter + 8.0, primary_meter_max)
	sanctity_idle_timer = 0.0

func _on_shield_slam_launch(body):
	if body == self:
		return
	if not body.has_method("take_damage"):
		return
	var dmg = 90.0 * (1.0 + crusade_bonus_damage)
	body.take_damage(dmg, "physical", [])
	if not body.is_blocking:
		var dir = (body.global_position - global_position).normalized()
		body.velocity.x = dir.x * 3.0
		body.velocity.z = dir.z * 3.0
		body.velocity.y = 17.0
		body.apply_airborne()
		body.is_staggered = true
		body.stagger_timer = 1.8
	primary_meter = min(primary_meter + 15.0, primary_meter_max)
	sanctity_idle_timer = 0.0
	print("LAUNCHER! Enemy airborne!")

# ============================================================
# V — SACRED WORD: AEGIS
# Radiant pulse — heals all nearby allies, Shielded 2s.
# Removes 1 Corrode stack. Builds Sanctity.
# Tier 2: reflects 20% of next incoming hit back at attacker.
# Tier 3: Shielded duration increases to 4s.
# ============================================================
func use_aegis():
	if aegis_cooldown > 0:
		return
	aegis_cooldown = AEGIS_COOLDOWN_MAX
	play_anim("block")

	var tier = get_sanctity_tier()
	var heal_pct = 0.06 + (tier - 1) * 0.02  # 6% T1, 8% T2, 10% T3
	var shielded_duration = 4.0 if tier >= 3 else 2.0
	var aegis_range = AURA_RANGE_T1

	# Heal self
	health = min(health + max_health * heal_pct, max_health)
	apply_shielded(shielded_duration)
	remove_corrode_stack()
	primary_meter = min(primary_meter + 12.0, primary_meter_max)
	sanctity_idle_timer = 0.0

	# Heal and shield nearby allies
	var characters = get_tree().get_nodes_in_group("characters")
	for char in characters:
		if char == self:
			continue
		if not char.has_method("take_damage"):
			continue
		var dist = global_position.distance_to(char.global_position)
		if dist <= aegis_range:
			char.health = min(char.health + char.max_health * heal_pct, char.max_health)
			char.apply_shielded(shielded_duration)
			char.remove_corrode_stack()

	print("Sacred Word: Aegis — tier ", tier, " healed allies, Shielded ", shielded_duration, "s")

# ============================================================
# B — SACRED WORD: RETRIBUTION
# AoE burst. Usable ANY time (airborne, staggered, mid-juggle).
# 0.5s invincibility. Breaks opponent combos. Interrupt flagged.
# AoE scales with Sanctity tier.
# ============================================================
func use_retribution():
	if retribution_cooldown > 0:
		return

	retribution_cooldown = RETRIBUTION_COOLDOWN_MAX

	# Cancel stagger — can fire mid-juggle
	if is_staggered:
		is_staggered = false
		stagger_timer = 0.0

	is_invincible = true
	play_anim("attack_2")

	var tier = get_sanctity_tier()
	var aoe_radius = [3.0, 5.0, 8.0][tier - 1]

	var hitbox = Area3D.new()
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = aoe_radius
	shape.shape = sphere
	hitbox.add_child(shape)
	hitbox.position = Vector3.ZERO
	add_child(hitbox)
	hitbox.body_entered.connect(_on_retribution_hit.bind(tier))

	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()

	await get_tree().create_timer(0.2).timeout
	is_invincible = false

	primary_meter = min(primary_meter + 12.0, primary_meter_max)
	sanctity_idle_timer = 0.0
	print("Sacred Word: Retribution — tier ", tier, " radius ", aoe_radius)

func _on_retribution_hit(body, tier):
	if body == self:
		return
	if not body.has_method("take_damage"):
		return

	var dmg = 70.0 * (1.0 + crusade_bonus_damage)
	var flags = ["Interrupt", "Stun"]

	# Tier 2+: bonus vs dark energy + knockback
	if tier >= 2:
		var sear_dmg = 8.0 * 1.5 if body.has_method("take_damage") else 8.0
		body.apply_sear(sear_dmg, 3.0)
		var dir = (body.global_position - global_position).normalized()
		body.apply_knockback(dir, 6.0)

	# Tier 3: Suppressed 1.5s, full Sear damage
	if tier >= 3:
		body.apply_suppressed(1.5)

	# Corrode carriers: Sear ticks deal double
	if body.corrode_stacks > 0:
		body.sear_damage *= 2.0

	body.take_damage(dmg, "magic", flags)

	# Allies in AoE get brief Shielded
	_apply_retribution_ally_shield()

	print("Retribution hit — tier ", tier, " enemy HP: ", body.health)

func _apply_retribution_ally_shield():
	var characters = get_tree().get_nodes_in_group("characters")
	var tier = get_sanctity_tier()
	var radius = [3.0, 5.0, 8.0][tier - 1]
	for char in characters:
		if char == self:
			continue
		if not char.has_method("apply_shielded"):
			continue
		# Only allies — in a real game check team; here skip enemy (cpu_opponent group)
		if char.is_in_group("enemies"):
			continue
		var dist = global_position.distance_to(char.global_position)
		if dist <= radius:
			char.apply_shielded(1.0)

# ============================================================
# V + B — DIVINE WORD: CRUSADE (Ultimate)
# 1.5s telegraph (Charged, Interruptible).
# Charge forward shield-first. Unstoppable during charge.
# Divine Surge 8s after impact. Sacred Verdict finale.
# ============================================================
func use_crusade():
	if crusade_cooldown > 0:
		return
	if primary_meter < primary_meter_max:
		print("Crusade — meter not full: ", primary_meter)
		return

	crusade_cooldown = CRUSADE_COOLDOWN_MAX
	is_powered = true
	is_crusading = true
	is_charged = true
	play_anim("crusade")
	print("Divine Word: Crusade — CHARGING")

	# 1.5s telegraph — can be Interrupted
	await get_tree().create_timer(1.5).timeout

	if is_interrupted:
		# Cancelled — reset
		is_crusading = false
		is_powered = false
		is_charged = false
		primary_meter = 30.0  # ring-out style partial reset on cancel
		print("Crusade INTERRUPTED during telegraph")
		return

	is_charged = false
	is_cc_immune = true  # unstoppable during charge

	# --- CHARGE FORWARD ---
	var charge_duration = 0.6
	var charge_dir = -global_transform.basis.z  # facing direction
	charge_dir.y = 0
	charge_dir = charge_dir.normalized()

	var charge_timer_local = 0.0
	var hit_targets = []

	var hitbox = Area3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, 2.5)
	shape.shape = box
	hitbox.add_child(shape)
	hitbox.position = Vector3(0, 1.0, -1.5)
	add_child(hitbox)
	hitbox.body_entered.connect(_on_crusade_hit.bind(hit_targets))

	# Drive character forward during charge
	while charge_timer_local < charge_duration:
		velocity.x = charge_dir.x * 20.0
		velocity.z = charge_dir.z * 20.0
		charge_timer_local += get_physics_process_delta_time()
		await get_tree().process_frame

	velocity.x = 0
	velocity.z = 0
	if is_instance_valid(hitbox):
		hitbox.queue_free()

	is_cc_immune = false

	# --- DIVINE SURGE (8s) ---
	divine_surge_timer = DIVINE_SURGE_DURATION
	crusade_bonus_damage = 0.25  # +25% all damage during surge
	print("Divine Surge active — 8 seconds")
	_apply_divine_surge_to_allies()

	# --- SACRED VERDICT after 8s ---
	await get_tree().create_timer(DIVINE_SURGE_DURATION).timeout
	use_sacred_verdict()

func _on_crusade_hit(body, hit_targets):
	if body == self:
		return
	if not body.has_method("take_damage"):
		return
	if body in hit_targets:
		return
	hit_targets.append(body)

	var dmg = 120.0  # charge impact
	var is_dark = body.is_powered  # approximation for dark energy class check
	if is_dark:
		dmg *= 1.30

	body.take_damage(dmg, "physical", ["Interrupt"])
	body.apply_airborne()
	body.apply_sear(10.0, 4.0)
	body.apply_suppressed(3.0)
	print("Crusade charge HIT — dmg: ", dmg, " enemy HP: ", body.health)

func _apply_divine_surge_to_allies():
	var characters = get_tree().get_nodes_in_group("characters")
	for char in characters:
		if char == self:
			continue
		if char.is_in_group("enemies"):
			continue
		if not char.has_method("apply_shielded"):
			continue
		# Allies get: 20% attack boost representation as a shield window + regen
		# Full stat buffs require a buff system — applying available equivalents
		char.apply_shielded(2.0)
		print("Divine Surge applied to ally: ", char.name)

func use_sacred_verdict():
	print("Sacred Verdict!")
	var hitbox = Area3D.new()
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 9.0  # full stage range
	shape.shape = sphere
	hitbox.add_child(shape)
	hitbox.position = Vector3.ZERO
	add_child(hitbox)
	hitbox.body_entered.connect(_on_sacred_verdict_hit)

	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()

	# Allies near Paladin get Shielded + bonus window
	_apply_verdict_ally_buff()

	# End powered state and clean up
	crusade_bonus_damage = 0.0
	is_powered = false
	is_crusading = false
	primary_meter = 30.0  # resets to 30% after ultimate

	# 4s recovery window — reduced movement
	SPEED = 4.0
	await get_tree().create_timer(4.0).timeout
	SPEED = 6.5
	print("Crusade ended — recovery complete")

func _on_sacred_verdict_hit(body):
	if body == self:
		return
	if not body.has_method("take_damage"):
		return
	body.take_damage(80.0, "magic", ["Interrupt"])
	body.apply_airborne()
	body.apply_suppressed(2.0)
	print("Sacred Verdict hit — enemy HP: ", body.health)

func _apply_verdict_ally_buff():
	var characters = get_tree().get_nodes_in_group("characters")
	for char in characters:
		if char == self:
			continue
		if char.is_in_group("enemies"):
			continue
		if not char.has_method("apply_shielded"):
			continue
		char.apply_shielded(3.0)

func handle_divine_surge(delta):
	if divine_surge_timer > 0:
		divine_surge_timer -= delta
		if divine_surge_timer <= 0:
			crusade_bonus_damage = 0.0

# ============================================================
# X + C — HOLY SLAM (Grab override)
# Consecrates landing point. Sear DOT on impact.
# Builds Sanctity meter.
# ============================================================
func spawn_grab_hitbox():
	if grab_active_cooldown > 0:
		return
	if is_suppressed:
		return
	grab_active_cooldown = GRAB_ACTIVE_COOLDOWN_MAX

	var hitbox = Area3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.5, 2.0, 1.5)
	shape.shape = box
	hitbox.add_child(shape)
	hitbox.position = get_facing_offset(Vector3(0, 1.0, -1.8))
	add_child(hitbox)
	hitbox.body_entered.connect(_on_holy_slam_grab)

	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()

func _on_holy_slam_grab(body):
	if body == self:
		return
	if not body.has_method("take_damage"):
		return
	if body.is_shielded:
		return
	if body.is_airborne:
		return

	# Slam — throw downward
	body.take_damage(70.0, "physical", [])
	body.velocity.y = -8.0
	body.apply_airborne()
	body.apply_sear(12.0, 4.0)

	# Consecrate landing point — spawn zone at body position
	_spawn_consecrated_zone(body.global_position)

	primary_meter = min(primary_meter + 10.0, primary_meter_max)
	sanctity_idle_timer = 0.0
	print("Holy Slam — consecrated landing point!")

func _spawn_consecrated_zone(pos: Vector3):
	# Hallowed Ground zone at slam landing point — 4s
	var zone = Area3D.new()
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = HALLOWED_GROUND_RANGE
	shape.shape = sphere
	zone.add_child(shape)
	zone.global_position = pos
	get_tree().current_scene.add_child(zone)
	zone.body_entered.connect(_on_consecrated_zone_tick)

	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(zone):
		zone.queue_free()

func _on_consecrated_zone_tick(body):
	if not body.has_method("take_damage"):
		return
	if body == self:
		# Heal self if standing in zone
		health = min(health + max_health * 0.005, max_health)
		return
	if body.is_in_group("enemies"):
		body.apply_sear(4.0, 2.0)

# ============================================================
# PASSIVE: HOLY PRESENCE AURA
# Ticks every 3s for regen, every frame for DR (handled via is_in_range checks)
# ============================================================
func handle_holy_presence_aura(delta):
	if is_suppressed:
		return
	aura_tick_timer += delta
	var tier = get_sanctity_tier()
	var aura_range = _get_aura_range(tier)

	if aura_tick_timer >= AURA_TICK_RATE:
		aura_tick_timer = 0.0
		var characters = get_tree().get_nodes_in_group("characters")
		for char in characters:
			var dist = global_position.distance_to(char.global_position)
			if dist > aura_range:
				continue
			if char == self:
				continue

			if char.is_in_group("enemies"):
				# Opponents: Sear DOT passive
				char.apply_sear(3.0, 1.5)
				# Tier 3: Suppressed (capped at 1s max per design)
				if tier >= 3:
					char.apply_suppressed(1.0)
			else:
				# Allies: HP regen at tier 3 (1% every 3s)
				if tier >= 3:
					char.health = min(char.health + char.max_health * 0.01, char.max_health)

func _get_aura_range(tier: int) -> float:
	match tier:
		1: return AURA_RANGE_T1
		2: return AURA_RANGE_T2
		3: return AURA_RANGE_T3
		_: return AURA_RANGE_T1

# ============================================================
# PASSIVE: HALLOWED GROUND
# Consecrates position for 4s while blocking
# ============================================================
func handle_hallowed_ground(delta):
	if is_blocking and not is_suppressed:
		if not hallowed_ground_active:
			hallowed_ground_active = true
			hallowed_ground_timer = HALLOWED_GROUND_DURATION
		else:
			# Refresh while still blocking
			hallowed_ground_timer = HALLOWED_GROUND_DURATION

	if hallowed_ground_active:
		hallowed_ground_timer -= delta
		if hallowed_ground_timer <= 0:
			hallowed_ground_active = false
			return
		hallowed_ground_tick_timer -= delta
		if hallowed_ground_tick_timer <= 0:
			hallowed_ground_tick_timer = HALLOWED_GROUND_TICK_RATE
			_tick_hallowed_ground()

func _tick_hallowed_ground():
	var characters = get_tree().get_nodes_in_group("characters")
	for char in characters:
		var dist = global_position.distance_to(char.global_position)
		if dist > HALLOWED_GROUND_RANGE:
			continue
		if char == self:
			# Self heal in zone
			health = min(health + max_health * 0.005, max_health)
			continue
		if char.is_in_group("enemies"):
			char.apply_sear(3.0, 1.5)
		else:
			char.health = min(char.health + char.max_health * 0.02, char.max_health)

# ============================================================
# PASSIVE: BULWARK + DIVINE RETALIATION
# Called while blocking
# ============================================================
func handle_blocking_passives(delta):
	if divine_retaliation_timer > 0:
		divine_retaliation_timer -= delta
		if divine_retaliation_timer <= 0:
			divine_retaliation_stacks = 0

# Called from take_damage override when blocking
func on_blocked_hit():
	# BULWARK — DR applied in take_damage override below
	# DIVINE RETALIATION — allies get +3% attack boost
	divine_retaliation_stacks = min(divine_retaliation_stacks + 1, DIVINE_RETALIATION_MAX_STACKS)
	divine_retaliation_timer = DIVINE_RETALIATION_DURATION
	_apply_divine_retaliation_to_allies()

	# Tier 3: blocked damage builds Sanctity Meter
	if get_sanctity_tier() >= 3:
		primary_meter = min(primary_meter + 5.0, primary_meter_max)
		sanctity_idle_timer = 0.0

	print("Bulwark — blocked! Retaliation stacks: ", divine_retaliation_stacks)

func _apply_divine_retaliation_to_allies():
	var characters = get_tree().get_nodes_in_group("characters")
	for char in characters:
		if char == self:
			continue
		if char.is_in_group("enemies"):
			continue
		var dist = global_position.distance_to(char.global_position)
		if dist <= _get_aura_range(get_sanctity_tier()):
			# Represent the attack boost as a brief damage buff — store on char if system exists
			# For now: heal small amount as placeholder until full buff system is built
			char.health = min(char.health + 5.0, char.max_health)

# ============================================================
# TAKE DAMAGE OVERRIDE
# Applies Bulwark DR on top of base block reduction
# ============================================================
func take_damage(amount, damage_type = "physical", flags = []):
	if is_blocking and not ("GuardBypass" in flags) and not ("Burn" in flags):
		# BULWARK: additional 15% DR on top of base 80% block
		amount *= (1.0 - BULWARK_DR)
		on_blocked_hit()

	# Sanctity meter builds from taking damage
	primary_meter = min(primary_meter + 3.0, primary_meter_max)
	sanctity_idle_timer = 0.0

	super(amount, damage_type, flags)

# ============================================================
# INDOMITABLE PASSIVE
# Once per match at 15% HP:
# 3s invincibility, CC immune, Shielded, aura doubles
# ============================================================
func check_indomitable():
	if indomitable_used:
		return
	if health < max_health * 0.15:
		_trigger_indomitable()

func _trigger_indomitable():
	indomitable_used = true
	is_cc_immune = true
	is_staggered = false
	stagger_timer = 0.0
	is_invincible = true
	apply_shielded(3.0)
	primary_meter = min(primary_meter + 20.0, primary_meter_max)
	print("INDOMITABLE — 3s invincibility!")
	await get_tree().create_timer(3.0).timeout
	is_cc_immune = false
	is_invincible = false
	print("Indomitable ended")
