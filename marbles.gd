extends Node2D

# This script will handle the creation and management of marble sprites

# Scale factor for the marble (reduce this to make the marble smaller)
var marble_scale = 0.165  # 16.5% of original size
var pit_texture = null

func _ready():
	# Load the pit texture once
	pit_texture = load("res://assets/sprites/marbles/pit.png")
	if pit_texture == null:
		print("ERROR: Could not load pit texture!")
		return
		
	# Get the viewport size to center the marble
	var viewport_size = get_viewport_rect().size
	var center_position = viewport_size / 2
	
	# Create pits at all white circle positions
	create_pits_at_all_grid_points()
	
	# Print debug info
	print("Created pits with texture: ", pit_texture)

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
	var hover_indicator = Node2D.new()
	hover_indicator.name = "HoverIndicator"
	hover_indicator.visible = false
	
	# Set z-index to be above both pits and marbles
	hover_indicator.z_index = 100
	
	add_child(hover_indicator)
	
	# Create a circle to show valid (green) or invalid (red) placement
	var indicator_circle = Sprite2D.new()
	indicator_circle.name = "IndicatorCircle"
	indicator_circle.texture = pit_texture if pit_texture != null else load("res://assets/sprites/marbles/pit.png")
	indicator_circle.scale = Vector2(marble_scale * 0.7, marble_scale * 0.7)  # Smaller than pits
	
	hover_indicator.add_child(indicator_circle)
	
	return hover_indicator

# Update the hover indicator position and color
func update_hover_indicator(hover_indicator: Node2D, pos: Vector2, is_valid: bool):
	if hover_indicator == null:
		return
		
	# Position the hover indicator directly on the pit
	hover_indicator.position = pos
	hover_indicator.visible = true
	
	# Update the indicator color
	var indicator_circle = hover_indicator.get_node("IndicatorCircle")
	if indicator_circle:
		indicator_circle.modulate = Color(0, 1, 0, 0.5) if is_valid else Color(1, 0, 0, 0.5)
