extends CanvasLayer

var health_bars = {}

func _ready():
	# Find all characters in scene and create bars for them
	await get_tree().process_frame
	setup_health_bars()

func setup_health_bars():
	# Get all CharacterBody3D nodes in scene
	var characters = get_tree().get_nodes_in_group("characters")
	
	var bar_index = 0
	for character in characters:
		create_health_bar(character, bar_index)
		bar_index += 1

func create_health_bar(character, index):
	# Create a container for this character's bars
	var container = VBoxContainer.new()
	container.name = character.name + "_UI"
	$Control.add_child(container)
	
	# Position — left side for index 0, right side for index 1+
	var bar_width = 500
	var bar_height = 35
	var margin = 20
	
	if index == 0:
		container.position = Vector2(20, 620)
	else:
		container.position = Vector2(760, 620)
		
	
	# Character name label
	var name_label = Label.new()
	name_label.text = character.name.to_upper()
	name_label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(name_label)
	
	# Health bar
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.min_value = 0
	health_bar.max_value = character.max_health
	health_bar.value = character.health
	health_bar.custom_minimum_size = Vector2(bar_width, bar_height)
	health_bar.show_percentage = false
	
	# Color — green for player index 0, red for others
	var style = StyleBoxFlat.new()
	if index == 0:
		style.bg_color = Color("#00cc66")
	else:
		style.bg_color = Color("#cc2200")
	health_bar.add_theme_stylebox_override("fill", style)
	
	# Dark background
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#1a1a1a")
	health_bar.add_theme_stylebox_override("background", bg_style)
	
	container.add_child(health_bar)
	
	# Sanctity/meter bar if character has one
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
	
	# Store reference for updates
	health_bars[character.name] = {
		"character": character,
		"health_bar": health_bar,
		"container": container
	}

func _process(delta):
	# Update all bars every frame
	for char_name in health_bars:
		var data = health_bars[char_name]
		var character = data["character"]
		var bar = data["health_bar"]
		
		if is_instance_valid(character):
			bar.value = character.health
			
			# Update meter bar if exists
			var meter_bar = data["container"].get_node_or_null("MeterBar")
			if meter_bar and "primary_meter" in character:
				meter_bar.value = character.primary_meter
