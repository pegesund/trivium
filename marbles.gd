extends Node2D

# This script will handle the creation and management of marble sprites

# Scale factor for the marble (reduce this to make the marble smaller)
var marble_scale = 0.165  # 16.5% of original size
var pit_texture = null

# Variables for drag and drop functionality
var dragging_marble = null
var original_marble_position = Vector2.ZERO
var hover_indicator = null
var hover_pit = null  # Reference to the pit we're hovering over

# Store the last valid grid position for placement
var last_valid_grid_position = null

# References to other nodes
@onready var game_manager = get_node("../GameManager")
@onready var background_node = get_node("../Background")

func _ready():
	# Load the pit texture once
	pit_texture = load("res://assets/sprites/marbles/pit.png")
	if pit_texture == null:
		print("ERROR: Could not load pit texture!")
		return
		
	# Get the viewport size to center the marble
	var viewport_size = get_viewport_rect().size
	var _center_position = viewport_size / 2
	
	# Create pits at all white circle positions
	create_pits_at_all_grid_points()
	
	# Create hover indicator for placement feedback
	hover_indicator = create_hover_indicator()

func _process(_delta):
	# Update the dragging marble position if we're dragging
	if dragging_marble:
		dragging_marble.global_position = get_global_mouse_position()
		
		# Update the hover indicator position
		update_hover_indicator_position()

func _input(event):
	if game_manager.game_started:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					# Start dragging
					var marble = find_marble_under_mouse(get_global_mouse_position())
					if marble != null and game_manager.can_player_move_marble(marble):
						start_dragging(marble)
				else:
					# Stop dragging
					if dragging_marble != null:
						stop_dragging()
		
		elif event is InputEventMouseMotion:
			# Update dragging position
			if dragging_marble != null:
				update_dragging_position(get_global_mouse_position())

# Function to create pits at all white circle positions in the background
func create_pits_at_all_grid_points():
	# Get the Background node to access its grid
	var background = get_node("../Background")
	
	# Get all intersection points
	var all_intersections = background.get_all_intersection_points()
	
	# Create a separate node for pits to ensure they're rendered first
	var pits_node = Node2D.new()
	pits_node.name = "Pits"
	pits_node.z_index = 5  # Set z-index to be above the background but below marbles
	add_child(pits_node)
	move_child(pits_node, 0)  # Move to first position
	
	var pit_count = 0
	# Create pits at all inner intersection points (white circles)
	for intersection in all_intersections:
		if not intersection["is_outer"]:  # Only create pits at inner points (white circles)
			create_pit(intersection["position"], pits_node)
			pit_count += 1
	
	print("Created ", pit_count, " pits")

# Function to create a pit at a specific position
func create_pit(pos, parent_node):
	# Create a Sprite2D for the pit
	var pit = Sprite2D.new()
	pit.position = pos
	pit.texture = pit_texture
	pit.scale = Vector2(marble_scale, marble_scale)  # Use the same scale as marbles
	pit.name = "Pit_" + str(pos.x) + "_" + str(pos.y)
	pit.z_index = 5  # Set z-index to be above the background but below marbles
	
	# Add the pit to the pits node
	parent_node.add_child(pit)
	
	return pit

# Function to create a marble with multiple layers at a specific position
func create_marble(marble_color, pos, is_small = false):
	# Create the main container node for this marble
	var marble_container = Node2D.new()
	marble_container.position = pos
	marble_container.name = marble_color.capitalize() + ("SmallMarble" if is_small else "Marble")
	
	# Set z-index for the entire container
	marble_container.z_index = 10
	
	add_child(marble_container)
	
	# Scale factor - smaller for the small marble
	var scale_factor = marble_scale * (0.6 if is_small else 1.0)
	
	# Add the shadow layer (bottom layer)
	var shadow_layer = Sprite2D.new()
	shadow_layer.texture = load("res://assets/sprites/marbles/" + marble_color + "/shadow.png")
	shadow_layer.scale = Vector2(scale_factor, scale_factor)  # Scale down
	marble_container.add_child(shadow_layer)
	
	# Add the sphere layer (main marble)
	var sphere_layer = Sprite2D.new()
	sphere_layer.name = "SphereLayer"  # Named for easier access
	sphere_layer.texture = load("res://assets/sprites/marbles/" + marble_color + "/sphere.png")
	sphere_layer.scale = Vector2(scale_factor, scale_factor)  # Scale down
	marble_container.add_child(sphere_layer)
	
	# Add the glow layer
	var glow_layer = Sprite2D.new()
	glow_layer.texture = load("res://assets/sprites/marbles/" + marble_color + "/glow.png")
	glow_layer.scale = Vector2(scale_factor, scale_factor)  # Scale down
	marble_container.add_child(glow_layer)
	
	# Add the 90 degree reflection layer (top layer)
	var reflection_layer = Sprite2D.new()
	reflection_layer.texture = load("res://assets/sprites/marbles/" + marble_color + "/90.png")
	reflection_layer.scale = Vector2(scale_factor, scale_factor)  # Scale down
	marble_container.add_child(reflection_layer)
	
	# Make the marble interactive by default
	make_marble_interactive(marble_container)
	
	return marble_container

