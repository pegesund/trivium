extends Node2D

# This script will handle the creation and management of marble sprites

# Scale factor for the marble (reduce this to make the marble smaller)
var marble_scale = 0.165  # 16.5% of original size
var pit_texture = null

# Drag and drop variables
var hover_indicator
var dragging_marble = null
var original_marble_position = Vector2.ZERO  # Store the original position of the marble
var drag_offset: Vector2 = Vector2.ZERO
var hover_grid_x = -1
var hover_grid_y = -1
var hover_world_position = Vector2.ZERO  # Store the exact world position of the hover indicator

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
	
	# Print debug info
	print("Created pits with texture: ", pit_texture)

func _process(_delta):
	# Update hover indicator position if dragging
	if dragging_marble != null and hover_indicator != null:
		update_hover_indicator_position()

func _input(event):
	if game_manager.game_started:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					# Start dragging
					var marble = find_marble_under_mouse(get_global_mouse_position())
					if marble != null and game_manager.can_player_move_marble(marble):
						start_dragging(marble, get_global_mouse_position())
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
	print("Found ", all_intersections.size(), " intersection points")
	
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
	
	return marble_container

# Function to add a marble at a specific grid position
func add_marble_at_grid_position(marble_color, grid_x, grid_y, is_small = false):
	# Get the Background node to access its grid
	var background = get_node("../Background")
	
	# Check if we can get grid points from the background
	if background and background.has_method("get_grid_point_position"):
		# Get the world position from the grid coordinates
		var world_position = background.get_grid_point_position(grid_x, grid_y)
		return create_marble(marble_color, world_position, is_small)
	else:
		# Fallback if the background doesn't have the method
		var world_position = Vector2(grid_x * 50, grid_y * 50)  # Example conversion
		return create_marble(marble_color, world_position, is_small)

# Make a marble interactive for drag and drop
func make_marble_interactive(marble: Node2D):
	# Add a collision shape for interaction
	var area = Area2D.new()
	area.name = "InteractionArea"
	marble.add_child(area)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 50  # Increased radius for easier interaction
	collision.shape = shape
	area.add_child(collision)
	
	# Make sure the area is monitoring for input
	area.input_pickable = true
	
	return marble

# Create a hover indicator to show valid placement
func create_hover_indicator():
	var indicator = Node2D.new()
	indicator.name = "HoverIndicator"
	indicator.visible = false
	
	# Set z-index to be above both pits and marbles
	indicator.z_index = 100
	
	add_child(indicator)
	
	# Create a circle to show valid (green) or invalid (red) placement
	var indicator_circle = Sprite2D.new()
	indicator_circle.name = "IndicatorCircle"
	indicator_circle.texture = pit_texture if pit_texture != null else load("res://assets/sprites/marbles/pit.png")
	indicator_circle.scale = Vector2(marble_scale * 0.7, marble_scale * 0.7)  # Smaller than pits
	
	indicator.add_child(indicator_circle)
	
	return indicator

# Update the hover indicator position and validity
func update_hover_indicator_position():
	if dragging_marble == null or hover_indicator == null:
		return
	
	# Use the mouse position to find the closest grid position
	var mouse_position = get_global_mouse_position()
	
	var closest_position = game_manager.find_closest_grid_position(mouse_position)
	
	if not closest_position.is_empty():
		# Get the grid coordinates
		var grid_x = closest_position["grid_x"]
		var grid_y = closest_position["grid_y"]
		
		# Store these coordinates for use when dropping
		hover_grid_x = grid_x
		hover_grid_y = grid_y
		
		# Store the exact world position for placement
		hover_world_position = closest_position["position"]
		
		# SUPER SIMPLIFIED VALIDATION: Only check if the position is occupied
		var is_valid = not closest_position["occupied"]
		
		print("Grid position (", grid_x, ", ", grid_y, ") at ", 
			hover_world_position, " is_valid: ", is_valid, 
			", is_occupied: ", closest_position["occupied"])
		
		# Update the indicator position and color
		hover_indicator.global_position = hover_world_position
		hover_indicator.visible = true
		
		# Set color: green if valid, red if invalid or occupied
		var indicator_circle = hover_indicator.get_node("IndicatorCircle")
		if indicator_circle:
			if is_valid:
				indicator_circle.modulate = Color(0, 1, 0, 0.5)  # Green
			else:
				indicator_circle.modulate = Color(1, 0, 0, 0.5)  # Red
	else:
		# If no valid grid position is found, hide the indicator and reset coordinates
		print("No valid grid position found near mouse")
		hover_indicator.visible = false
		hover_grid_x = -1
		hover_grid_y = -1
		hover_world_position = Vector2.ZERO

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

