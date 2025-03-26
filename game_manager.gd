extends Node2D

# Game Manager - Handles game logic, player turns, and marble placement

# Player data structure
class Player:
	var id: int  # Player ID (1, 2, 3)
	var color: String  # Marble color
	var large_marbles: Array[Node2D] = []  # References to the player's large marbles
	var path_position: int = 0  # Position on the path (0-50)
	
	func _init(player_id: int, player_color: String):
		id = player_id
		color = player_color

# Game state variables
var players: Array[Player] = []
var current_turn: int = 0  # Index of the current player (0, 1, 2)
var total_path_steps: int = 50  # Total steps in the path
var game_started: bool = false

# Drag and drop variables
var dragging_marble: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO
var hover_indicator: Node2D = null

# Triangle grid state
var grid_positions: Dictionary = {}  # Maps grid coordinates to their occupancy state
var marble_to_grid_position: Dictionary = {}  # Maps marble nodes to their grid positions
var position_to_grid_coords: Dictionary = {}  # Maps position keys to grid coordinates

# References to other nodes
@onready var marbles_node = get_node("../Marbles")
@onready var background_node = get_node("../Background")

func _ready():
	# Initialize the game
	initialize_players()
	initialize_grid()
	setup_initial_marbles()
	
	# Create hover indicator for placement feedback
	hover_indicator = marbles_node.create_hover_indicator()
	
	# Start with player 1
	current_turn = 0
	game_started = true

func _process(_delta):
	# Update hover indicator position if dragging
	if dragging_marble != null and hover_indicator != null:
		update_hover_indicator()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				var marble = find_marble_under_mouse(get_global_mouse_position())
				if marble != null and can_player_move_marble(marble):
					start_dragging(marble, get_global_mouse_position())
			else:
				# Stop dragging
				if dragging_marble != null:
					stop_dragging(get_global_mouse_position())
	
	elif event is InputEventMouseMotion:
		# Update dragging position
		if dragging_marble != null:
			update_dragging_position(get_global_mouse_position())

# Initialize the three players with their colors
func initialize_players():
	players.append(Player.new(1, "blue"))
	players.append(Player.new(2, "rosa"))
	players.append(Player.new(3, "green"))

# Initialize the grid positions dictionary
func initialize_grid():
	# Get all intersection points from the background
	var all_intersections = background_node.get_all_intersection_points()
	
	# For each intersection point, create a grid entry
	for i in range(all_intersections.size()):
		var intersection = all_intersections[i]
		if not intersection["is_outer"]:  # Only use inner points (white circles)
			# Create a unique key for this position
			var position_key = str(intersection["position"].x) + "_" + str(intersection["position"].y)
			
			# Find the grid coordinates for this position
			var grid_coords = find_grid_coordinates_for_position(intersection["position"])
			
			# Store the position with empty occupancy
			grid_positions[position_key] = {
				"position": intersection["position"],
				"occupied": false,
				"marble": null,
				"grid_x": grid_coords.x,
				"grid_y": grid_coords.y
			}
			
			# Store the mapping from position key to grid coordinates
			position_to_grid_coords[position_key] = grid_coords

# Find grid coordinates for a world position
func find_grid_coordinates_for_position(world_pos: Vector2) -> Vector2:
	# Get viewport dimensions to calculate the center position
	var viewport_size = get_viewport().get_visible_rect().size
	var center_x = viewport_size.x / 2 + background_node.position_x_offset
	var center_y = viewport_size.y * background_node.vertical_position_ratio + background_node.position_y_offset
	
	# Calculate the actual width using the scale factor
	var scaled_width = background_node.base_width * background_node.scale_factor
	var y_size = scaled_width * background_node.height_to_width_ratio
	
	# Calculate the height of each row
	var rows = 6
	var row_height = y_size / (rows - 1)
	
	# Find the row (y coordinate) based on vertical distance from center
	var grid_y = round((world_pos.y - center_y) / row_height)
	
	# Make sure grid_y is within bounds
	grid_y = clamp(grid_y, 0, rows - 1)
	
	# Calculate row width (proportional to row index)
	var row_width = scaled_width * grid_y / (rows - 1)
	
	# Calculate number of points in this row
	var points_in_row = int(grid_y) + 1
	
	# Calculate horizontal spacing
	var col_width = 0
	if points_in_row > 1:
		col_width = row_width / (points_in_row - 1)
	
	# Calculate the start x position for this row
	var start_x = center_x - row_width / 2
	
	# Find the column (x coordinate) based on horizontal distance from start
	var grid_x = 0
	if col_width > 0:
		grid_x = round((world_pos.x - start_x) / col_width)
	
	# Make sure grid_x is within bounds
	grid_x = clamp(grid_x, 0, points_in_row - 1)
	
	return Vector2(grid_x, grid_y)

