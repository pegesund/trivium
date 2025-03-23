extends Node2D

# This script will handle the creation and management of marble sprites

# Scale factor for the marble (reduce this to make the marble smaller)
var marble_scale = 0.15  # 15% of original size

func _ready():
	# Get the viewport size to center the marble
	var viewport_size = get_viewport_rect().size
	var center_position = viewport_size / 2
	
	# Create a blue marble at the center of the screen
	create_marble("blue", center_position)

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