# Start dragging a marble
func start_dragging(marble: Node2D, _mouse_pos: Vector2):
	dragging_marble = marble
	original_marble_position = marble.global_position
	
	# Set the drag offset to zero for more direct mouse following
	drag_offset = Vector2.ZERO
	print("Drag offset set to zero for direct mouse following")
	
	# Show the hover indicator
	if hover_indicator:
		hover_indicator.visible = true
	
	# If the marble is already placed on the grid, remove it from that position
	if marble in game_manager.marble_to_grid_position:
		var _grid_pos = game_manager.marble_to_grid_position[marble]  # Unused but kept for clarity
		var position_key = str(marble.position.x) + "_" + str(marble.position.y)
		
		if position_key in game_manager.grid_positions:
			game_manager.grid_positions[position_key]["occupied"] = false
			game_manager.grid_positions[position_key]["marble"] = null
		
		game_manager.marble_to_grid_position.erase(marble)

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

# Stop dragging and place the marble if valid
func stop_dragging():
	if dragging_marble and hover_indicator:
		print("Attempting to place marble at hover grid: (", hover_grid_x, ", ", hover_grid_y, ")")
		
		# Check if the hover indicator is visible and valid (green)
		var hover_valid = hover_indicator.visible and hover_indicator.get_node("IndicatorCircle").modulate == Color(0, 1, 0, 0.5)
		print("Hover indicator is visible and valid: ", hover_valid)
		
		if hover_valid:
			# Use the hover grid coordinates for placement
			print("DEBUG: Placing marble at grid: (", hover_grid_x, ", ", hover_grid_y, ") at exact position: ", hover_world_position)
			
			# FORCE SUCCESS: If the hover indicator is green, we know the position is valid
			# So we'll directly update the grid state without additional validation
			
			# Find the position key for these coordinates
			var position_key = ""
			
			# First, find the exact grid position that matches our coordinates
			for pos_key in game_manager.grid_positions:
				var pos_data = game_manager.grid_positions[pos_key]
				if pos_data["grid_x"] == hover_grid_x and pos_data["grid_y"] == hover_grid_y:
					position_key = pos_key
					print("DEBUG: Found matching position key: ", position_key, " for grid (", 
						hover_grid_x, ", ", hover_grid_y, ") at position ", pos_data["position"])
					break
			
			if not position_key.is_empty():
				print("DEBUG: Using position key: ", position_key, " for placement")
				
				# Update the marble position to the exact hover position
				dragging_marble.global_position = hover_world_position
				
				# Update the grid state
				game_manager.grid_positions[position_key]["occupied"] = true
				game_manager.grid_positions[position_key]["marble"] = dragging_marble
				
				# Update the marble to grid position mapping
				game_manager.marble_to_grid_position[dragging_marble] = Vector2(hover_grid_x, hover_grid_y)
				
				var current_player = game_manager.get_current_player()
				print("DEBUG: Successfully placed ", current_player.color, " marble at grid position (", 
					hover_grid_x, ", ", hover_grid_y, ") at exact position ", hover_world_position)
				
				# Successfully placed, end player's turn
				game_manager.end_turn()
				# Reset dragging state
				dragging_marble = null
				hover_grid_x = -1
				hover_grid_y = -1
				hover_world_position = Vector2.ZERO
				
				if hover_indicator:
					hover_indicator.visible = false
				return
			else:
				print("DEBUG: ERROR - No position key found for grid: (", hover_grid_x, ", ", hover_grid_y, ")")
		
		# If we reach here, placement failed or was invalid
		print("Placement failed or invalid, returning marble to original position: ", original_marble_position)
		# Return the marble to its original position
		dragging_marble.global_position = original_marble_position
	
	# Reset dragging state
	dragging_marble = null
	hover_grid_x = -1
	hover_grid_y = -1
	hover_world_position = Vector2.ZERO
	
	if hover_indicator:
		hover_indicator.visible = false

# Validate if a marble placement is valid for a player at specific grid coordinates
func validate_marble_placement(_player, grid_x: int, grid_y: int) -> bool:
	print("Validating placement at grid: (", grid_x, ", ", grid_y, ")")
	
	# Get the position key for these coordinates
	var position_key = ""
	for pos_key in game_manager.grid_positions:
		var pos_data = game_manager.grid_positions[pos_key]
		if pos_data["grid_x"] == grid_x and pos_data["grid_y"] == grid_y:
			position_key = pos_key
			print("Found position key: ", position_key, " occupied: ", pos_data["occupied"])
			break
	
	if position_key.is_empty():
		print("No position key found for grid: (", grid_x, ", ", grid_y, ")")
		return false
	
	# Check if the position is already occupied
	if game_manager.grid_positions[position_key]["occupied"]:
		print("Position is already occupied")
		return false
	
	# Call the custom validation function for additional rules
	if not validate(grid_x, grid_y):
		print("Custom validation failed")
		return false
	
	print("Position is valid")
	return true