# Set up the initial marbles for each player
func setup_initial_marbles():
	# Get viewport dimensions for positioning
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Calculate the bottom of the triangle to position marbles below it
	var center_x = viewport_size.x / 2 + background_node.position_x_offset
	var center_y = viewport_size.y * background_node.vertical_position_ratio + background_node.position_y_offset
	
	# Calculate the triangle's height
	var scaled_width = background_node.base_width * background_node.scale_factor
	var triangle_height = scaled_width * background_node.height_to_width_ratio
	
	# Calculate the bottom of the triangle (y-coordinate)
	var triangle_bottom = center_y + triangle_height
	
	# Position all marbles below the triangle
	var marble_start_y = triangle_bottom + 50.0  # 50 pixels below the triangle
	
	# Calculate the total width needed for all marbles
	var marble_spacing = 40.0  # Reduced spacing between marbles
	var group_spacing = 80.0   # Spacing between color groups
	var total_width = (3 * 3 * marble_spacing) + (2 * group_spacing)
	
	# Calculate the starting x position to center all marbles
	var start_x = center_x - (total_width / 2.0)  # Using float division
	
	# For each player, create 3 large marbles grouped by color
	for player_idx in range(players.size()):
		var player = players[player_idx]
		
		# Calculate the starting position for this player's group
		var group_start_x = start_x + player_idx * (3 * marble_spacing + group_spacing)
		
		for i in range(3):
			var x_pos = group_start_x + i * marble_spacing
			var starting_position = Vector2(x_pos, marble_start_y)
			
			var large_marble = marbles_node.create_marble(player.color, starting_position)
			marbles_node.make_marble_interactive(large_marble)
			player.large_marbles.append(large_marble)

# Update the hover indicator position and color
func update_hover_indicator():
	if dragging_marble == null or hover_indicator == null:
		return
	
	# Find the closest grid position
	var mouse_pos = get_global_mouse_position()
	var closest_position = find_closest_grid_position(mouse_pos)
	
	if not closest_position.is_empty():
		# Get the grid coordinates
		var grid_x = closest_position["grid_x"]
		var grid_y = closest_position["grid_y"]
		
		# Check if this is a valid placement
		var current_player = get_current_player()
		var is_valid = validate_marble_placement(current_player, grid_x, grid_y)
		
		# Update the indicator using the Marbles script
		marbles_node.update_hover_indicator(hover_indicator, closest_position["position"], is_valid)
	else:
		hover_indicator.visible = false

# Find the closest grid position to a world position
func find_closest_grid_position(world_pos: Vector2) -> Dictionary:
	var closest_pos = null
	var closest_distance = INF
	
	for pos_key in grid_positions:
		var pos_data = grid_positions[pos_key]
		var distance = world_pos.distance_to(pos_data["position"])
		
		if distance < closest_distance:
			closest_distance = distance
			closest_pos = pos_data
	
	# Only return if within a reasonable distance
	if closest_distance < 50:  # Adjust threshold as needed
		return closest_pos
	
	return {}

# Find a marble under the mouse position
func find_marble_under_mouse(mouse_pos: Vector2) -> Node2D:
	# Check all marbles for all players (not just current player)
	for player in players:
		for marble in player.large_marbles:
			# Simple distance check for now
			var distance = mouse_pos.distance_to(marble.global_position)
			if distance <= 50:  # Using a fixed radius for detection
				return marble
	
	return null

# Check if the current player can move a specific marble
func can_player_move_marble(marble: Node2D) -> bool:
	var current_player = get_current_player()
	
	# Check if this marble belongs to the current player
	return marble in current_player.large_marbles

# Start dragging a marble
func start_dragging(marble: Node2D, mouse_pos: Vector2):
	dragging_marble = marble
	drag_offset = marble.global_position - mouse_pos
	
	# Show the hover indicator
	if hover_indicator:
		hover_indicator.visible = true
	
	# If the marble is already placed on the grid, remove it from that position
	if marble in marble_to_grid_position:
		var _grid_pos = marble_to_grid_position[marble]  # Unused but kept for clarity
		var position_key = str(marble.position.x) + "_" + str(marble.position.y)
		
		if position_key in grid_positions:
			grid_positions[position_key]["occupied"] = false
			grid_positions[position_key]["marble"] = null
		
		marble_to_grid_position.erase(marble)

# Update the position of the dragging marble
func update_dragging_position(mouse_pos: Vector2):
	if dragging_marble != null:
		dragging_marble.global_position = mouse_pos + drag_offset

# Stop dragging and try to place the marble
func stop_dragging(mouse_pos: Vector2):
	if dragging_marble == null:
		return
	
	# Find the closest grid position
	var closest_position = find_closest_grid_position(mouse_pos)
	
	if not closest_position.is_empty():
		# Get the grid coordinates
		var grid_x = closest_position["grid_x"]
		var grid_y = closest_position["grid_y"]
		
		# Try to place the marble at this position
		var success = place_marble_at_grid_position(dragging_marble, grid_x, grid_y)
		
		if success:
			# If placement was successful, move to the next player's turn
			end_turn()
		else:
			# If placement failed, return the marble to its original position
			return_marble_to_starting_position(dragging_marble)
	else:
		# If no valid position found, return the marble to its original position
		return_marble_to_starting_position(dragging_marble)
	
	# Reset dragging state
	dragging_marble = null
	
	# Hide the hover indicator
	if hover_indicator:
		hover_indicator.visible = false

