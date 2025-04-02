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
	
	# Start with player 1
	current_turn = 0
	game_started = true

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
			
			# Also store the reverse mapping
			position_to_grid_coords[position_key] = grid_coords
	
# Find grid coordinates for a world position
func find_grid_coordinates_for_position(world_pos: Vector2) -> Vector2:
	# This is a simplified approach - in a real game, you'd use a proper mapping algorithm
	# For now, we'll use the background's grid point lookup if available
	if background_node and background_node.has_method("get_grid_coordinates_for_position"):
		return background_node.get_grid_coordinates_for_position(world_pos)
	
	# Fallback approach - approximate grid coordinates
	# This assumes a regular grid with known spacing
	var grid_spacing = 100  # Example value, adjust based on your grid
	return Vector2(round(world_pos.x / grid_spacing), round(world_pos.y / grid_spacing))

# Setup initial marbles for each player
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

# Get the current player
func get_current_player() -> Player:
	return players[current_turn]

# Move to the next player's turn
func end_turn():
	# Move to the next player
	current_turn = (current_turn + 1) % players.size()
	print("Now it's Player ", get_current_player().id, "'s turn")

# Place a marble at a specific triangular position (row, position in row)
func place_marble_at_triangular_position(player_id: int, row: int, pos: int, marble_node: Node2D) -> bool:
	# Use the background node's function to place the marble at the specified pit
	return background_node.place_marble_at_pit(row, pos, player_id, marble_node)

# Get a pit at a specific triangular position
func get_pit_at_triangular_position(row: int, pos: int):
	return background_node.get_pit(row, pos)

# Check if a triangular position is valid and empty
func is_valid_empty_position(row: int, pos: int) -> bool:
	return background_node.is_pit_empty(row, pos)

# Get all empty pits in the triangular grid
func get_all_empty_positions() -> Array:
	return background_node.get_empty_pits()

# Get all pits owned by a specific player
func get_player_positions(player_id: int) -> Array:
	return background_node.get_player_pits(player_id)

# Find the closest grid position to a world position
func find_closest_grid_position(world_pos: Vector2) -> Dictionary:
	var closest_pos = {}
	var closest_distance = INF
	
	# Debug the input position
	print("Finding closest grid position to world position: ", world_pos)
	
	for pos_key in grid_positions:
		var pos_data = grid_positions[pos_key]
		var distance = pos_data["position"].distance_to(world_pos)
		
		# Debug each position's distance
		if distance < 100:  # Only print positions that are reasonably close
			print("Grid (", pos_data["grid_x"], ", ", pos_data["grid_y"], ") at ", 
				pos_data["position"], " distance: ", distance, " occupied: ", pos_data["occupied"])
		
		if distance < closest_distance:
			closest_distance = distance
			closest_pos = pos_data.duplicate() # Create a copy to avoid reference issues
	
	# Only return if within a reasonable distance
	if closest_distance < 100:  # Increased threshold for better detection
		print("Found closest grid position: (", closest_pos["grid_x"], ", ", closest_pos["grid_y"], 
			") at ", closest_pos["position"], " distance: ", closest_distance, 
			" occupied: ", closest_pos["occupied"])
		return closest_pos
	
	print("No grid position found within threshold distance")
	return {}

# Print all grid positions for debugging
func debug_print_grid_positions():
	print("==== DEBUG: All Grid Positions ====")
	for pos_key in grid_positions:
		var pos_data = grid_positions[pos_key]
		print("Grid (", pos_data["grid_x"], ", ", pos_data["grid_y"], ") at position ", pos_data["position"])
	print("==== END DEBUG ====")

# Check if the current player can move a specific marble
func can_player_move_marble(marble: Node2D) -> bool:
	var current_player = get_current_player()
	
	# First check if this marble is one of the player's starting marbles
	if marble in current_player.large_marbles:
		return true
	
	# If not a starting marble, check if it's a marble on the board that belongs to this player
	# Get all pits owned by the current player
	var player_pits = background_node.get_player_pits(current_player.id)
	
	# Check if this marble is in any of the player's pits
	for pit in player_pits:
		if pit.marble == marble:
			return true
	
	# If we reach here, the marble doesn't belong to the current player
	return false