# Custom validation function for additional game rules
# This will be expanded later with more complex validation logic
func validate(_grid_x: int, _grid_y: int) -> bool:
	# For now, all positions that aren't occupied are valid
	# This function will be expanded later with more game rules
	return true

# Place a marble at a specific grid position
func place_marble_at_grid_position(marble: Node2D, grid_x: int, grid_y: int) -> bool:
	print("Placing marble at grid: (", grid_x, ", ", grid_y, ")")
	
	# Validate the placement
	var current_player = game_manager.get_current_player()
	if not validate_marble_placement(current_player, grid_x, grid_y):
		print("Placement validation failed")
		return false
	
	# Find the position key for these coordinates
	var position_key = ""
	var target_position = Vector2.ZERO
	
	for pos_key in game_manager.grid_positions:
		var pos_data = game_manager.grid_positions[pos_key]
		if pos_data["grid_x"] == grid_x and pos_data["grid_y"] == grid_y:
			position_key = pos_key
			target_position = pos_data["position"]
			break
	
	if position_key.is_empty():
		print("No position key found for grid: (", grid_x, ", ", grid_y, ")")
		return false
	
	print("Found position key: ", position_key, " with target position: ", target_position)
	
	# Update the marble position
	marble.global_position = target_position
	
	# Update the grid state
	game_manager.grid_positions[position_key]["occupied"] = true
	game_manager.grid_positions[position_key]["marble"] = marble
	
	# Update the marble to grid position mapping
	game_manager.marble_to_grid_position[marble] = Vector2(grid_x, grid_y)
	
	print("Successfully placed ", current_player.color, " marble at grid position (", grid_x, ", ", grid_y, ")")
	
	return true

# Place a marble at a specific grid position using the exact hover position
func place_marble_at_exact_position(marble: Node2D, grid_x: int, grid_y: int, exact_position: Vector2) -> bool:
	print("Placing marble at grid: (", grid_x, ", ", grid_y, ") with exact position: ", exact_position)
	
	# Find the position key for these coordinates
	var position_key = ""
	var is_occupied = false
	
	# First, find the exact grid position that matches our coordinates
	for pos_key in game_manager.grid_positions:
		var pos_data = game_manager.grid_positions[pos_key]
		if pos_data["grid_x"] == grid_x and pos_data["grid_y"] == grid_y:
			position_key = pos_key
			is_occupied = pos_data["occupied"]
			print("Found matching position key: ", position_key, " for grid (", 
				grid_x, ", ", grid_y, ") at position ", pos_data["position"], 
				" occupied: ", is_occupied)
			break
	
	if position_key.is_empty():
		print("No position key found for grid: (", grid_x, ", ", grid_y, ")")
		return false
	
	# Check if the position is already occupied
	if is_occupied:
		print("Position is already occupied")
		return false
	
	print("Using position key: ", position_key, " for placement")
	
	# Update the marble position to the exact hover position
	marble.global_position = exact_position
	
	# Update the grid state
	game_manager.grid_positions[position_key]["occupied"] = true
	game_manager.grid_positions[position_key]["marble"] = marble
	
	# Update the marble to grid position mapping
	game_manager.marble_to_grid_position[marble] = Vector2(grid_x, grid_y)
	
	var current_player = game_manager.get_current_player()
	print("Successfully placed ", current_player.color, " marble at grid position (", grid_x, ", ", grid_y, ") at exact position ", exact_position)
	
	return true

# Return a marble to its starting position if placement fails
func return_marble_to_starting_position(marble: Node2D):
	# For now, just return it to a default position based on the player
	var player_index = -1
	
	# Find which player this marble belongs to
	for i in range(game_manager.players.size()):
		if marble in game_manager.players[i].large_marbles:
			player_index = i
			break
	
	if player_index >= 0:
		# Calculate a position based on the player index
		var marble_index = game_manager.players[player_index].large_marbles.find(marble)
		var x_pos = 100 + (player_index * 200) + (marble_index * 50)
		var y_pos = 650
		
		# Move the marble back
		marble.position = Vector2(x_pos, y_pos)
		
		print("Returned ", game_manager.players[player_index].color, " marble to starting position")
