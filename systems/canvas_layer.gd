extends CanvasLayer

var health_bars = {}
var ability_panels = {}  # character name → array of slot dicts

const PASSIVE_SIZE = Vector2(48, 48)
const ABILITY_SIZE = Vector2(72, 72)
const ULTIMATE_SIZE = Vector2(90, 90)
const SLOT_MARGIN = 8
const RIGHT_MARGIN = 16
const BOTTOM_MARGIN = 120

const COLOR_CDR_OVERLAY = Color(0.0, 0.0, 0.0, 0.75)
const COLOR_PASSIVE_BG = Color(0.15, 0.12, 0.05, 0.9)
const COLOR_ABILITY_BG = Color(0.1, 0.08, 0.02, 0.95)
const COLOR_ULTIMATE_BG = Color(0.2, 0.15, 0.0, 0.95)
const COLOR_BORDER = Color(0.8, 0.65, 0.1, 1.0)
const COLOR_BORDER_ULTIMATE = Color(1.0, 0.85, 0.2, 1.0)
const COLOR_READY = Color(1.0, 0.9, 0.3, 1.0)
const COLOR_ON_CDR = Color(0.5, 0.4, 0.1, 1.0)

func _ready():
	await get_tree().process_frame
	setup_health_bars()
	setup_ability_panels()

func setup_health_bars():
	var characters = get_tree().get_nodes_in_group("characters")
	var bar_index = 0
	for character in characters:
		create_health_bar(character, bar_index)
		bar_index += 1

func create_health_bar(character, index):
	var container = VBoxContainer.new()
	container.name = character.name + "_UI"
	$Control.add_child(container)

	var bar_width = 500
	var bar_height = 35

	if index == 0:
		container.position = Vector2(20, 620)
	else:
		container.position = Vector2(760, 620)

	var name_label = Label.new()
	name_label.text = character.name.to_upper()
	name_label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(name_label)

	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.min_value = 0
	health_bar.max_value = character.max_health
	health_bar.value = character.health
	health_bar.custom_minimum_size = Vector2(bar_width, bar_height)
	health_bar.show_percentage = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#00cc66") if index == 0 else Color("#cc2200")
	health_bar.add_theme_stylebox_override("fill", style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#1a1a1a")
	health_bar.add_theme_stylebox_override("background", bg_style)
	container.add_child(health_bar)

	if "primary_meter" in character:
		var meter_bar = ProgressBar.new()
		meter_bar.name = "MeterBar"
		meter_bar.min_value = 0
		meter_bar.max_value = character.primary_meter_max
		meter_bar.value = character.primary_meter
		meter_bar.custom_minimum_size = Vector2(bar_width, 16)
		meter_bar.show_percentage = false

		var meter_style = StyleBoxFlat.new()
		meter_style.bg_color = Color("#ffd700")
		meter_bar.add_theme_stylebox_override("fill", meter_style)

		var meter_bg = StyleBoxFlat.new()
		meter_bg.bg_color = Color("#1a1a1a")
		meter_bar.add_theme_stylebox_override("background", meter_bg)
		container.add_child(meter_bar)

	health_bars[character.name] = {
		"character": character,
		"health_bar": health_bar,
		"container": container
	}

# ============================================================
# ABILITY PANELS — universal, driven by get_ability_data()
# Only builds for characters that return ability data
# ============================================================
func setup_ability_panels():
	var characters = get_tree().get_nodes_in_group("characters")
	var viewport_size = get_viewport().get_visible_rect().size

	for character in characters:
		if not character.has_method("get_ability_data"):
			continue
		var ability_data = character.get_ability_data()
		if ability_data.is_empty():
			continue
		build_ability_panel(character, ability_data, viewport_size)

func build_ability_panel(character, abilities, viewport_size):
	var slots = []
	var current_y = viewport_size.y - BOTTOM_MARGIN

	for ability in abilities:
		var slot_size = PASSIVE_SIZE
		if ability["type"] == "ability":
			slot_size = ABILITY_SIZE
		elif ability["type"] == "ultimate":
			slot_size = ULTIMATE_SIZE

		current_y -= slot_size.y + SLOT_MARGIN
		var slot_x = viewport_size.x - slot_size.x - RIGHT_MARGIN

		# Background
		var panel = ColorRect.new()
		match ability["type"]:
			"passive":  panel.color = COLOR_PASSIVE_BG
			"ability":  panel.color = COLOR_ABILITY_BG
			"ultimate": panel.color = COLOR_ULTIMATE_BG
		panel.size = slot_size
		panel.position = Vector2(slot_x, current_y)
		$Control.add_child(panel)

		# Border
		var border_color = COLOR_BORDER_ULTIMATE if ability["type"] == "ultimate" else COLOR_BORDER
		_add_border(slot_x, current_y, slot_size, border_color)

		# Icon
		var icon_rect = TextureRect.new()
		if ResourceLoader.exists(ability["icon"]):
			icon_rect.texture = load(ability["icon"])
		icon_rect.size = slot_size - Vector2(4, 4)
		icon_rect.position = Vector2(slot_x + 2, current_y + 2)
		icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
		$Control.add_child(icon_rect)

		# CDR overlay
		var overlay = ColorRect.new()
		overlay.color = COLOR_CDR_OVERLAY
		overlay.size = slot_size - Vector2(4, 4)
		overlay.position = Vector2(slot_x + 2, current_y + 2)
		overlay.visible = false
		$Control.add_child(overlay)

		# Key label
		var key_label = Label.new()
		key_label.text = ability.get("key", "")
		key_label.position = Vector2(slot_x + 3, current_y + 3)
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", COLOR_READY)
		$Control.add_child(key_label)

		# Cooldown timer
		var timer_label = Label.new()
		timer_label.text = ""
		timer_label.position = Vector2(slot_x + slot_size.x * 0.25, current_y + slot_size.y * 0.35)
		timer_label.add_theme_font_size_override("font_size", 14 if ability["type"] == "ultimate" else 11)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.visible = false
		$Control.add_child(timer_label)

		# Ability name
		var name_label = Label.new()
		name_label.text = ability["name"]
		name_label.position = Vector2(slot_x - 10, current_y + slot_size.y + 1)
		name_label.add_theme_font_size_override("font_size", 8)
		name_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0.9))
		$Control.add_child(name_label)

		slots.append({
			"overlay": overlay,
			"timer_label": timer_label,
			"key_label": key_label,
			"data": ability
		})

	ability_panels[character.name] = {
		"character": character,
		"slots": slots
	}