# Function to add a marble at a specific triangular position
func add_marble_at_triangular_position(marble_color: String, row: int, pos: int, is_small = false):
	# Get the pit at this position
	var pit = game_manager.get_pit_at_triangular_position(row, pos)
	if pit:
		return create_marble(marble_color, pit.position, is_small)
	else:
		return null

# Make a marble interactive (draggable)
func make_marble_interactive(marble: Node2D):
	# Add an Area2D for input detection
	var area = Area2D.new()
	area.name = "InteractionArea"
	marble.add_child(area)
	
	# Add a collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30  # Adjust based on your marble size
	collision.shape = shape
	area.add_child(collision)
	
	# Make the area pickable
	area.input_pickable = true
	
	# Connect the input event signal
	area.connect("input_event", Callable(self, "_on_marble_area_input_event").bind(marble))

# Handle input events on marble areas
func _on_marble_area_input_event(_viewport, event, _shape_idx, marble: Node2D):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				start_dragging(marble)
			else:
				# Stop dragging
				stop_dragging()

# Start dragging a marble
func start_dragging(marble: Node2D):
	# Check if this marble belongs to the current player
	if not game_manager.can_player_move_marble(marble):
		print("This marble does not belong to the current player")
		return
	
	# Store the original position in case we need to return it
	original_marble_position = marble.global_position
	
	# Set the dragging marble
	dragging_marble = marble
	
	# Create hover indicator if it doesn't exist
	if not hover_indicator:
		create_hover_indicator()
	
	# Show the hover indicator
	if hover_indicator:
		hover_indicator.visible = true

# Update the hover indicator position based on the closest valid pit
func update_hover_indicator_position():
	if dragging_marble == null or hover_indicator == null:
		return
	
	# Get the mouse position
	var mouse_pos = get_global_mouse_position()
	
	# Find the closest pit (empty or not)
	var closest_pit = find_closest_pit(mouse_pos)
	hover_pit = closest_pit
	
	if closest_pit:
		# Update the hover indicator position
		hover_indicator.global_position = closest_pit.position
		
		# Check if the pit is empty and belongs to the current player
		var is_valid = closest_pit.is_empty()
		print("Hovering over pit at (", closest_pit.grid_y, ",", closest_pit.grid_x, ") - Empty: ", is_valid)
		
		# Set the indicator color based on validity
		var indicator_circle = hover_indicator.get_node("IndicatorCircle")
		if indicator_circle:
			if is_valid:
				# Green for valid placement
				indicator_circle.modulate = Color(0, 1, 0, 0.8)  # More opaque green
				print("Setting indicator to GREEN")
			else:
				# Red for invalid placement
				indicator_circle.modulate = Color(1, 0, 0, 0.8)  # More opaque red
				print("Setting indicator to RED")
		else:
			print("ERROR: IndicatorCircle node not found!")
		
		# Show the indicator
		hover_indicator.visible = true
		print("Hover indicator visible: ", hover_indicator.visible)
	else:
		# No valid pit found, hide the indicator
		hover_indicator.visible = false

# Find the closest pit to a world position (empty or not)
func find_closest_pit(world_pos: Vector2):
	var closest_pit = null
	var closest_distance = INF
	
	# Get all pits from the background (both empty and occupied)
	var all_pits = []
	for row in game_manager.background_node.pits:
		for pit in row:
			all_pits.append(pit)
	
	# Find the closest pit
	for pit in all_pits:
		var distance = pit.position.distance_to(world_pos)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_pit = pit
	
	# Only return if within a reasonable distance
	if closest_distance < 100:  # Threshold for detection
		return closest_pit
	
	return null

# Stop dragging and place the marble if valid
func stop_dragging():
	if dragging_marble and hover_indicator:
		# Check if we have a valid pit to place the marble in
		if hover_pit and hover_indicator.visible:
			var current_player = game_manager.get_current_player()
			
			# Check if the pit is empty
			if hover_pit.is_empty():
				# Place the marble at the pit's position
				dragging_marble.global_position = hover_pit.position
				
				# Update the pit with the marble and player
				if hover_pit.place_marble(current_player.id, dragging_marble):
					print("Placed ", current_player.color, " marble at triangular position (", 
						hover_pit.grid_y, ",", hover_pit.grid_x, ")")
					
					# Successfully placed, end player's turn
					game_manager.end_turn()
					
					# Reset dragging state
					dragging_marble = null
					hover_pit = null
					
					if hover_indicator:
						hover_indicator.visible = false
					return
			else:
				print("Cannot place marble - pit is already occupied")
		
		# If we reach here, placement failed or was invalid
		# Return the marble to its original position
		return_marble_to_original_position()
	
	# Reset dragging state
	dragging_marble = null
	hover_pit = null
	
	if hover_indicator:
		hover_indicator.visible = false

