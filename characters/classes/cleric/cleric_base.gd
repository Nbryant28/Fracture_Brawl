extends "res://characters/base_character.gd"

# ============================================================
# CLERIC BASE
# All three subclasses inherit from this:
# Archangel, ArchCleric, Paladin
# ============================================================

# ============================================================
# CLERIC BASE STATS
# ============================================================
# Set in _ready of each subclass — these are defaults
# Paladin:    HP 1000, defense 0.10, SPEED 6.5
# Archangel:  HP 1000, defense 0.15, SPEED 6.0
# ArchCleric: HP 900,  defense 0.08, SPEED 6.0

# ============================================================
# DIVINE PRESENCE PASSIVE
# Allies within close range: 1% HP every 5s
# Corrode tick rate slowed 20% near Cleric
# ============================================================
var divine_presence_timer = 0.0
const DIVINE_PRESENCE_TICK = 5.0
const DIVINE_PRESENCE_HEAL = 0.01
const DIVINE_PRESENCE_RANGE = 5.0
const CORRODE_SLOW_RATE = 0.20

# ============================================================
# MAIN LOOP
# ============================================================
func _physics_process(delta):
	super(delta)
	handle_divine_presence(delta)

# ============================================================
# DIVINE PRESENCE
# ============================================================
func handle_divine_presence(delta):
	if is_suppressed:
		return
	divine_presence_timer += delta
	if divine_presence_timer >= DIVINE_PRESENCE_TICK:
		divine_presence_timer = 0.0
		heal_nearby_allies()

func heal_nearby_allies():
	var allies = get_tree().get_nodes_in_group("characters")
	for ally in allies:
		if ally == self:
			continue
		if not ally.has_method("take_damage"):
			continue
		var distance = global_position.distance_to(ally.global_position)
		if distance <= DIVINE_PRESENCE_RANGE:
			var heal_amount = ally.max_health * DIVINE_PRESENCE_HEAL
			ally.health = min(ally.health + heal_amount, ally.max_health)

# ============================================================
# V — HOLY WORD: MEND
# Heals targeted ally or self
# Fast cast. Moderate heal. Applies brief Shielded.
# Removes 1 Corrode stack on healed target.
# ============================================================
var mend_cooldown = 0.0
const MEND_COOLDOWN_MAX = 3.0
const MEND_HEAL_PERCENT = 0.08

func use_holy_word_mend():
	if mend_cooldown > 0:
		return
	if is_silenced:
		return
	mend_cooldown = MEND_COOLDOWN_MAX

	# Find nearest ally to heal
	var target = find_nearest_ally()
	if target == null:
		target = self

	var heal_amount = target.max_health * MEND_HEAL_PERCENT
	target.health = min(target.health + heal_amount, target.max_health)
	target.apply_shielded(2.0)
	target.remove_corrode_stack()

	print("Holy Word: Mend — healed ", target.name, " for ", heal_amount)

func find_nearest_ally():
	var allies = get_tree().get_nodes_in_group("characters")
	var nearest = null
	var nearest_dist = INF
	for ally in allies:
		if ally == self:
			continue
		if not ally.has_method("take_damage"):
			continue
		var dist = global_position.distance_to(ally.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = ally
	return nearest

# ============================================================
# B — HOLY WORD: WRATH
# Concentrated radiant energy strike
# Applies Sear DOT. 50% bonus vs Corrode carriers.
# Interrupt flagged. Brief Suppressed vs dark Powered states.
# ============================================================
var wrath_cooldown = 0.0
const WRATH_COOLDOWN_MAX = 4.0
const WRATH_DAMAGE = 70.0
const WRATH_SEAR_BASE_DAMAGE = 6.0
const WRATH_SEAR_DURATION = 3.0

func use_holy_word_wrath():
	if wrath_cooldown > 0:
		return
	if is_silenced:
		return
	wrath_cooldown = WRATH_COOLDOWN_MAX
	spawn_hitbox(Vector3(2.0, 2.0, 4.0), Vector3(0, 1.0, -2.0), 0.2, _on_wrath_hit)
	print("Holy Word: Wrath!")

func _on_wrath_hit(body):
	if body == self:
		return
	if not body.has_method("take_damage"):
		return

	var damage = WRATH_DAMAGE
	var wrath_sear = WRATH_SEAR_BASE_DAMAGE

	# 50% bonus vs Corrode carriers
	if body.corrode_stacks > 0:
		wrath_sear *= 1.5

	body.take_damage(damage, "magic", ["Interrupt"])
	body.apply_sear(wrath_sear, WRATH_SEAR_DURATION)

	# Brief Suppressed vs dark Powered states
	if body.is_powered:
		body.apply_suppressed(1.0)

	print("Holy Word: Wrath hit! Enemy HP: ", body.health)

# ============================================================
# COOLDOWN HANDLER — call from subclass _physics_process
# ============================================================
func handle_cleric_cooldowns(delta):
	if mend_cooldown > 0:
		mend_cooldown -= delta
	if wrath_cooldown > 0:
		wrath_cooldown -= delta