# Helper function to return a marble to its starting position
func return_marble_to_starting_position(marble: Node2D):
	# Find which player owns this marble and its index
	var player_index = -1
	var marble_index = -1
	
	for i in range(players.size()):
		marble_index = players[i].large_marbles.find(marble)
		if marble_index >= 0:
			player_index = i
			break
	
	if player_index >= 0 and marble_index >= 0:
		# Get viewport dimensions for positioning
		var viewport_size = get_viewport().get_visible_rect().size
		
		# Calculate the bottom of the triangle
		var center_x = viewport_size.x / 2 + background_node.position_x_offset
		var center_y = viewport_size.y * background_node.vertical_position_ratio + background_node.position_y_offset
		var scaled_width = background_node.base_width * background_node.scale_factor
		var triangle_height = scaled_width * background_node.height_to_width_ratio
		var triangle_bottom = center_y + triangle_height
		
		# Position marble back in its starting position
		var marble_start_y = triangle_bottom + 50.0
		var marble_spacing = 40.0
		var group_spacing = 80.0
		var total_width = (3 * 3 * marble_spacing) + (2 * group_spacing)
		var start_x = center_x - (total_width / 2.0)
		
		# Calculate the position in the group
		var group_start_x = start_x + player_index * (3 * marble_spacing + group_spacing)
		var x_pos = group_start_x + marble_index * marble_spacing
		
		marble.position = Vector2(x_pos, marble_start_y)

# Place a marble at a specific grid position
func place_marble_at_grid_position(marble: Node2D, grid_x: int, grid_y: int) -> bool:
	# Get the world position from the grid coordinates
	var world_position = background_node.get_grid_point_position(grid_x, grid_y)
	
	# Check if the position is valid
	if world_position == Vector2.ZERO:
		return false
	
	# Create a unique key for this position
	var position_key = str(world_position.x) + "_" + str(world_position.y)
	
	# Check if this position exists in our grid and is not occupied
	if position_key in grid_positions and not grid_positions[position_key]["occupied"]:
		# Check if the placement is valid according to game rules
		var current_player = get_current_player()
		if not validate_marble_placement(current_player, grid_x, grid_y):
			return false
		
		# Move the marble to this position (directly on the pit, z-index handles visibility)
		marble.position = world_position
		
		# Mark the position as occupied
		grid_positions[position_key]["occupied"] = true
		grid_positions[position_key]["marble"] = marble
		
		# Store the grid position for this marble
		marble_to_grid_position[marble] = {"grid_x": grid_x, "grid_y": grid_y}
		
		return true
	
	return false

# Validate if a marble can be placed at a specific position
func validate_marble_placement(_player: Player, grid_x: int, grid_y: int) -> bool:
	# In the initial implementation, any free position is valid
	# This function will be expanded later with more rules
	
	# Get the world position from the grid coordinates
	var world_position = background_node.get_grid_point_position(grid_x, grid_y)
	
	# Check if the position is valid
	if world_position == Vector2.ZERO:
		return false
	
	# Create a unique key for this position
	var position_key = str(world_position.x) + "_" + str(world_position.y)
	
	# Check if this position exists in our grid and is not occupied
	if position_key in grid_positions and not grid_positions[position_key]["occupied"]:
		return true
	
	return false

# Get the highest position (row) of a player's marbles
func get_player_highest_position(player: Player) -> int:
	var highest_row = 5  # Start with the bottom row (5)
	
	# Check all large marbles
	for marble in player.large_marbles:
		if marble in marble_to_grid_position:
			var grid_pos = marble_to_grid_position[marble]
			highest_row = min(highest_row, grid_pos["grid_y"])
	
	return highest_row

# Move a player forward on the path
func move_player_forward(player: Player, steps: int):
	# Calculate new position
	var new_position = player.path_position + steps
	
	# Cap at the end of the path
	if new_position > total_path_steps:
		new_position = total_path_steps
	
	# Update player position
	player.path_position = new_position
	
	# Check for win condition
	if player.path_position >= total_path_steps:
		handle_player_win(player)

# Handle player winning the game
func handle_player_win(player: Player):
	print("Player " + str(player.id) + " wins!")
	# Additional win logic can be added here

# End the current turn and move to the next player
func end_turn():
	# Calculate how many steps the current player can move
	var current_player = players[current_turn]
	var highest_position = get_player_highest_position(current_player)
	var steps_to_move = 6 - highest_position  # 6 rows total, so row 0 gives 6 steps, row 5 gives 1 step
	
	# Move the player forward
	move_player_forward(current_player, steps_to_move)
	
	# Move to the next player
	current_turn = (current_turn + 1) % players.size()

# Get the current player
func get_current_player() -> Player:
	return players[current_turn]
