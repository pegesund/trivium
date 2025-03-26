extends Node2D

# Scale factor for the numbers (can be adjusted to make numbers larger or smaller)
var number_scale = 0.15  # 20% of original size

# Function called when the node enters the scene tree
func _ready():
	# Add numbers to the grid pits
	add_numbers_to_pits()

# Function to add numbers to all pits in the triangular grid
func add_numbers_to_pits():
	# Get the Background node to access its grid
	var background = get_node("../Background")
	
	# Get all intersection points
	var all_intersections = background.get_all_intersection_points()
	
	# Filter to get only inner points (white circles/pits)
	var inner_points = []
	for intersection in all_intersections:
		if not intersection["is_outer"]:  # Only use inner points (white circles)
			inner_points.append(intersection["position"])
	
	# Get the grid structure to determine rows
	var rows = 6  # Total number of rows in the triangular grid
	
	# Create a mapping of positions to their grid coordinates
	var position_to_grid = {}
	for grid_y in range(rows):
		for grid_x in range(grid_y + 1):  # Each row has (row_index + 1) points
			var pos = background.get_grid_point_position(grid_x, grid_y)
			position_to_grid[pos] = {"x": grid_x, "y": grid_y}
	
	# Assign numbers to positions based on row
	# Row 0 (top) gets number 6, and each subsequent row gets a decreasing number
	for position in inner_points:
		# Find the closest grid point to this position
		var closest_grid = find_closest_grid_point(position, position_to_grid)
		
		if closest_grid:
			var row = closest_grid["y"]
			var number = 6 - row  # Top row (0) gets 6, next row gets 5, etc.
			
			# Only use numbers 1-6
			if number >= 1 and number <= 6:
				create_number(number, position)

# Function to find the closest grid point to a given position
func find_closest_grid_point(position, position_to_grid):
	var min_distance = INF
	var closest_grid = null
	
	for grid_pos in position_to_grid:
		var distance = position.distance_to(grid_pos)
		if distance < min_distance:
			min_distance = distance
			closest_grid = position_to_grid[grid_pos]
	
	return closest_grid

# Function to create a number with its shadow at a specific position
func create_number(number, position):
	# Create the main container node for this number
	var number_container = Node2D.new()
	number_container.position = position
	number_container.name = "Number" + str(number)
	number_container.z_index = 20  # Set z-index higher than pits (5) and marbles (10)
	add_child(number_container)
	
	# Add the shadow layer (bottom layer)
	var shadow_layer = Sprite2D.new()
	shadow_layer.texture = load("res://assets/numbers/" + str(number) + "-shadow.png")
	shadow_layer.scale = Vector2(number_scale, number_scale)  # Scale down
	number_container.add_child(shadow_layer)
	
	# Add the number layer (top layer)
	var number_layer = Sprite2D.new()
	number_layer.texture = load("res://assets/numbers/" + str(number) + ".png")
	number_layer.scale = Vector2(number_scale, number_scale)  # Scale down
	number_container.add_child(number_layer)
	
	return number_container

# Function to add a number at a specific grid position
func add_number_at_grid_position(number, grid_x, grid_y):
	# Get the Background node to access its grid
	var background = get_node("../Background")
	
	# Check if we can get grid points from the background
	if background and background.has_method("get_grid_point_position"):
		# Get the world position from the grid coordinates
		var world_position = background.get_grid_point_position(grid_x, grid_y)
		return create_number(number, world_position)
	else:
		# Fallback if the background doesn't have the method
		var world_position = Vector2(grid_x * 50, grid_y * 50)  # Example conversion
		return create_number(number, world_position)