# Return the marble to its original position
func return_marble_to_original_position():
	if dragging_marble:
		# Animate the return to make it smoother
		var tween = create_tween()
		tween.tween_property(dragging_marble, "global_position", original_marble_position, 0.3)
		tween.play()
		print("Returned marble to original position")

# Create a hover indicator to show where the marble will be placed
func create_hover_indicator():
	print("Creating hover indicator...")
	
	# Create a container node
	hover_indicator = Node2D.new()
	hover_indicator.name = "HoverIndicator"
	hover_indicator.z_index = 20  # Make sure it's above everything
	add_child(hover_indicator)
	
	# Create a circle sprite for the indicator
	var indicator_circle = Sprite2D.new()
	indicator_circle.name = "IndicatorCircle"
	
	# Create a circle texture programmatically
	var image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))  # Transparent background
	
	# Draw a circle
	var center = Vector2(50, 50)
	var radius = 45
	var color = Color(1, 1, 1, 1)  # White circle, we'll tint it with modulate
	
	# Draw the circle
	for x in range(100):
		for y in range(100):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			if distance <= radius:  # Fill the entire circle
				image.set_pixel(x, y, color)
	
	# Create texture from image
	var texture = ImageTexture.create_from_image(image)
	indicator_circle.texture = texture
	
	indicator_circle.scale = Vector2(0.6, 0.6)  # Scale to appropriate size
	indicator_circle.modulate = Color(0, 1, 0, 0.8)  # More opaque green
	hover_indicator.add_child(indicator_circle)
	
	# Hide it initially
	hover_indicator.visible = false
	print("Hover indicator created with child: ", indicator_circle.name)
	
	return hover_indicator

# Find a marble under the mouse position
func find_marble_under_mouse(mouse_pos: Vector2) -> Node2D:
	# Check all marbles for all players
	for player in game_manager.players:
		for marble in player.large_marbles:
			# Simple distance check
			var distance = mouse_pos.distance_to(marble.global_position)
			if distance <= 50:  # Using a fixed radius for detection
				return marble
	
	return null

# Update the position of the dragging marble
func update_dragging_position(mouse_pos: Vector2):
	if dragging_marble != null:
		# Update the marble position to follow the mouse directly
		dragging_marble.global_position = mouse_pos
		
		# Ensure the hover indicator is visible while dragging
		if hover_indicator:
			hover_indicator.visible = true
		
		# Update the hover indicator position based on the current mouse position
		update_hover_indicator_position()

# Validate if a marble placement is valid for a player at specific triangular coordinates
func validate_marble_placement(_player, row: int, pos: int) -> bool:
	# Check if the position is valid and empty
	if not game_manager.is_pit_empty(row, pos):
		return false
	
	# Call the custom validation function for additional rules
	if not validate(row, pos):
		return false
	
	return true

# Custom validation function for additional game rules
# This will be expanded later with more complex validation logic
func validate(_row: int, _pos: int) -> bool:
	# For now, all positions that aren't occupied are valid
	# This function will be expanded later with more game rules
	return true

# Place a marble at a specific triangular position
func place_marble_at_grid_position(marble: Node2D, row: int, pos: int) -> bool:
	# Validate the placement
	var current_player = game_manager.get_current_player()
	if not validate_marble_placement(current_player, row, pos):
		return false
	
	# Get the pit at this position
	var pit = game_manager.get_pit_at_triangular_position(row, pos)
	if not pit:
		return false
	
	# Update the marble position
	marble.global_position = pit.position
	
	# Place the marble in the pit
	if not pit.place_marble(current_player.id, marble):
		return false
	
	print("Placed ", current_player.color, " marble at triangular position (", row, ",", pos, ")")
	
	return true

# Find all valid positions for the current player
func find_valid_positions() -> Array:
	# Get all empty pits
	var empty_pits = game_manager.get_all_empty_positions()
	var valid_positions = []
	
	# For each empty pit, check if it's a valid move
	for pit in empty_pits:
		if validate(pit.grid_y, pit.grid_x):
			valid_positions.append(pit)
	
	return valid_positions

# Highlight valid positions for the current player
func highlight_valid_positions():
	# Get all valid positions
	var valid_positions = find_valid_positions()
	
	# Create indicators for each valid position
	for pit in valid_positions:
		var indicator = create_position_indicator(pit.position, Color(0, 1, 0, 0.3))
		add_child(indicator)

# Create a position indicator at the specified position with the given color
func create_position_indicator(indicator_pos: Vector2, color: Color) -> Node2D:
	var indicator = Node2D.new()
	indicator.position = indicator_pos
	indicator.name = "PositionIndicator"
	
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/circle.png")
	sprite.scale = Vector2(0.15, 0.15)
	sprite.modulate = color
	
	indicator.add_child(sprite)
	
	return indicator
