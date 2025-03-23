extends Node2D

# This script will handle the creation and management of marble sprites

# Scale factor for the marble (reduce this to make the marble smaller)
var marble_scale = 0.165  # 16.5% of original size

func _ready():
	# Get the viewport size to center the marble
	var viewport_size = get_viewport_rect().size
	var center_position = viewport_size / 2
	
	# Create pits at all white circle positions
	create_pits_at_all_grid_points()

# Function to create pits at all white circle positions in the background
func create_pits_at_all_grid_points():
	# Get the Background node to access its grid
	var background = get_node("../Background")
	
	# Get all intersection points
	var all_intersections = background.get_all_intersection_points()
	
	# Create pits at all inner intersection points (white circles)
	for intersection in all_intersections:
		if not intersection["is_outer"]:  # Only create pits at inner points (white circles)
			create_pit(intersection["position"])
			
			# Place a marble on top of the pit at the top position
			if intersection["position"].y == background.get_grid_point_position(0, 0).y:
				create_marble("blue", intersection["position"])

# Function to create a pit at a specific position
func create_pit(position):
	# Create the main container node for this pit
	var pit_container = Node2D.new()
	pit_container.position = position
	pit_container.name = "Pit"
	add_child(pit_container)
	
	# Add the pit sprite
	var pit_sprite = Sprite2D.new()
	pit_sprite.texture = load("res://assets/sprites/marbles/pit.png")
	pit_sprite.scale = Vector2(marble_scale, marble_scale)  # Same scale as marbles
	pit_container.add_child(pit_sprite)
	
	return pit_container

# Function to create a marble with multiple layers at a specific position
func create_marble(marble_color, position):
	# Create the main container node for this marble
	var marble_container = Node2D.new()
	marble_container.position = position
	marble_container.name = marble_color.capitalize() + "Marble"
	add_child(marble_container)
	
	# Add the shadow layer (bottom layer)
	var shadow_layer = Sprite2D.new()
	shadow_layer.texture = load("res://assets/sprites/marbles/" + marble_color + "/shadow.png")
	shadow_layer.scale = Vector2(marble_scale, marble_scale)  # Scale down
	marble_container.add_child(shadow_layer)
	
	# Add the sphere layer (main marble)
	var sphere_layer = Sprite2D.new()
	sphere_layer.texture = load("res://assets/sprites/marbles/" + marble_color + "/sphere.png")
	sphere_layer.scale = Vector2(marble_scale, marble_scale)  # Scale down
	marble_container.add_child(sphere_layer)
	
	# Add the glow layer
	var glow_layer = Sprite2D.new()
	glow_layer.texture = load("res://assets/sprites/marbles/" + marble_color + "/glow.png")
	glow_layer.scale = Vector2(marble_scale, marble_scale)  # Scale down
	marble_container.add_child(glow_layer)
	
	# Add the 90 degree reflection layer (top layer)
	var reflection_layer = Sprite2D.new()
	reflection_layer.texture = load("res://assets/sprites/marbles/" + marble_color + "/90.png")
	reflection_layer.scale = Vector2(marble_scale, marble_scale)  # Scale down
	marble_container.add_child(reflection_layer)
	
	return marble_container

# Function to add a marble at a specific grid position
func add_marble_at_grid_position(marble_color, grid_x, grid_y):
	# Get the Background node to access its grid
	var background = get_node("../Background")
	
	# Check if we can get grid points from the background
	if background and background.has_method("get_grid_point_position"):
		# Get the world position from the grid coordinates
		var world_position = background.get_grid_point_position(grid_x, grid_y)
		return create_marble(marble_color, world_position)
	else:
		# Fallback if the background doesn't have the method
		var world_position = Vector2(grid_x * 50, grid_y * 50)  # Example conversion
		return create_marble(marble_color, world_position)