func _add_border(x, y, size, color):
	var thickness = 2
	for i in range(4):
		var b = ColorRect.new()
		b.color = color
		match i:
			0: b.size = Vector2(size.x, thickness); b.position = Vector2(x, y)
			1: b.size = Vector2(size.x, thickness); b.position = Vector2(x, y + size.y - thickness)
			2: b.size = Vector2(thickness, size.y); b.position = Vector2(x, y)
			3: b.size = Vector2(thickness, size.y); b.position = Vector2(x + size.x - thickness, y)
		$Control.add_child(b)

# ============================================================
# UPDATE
# ============================================================
func _process(_delta):
	update_health_bars()
	update_ability_cooldowns()

func update_health_bars():
	for char_name in health_bars:
		var data = health_bars[char_name]
		var character = data["character"]
		var bar = data["health_bar"]

		if is_instance_valid(character):
			bar.value = character.health
			var meter_bar = data["container"].get_node_or_null("MeterBar")
			if meter_bar and "primary_meter" in character:
				meter_bar.value = character.primary_meter

func update_ability_cooldowns():
	for char_name in ability_panels:
		var panel_data = ability_panels[char_name]
		var character = panel_data["character"]
		if not is_instance_valid(character):
			continue

		for slot in panel_data["slots"]:
			var data = slot["data"]

			# Passive — check boolean used flag
			if data["type"] == "passive":
				var cdr_var = data.get("cooldown_var", "")
				if cdr_var != "":
					var val = character.get(cdr_var)
					if val != null and val == true:
						slot["overlay"].visible = true
					else:
						slot["overlay"].visible = false
				continue

			# Active ability — check cooldown float
			var cdr_var = data.get("cooldown_var", "")
			if cdr_var == "":
				continue

			var cdr_val = character.get(cdr_var)
			if cdr_val == null:
				continue

			# Special — Crusade needs full meter too
			var meter_not_full = (data["name"] == "Crusade" and
				character.primary_meter < character.primary_meter_max)

			if cdr_val > 0:
				slot["overlay"].visible = true
				slot["timer_label"].visible = true
				slot["timer_label"].text = str(int(ceil(cdr_val)))
				slot["key_label"].add_theme_color_override("font_color", COLOR_ON_CDR)
			elif meter_not_full:
				slot["overlay"].visible = true
				slot["timer_label"].visible = true
				slot["timer_label"].text = str(int(character.primary_meter)) + "%"
				slot["key_label"].add_theme_color_override("font_color", COLOR_ON_CDR)
			else:
				slot["overlay"].visible = false
				slot["timer_label"].visible = false
				slot["key_label"].add_theme_color_override("font_color", COLOR_READY)
