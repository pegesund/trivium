extends Node2D

# Triangle configuration
var base_width = 200.0  # Base width of the triangle in pixels
var scale_factor = 1.7  # Scale factor to adjust the overall size (increase for larger triangle)
var height_to_width_ratio = 1  # How much taller the triangle is compared to its width (set to 1.8 as required)
var grid_color = Color(0.0, 0.0, 0.0, 1.0)  # Black color for the grid lines
var point_color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray color for the points
var background_color_top = Color(0.87, 0.87, 0.89, 1.0)  # Very light blue-gray for top gradient
var background_color_bottom = Color(0.82, 0.82, 0.85, 1.0)  # Slightly darker blue-gray for bottom gradient
var intersection_fill_color = Color(1.0, 1.0, 1.0, 1.0)  # White color for intersection fill
var intersection_radius = 5.0  # Radius of the intersection points
var connection_width = 2.0  # Width of the connection lines
var stick_extension_ratio = 1.0  # How far the sticks extend beyond the triangle (set to 1.0 as required)
var outer_point_color = Color(0.0, 0.0, 0.0, 1.0)  # Black color for outer intersection points
var visible_line_ratio = 0.7  # How much of the horizontal line is visible (70%)
var gap_dist_global = 0.0  # Distance from visible endpoint to black circle (will be calculated)

# Position and size controls
var position_x_offset = 0.0  # Horizontal offset from center (positive = right, negative = left)
var position_y_offset = 0.0  # Vertical offset (positive = down, negative = up)
var vertical_position_ratio = 0.3  # Position from top (0.0 = top, 0.5 = middle, 1.0 = bottom)

# Background effects
var noise = FastNoiseLite.new()
var time = 0.0
var subtle_movement = false  # Disabled animation by default
var animation_speed = 0.01  # Further reduced from 0.02
var redraw_interval = 1.0  # Only redraw every second (increased from 0.5)
var time_since_last_redraw = 0.0

# Pit class to hold information about each pit in the triangular grid
class Pit:
	var position: Vector2  # World position of the pit
	var grid_x: int  # Column index within the row
	var grid_y: int  # Row index
	var player: int = 0  # 0 = empty, 1-3 = player ID
	var marble: Node2D = null  # Reference to the marble node if occupied
	
	func _init(pos: Vector2, x: int, y: int):
		position = pos
		grid_x = x
		grid_y = y
	
	func is_empty() -> bool:
		return player == 0
	
	func place_marble(player_id: int, marble_node: Node2D) -> bool:
		if is_empty():
			player = player_id
			marble = marble_node
			return true
		return false
	
	func clear():
		player = 0
		marble = null
	
	func get_description() -> String:
		return "Pit(%d,%d) at (%d,%d) - %s" % [
			grid_y, 
			grid_x, 
			round(position.x), 
			round(position.y),
			"Empty" if is_empty() else "Player " + str(player)
		]

# Array to store pits organized by row
var pits = []

func _ready():
	# Initialize noise for background
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.frequency = 0.001  # Further reduced from 0.002 for even smoother noise
	noise.fractal_octaves = 2  # Further reduced from 3 for even less detail/flickering
	noise.fractal_lacunarity = 1.5  # Further reduced from 1.8
	noise.fractal_gain = 0.3  # Further reduced from 0.4
	
	# Draw once at startup
	queue_redraw()
	
	# Wait a short time for everything to initialize
	await get_tree().create_timer(0.5).timeout
	
	# Initialize the pits based on the intersection points
	initialize_pits()

func _process(delta):
	if subtle_movement:
		time_since_last_redraw += delta
		time += delta * animation_speed  # Much slower movement
		
		# Only redraw occasionally to reduce flickering
		if time_since_last_redraw >= redraw_interval:
			noise.offset.x = time * 2.0  # Further reduced from 5.0
			noise.offset.y = time * 1.0  # Further reduced from 2.0
			queue_redraw()
			time_since_last_redraw = 0.0

# Function to draw an intersection point
# pos: Vector2 position of the intersection
# is_outer: whether this is an outer point (at the end of a stick)
func draw_intersection(pos, is_outer = false):
	if is_outer:
		# Draw filled black circle for outer points
		draw_circle(pos, intersection_radius, outer_point_color)
	else:
		# Draw filled white circle for inner points
		draw_circle(pos, intersection_radius, intersection_fill_color)
		
		# Draw circle outline
		draw_circle_arc(pos, intersection_radius, 0, 360, point_color)
		
		# Check if this is a point in the bottom row
		var viewport_size = get_viewport_rect().size
		var _center_x = viewport_size.x / 2 + position_x_offset
		var center_y = viewport_size.y * vertical_position_ratio + position_y_offset
		var scaled_width = base_width * scale_factor
		var y_size = scaled_width * height_to_width_ratio
		var rows = 6
		var row_height = y_size / (rows - 1)  # Distance between rows
		
		# Calculate the y-position of the bottom row
		var bottom_row_y = center_y + (rows - 1) * row_height
		
		# Skip drawing black circles and connections for the bottom row
		if abs(pos.y - bottom_row_y) < 1.0:  # Using a small threshold for floating-point comparison
			return
		
		# Draw two black circles above the white circle
		# Calculate the distance between white circles (use standard_distance)
		var bottom_row_distance = scaled_width / 5.0  # Distance between points in bottom row (6 points)
		
		# Calculate vertical offset for the black circles (same as row height)
		var vertical_offset = row_height
		
		# Calculate horizontal offset for the black circles
		# The distance between the two black circles should equal the distance between white circles
		var horizontal_offset = bottom_row_distance / 2.0
		
		# Calculate positions for the two black circles
		var left_black_pos = Vector2(pos.x - horizontal_offset, pos.y - vertical_offset)
		var right_black_pos = Vector2(pos.x + horizontal_offset, pos.y - vertical_offset)
		
		# Draw the two black circles
		draw_circle(left_black_pos, intersection_radius, outer_point_color)
		draw_circle(right_black_pos, intersection_radius, outer_point_color)
		
		# Draw lines from the white circle to the black circles above
		# Use the same gap distance as for other lines
		draw_line_with_gap(pos, left_black_pos, gap_dist_global, grid_color, connection_width)
		draw_line_with_gap(pos, right_black_pos, gap_dist_global, grid_color, connection_width)

# Helper function to draw circle outline
func draw_circle_arc(center, radius, angle_from, angle_to, color):
	var nb_points = 32
	var points_arc = PackedVector2Array()
	
	for i in range(nb_points + 1):
		var angle_point = deg_to_rad(angle_from + i * (angle_to - angle_from) / nb_points)
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)
	
	for index_point in range(nb_points):
		draw_line(points_arc[index_point], points_arc[index_point + 1], color, 1)

# Function to draw a smooth line with antialiasing
func draw_smooth_line(start_point, end_point, color, width):
	# Use draw_line with antialiasing
	draw_line(start_point, end_point, color, width, true)  # Last parameter enables antialiasing

# Function to draw a line with a gap before reaching the endpoint
func draw_line_with_gap(start_point, end_point, gap_distance, line_color, line_width):
	var direction = (end_point - start_point).normalized()
	var total_distance = start_point.distance_to(end_point)
	
	# Calculate the visible endpoint so that the distance from it to the end point
	# is the same as the gap_distance
	# Also account for the radius of the black circle
	var visible_distance = total_distance - gap_distance - intersection_radius
	
	# Ensure we don't try to draw a negative length line
	if visible_distance <= 0:
		visible_distance = total_distance * 0.1  # Show at least a small portion
	
	var visible_end = start_point + direction * visible_distance
	
	# Draw the line with antialiasing
	draw_smooth_line(start_point, visible_end, line_color, line_width)

# Function to draw a horizontal stick
func draw_horizontal_stick(start_point, direction, stick_length):
	# Calculate the end point of the stick (horizontal)
	var stick_end = Vector2(start_point.x + direction * stick_length, start_point.y)
	
	# Draw the horizontal line (only 70% visible) with antialiasing
	var visible_end = Vector2(start_point.x + direction * stick_length * visible_line_ratio, start_point.y)
	draw_smooth_line(start_point, visible_end, grid_color, connection_width)
	
	# Calculate the gap distance (distance from visible endpoint to black circle)
	# This will be used for diagonal connections to ensure consistent gaps
	gap_dist_global = stick_length * (1.0 - visible_line_ratio)
	
	return stick_end

# Function to draw a diagonal stick
func draw_diagonal_stick(start_point, direction, stick_length):
	# Calculate the end point of the stick
	var stick_end = start_point + direction * stick_length
	
	# Draw the diagonal line (only 70% visible) with antialiasing
	var visible_end = start_point + direction * stick_length * visible_line_ratio
	draw_smooth_line(start_point, visible_end, grid_color, connection_width)
	
	return stick_end

# Draw a cool background with gradient and noise
func draw_cool_background(viewport_size):
	# Draw gradient background
	var gradient_rect = Rect2(0, 0, viewport_size.x, viewport_size.y)
	draw_rect(gradient_rect, background_color_top)
	
	# Create a very subtle gradient from top to bottom
	var gradient_points = 30  # Further reduced from 50 for better performance
	for i in range(gradient_points):
		var t = float(i) / gradient_points
		var y = viewport_size.y * t
		var color = background_color_top.lerp(background_color_bottom, t)
		var rect = Rect2(0, y, viewport_size.x, viewport_size.y / gradient_points + 1)
		draw_rect(rect, color)
	
	# Add extremely subtle noise texture overlay
	for x in range(0, int(viewport_size.x), 16):  # Further increased sampling interval from 8 to 16 pixels
		for y in range(0, int(viewport_size.y), 16):  # Further increased sampling interval for better performance
			var noise_val = noise.get_noise_2d(x, y)
			if noise_val > 0.2:  # Only draw the brightest spots (threshold increased from 0.0 to 0.2)
				var alpha = noise_val * 0.04  # Further reduced from 0.08 for extremely subtle effect
				var noise_color = Color(1, 1, 1, alpha)
				draw_rect(Rect2(x, y, 16, 16), noise_color)  # Larger rectangles (16x16 instead of 8x8)
	
	# Add just one or two extremely subtle glows
	var num_glows = 2  # Further reduced from 3
	for i in range(num_glows):
		var glow_x = viewport_size.x * (0.3 + 0.4 * randf())  # More centered
		var glow_y = viewport_size.y * (0.3 + 0.4 * randf())  # More centered
		var glow_size = viewport_size.y * (0.3 + 0.2 * randf())
		var glow_alpha = 0.01 + 0.01 * randf()  # Further reduced from 0.02-0.05 to 0.01-0.02
		
		# Draw multiple circles with decreasing opacity for a glow effect
		for j in range(5):  # Further reduced from 8
			var radius = glow_size * (1.0 - j/5.0)
			var alpha = glow_alpha * (1.0 - j/5.0)
			var glow_color = Color(1, 1, 1, alpha)
			draw_circle(Vector2(glow_x, glow_y), radius, glow_color)

# Function to draw a triangle with a grid
# x_size: width of the triangle
# height_ratio: how much taller the triangle is compared to its width
# x_pos, y_pos: coordinates of the top point of the triangle
func draw_triangle(x_size, height_ratio, x_pos, y_pos):
	# Calculate height based on the ratio
	var y_size = x_size * height_ratio
	
	# Calculate the three points of the triangle
	var triangle_top = Vector2(x_pos, y_pos)
	var triangle_bottom_left = Vector2(x_pos - x_size/2, y_pos + y_size)
	var triangle_bottom_right = Vector2(x_pos + x_size/2, y_pos + y_size)
	
	# Draw the triangle outline with antialiasing (no fill)
	draw_smooth_line(triangle_top, triangle_bottom_left, grid_color, connection_width)
	draw_smooth_line(triangle_bottom_left, triangle_bottom_right, grid_color, connection_width)
	draw_smooth_line(triangle_bottom_right, triangle_top, grid_color, connection_width)
	
	# Create a triangular grid with 6 rows
	var rows = 6
	var grid_points = []
	var stick_ends = []  # To store all stick endpoints for diagonal connections
	var all_intersections = []  # To store all intersection points (both inner and outer)
	
	# Calculate the height of each row
	var row_height = y_size / (rows - 1)
	
	# Generate points for each row
	for row in range(rows):
		var points_in_row = row + 1  # Row 0 has 1 point, row 5 has 6 points
		var row_points = []
		
		# Calculate row width (proportional to row index)
		var row_width = x_size * row / (rows - 1)
		
		# Calculate horizontal spacing
		var col_width = 0
		if points_in_row > 1:  # Avoid division by zero
			col_width = row_width / (points_in_row - 1)
		
		# Calculate row start position
		var start_x = x_pos - row_width / 2
		var current_y = y_pos + row * row_height
		
		# Create points for this row
		for col in range(points_in_row):
			var point_x = start_x + col * col_width
			var point = Vector2(point_x, current_y)
			
			# Add point to row
			row_points.append(point)
			
			# Store the intersection point
			all_intersections.append({"position": point, "is_outer": false})
		
		# Add row to grid
		grid_points.append(row_points)
		
		# Initialize stick_ends for this row
		stick_ends.append([])
	
	# Draw horizontal connections
	for row in range(rows):
		var row_points = grid_points[row]
		
		# Skip drawing horizontal connections for row 0 (the top row with only one point)
		if row != 0 and row_points.size() > 1:
			for i in range(row_points.size() - 1):
				var start = row_points[i]
				var end = row_points[i + 1]
				
				# Draw the line with antialiasing
				draw_smooth_line(start, end, grid_color, connection_width)
	
	# Draw vertical connections
	for row in range(rows - 1):
		var upper_row = grid_points[row]
		var lower_row = grid_points[row + 1]
		
		for i in range(upper_row.size()):
			var start = upper_row[i]
			var end = lower_row[i]
			
			# Draw the line with antialiasing
			draw_smooth_line(start, end, grid_color, connection_width)
	
	# Draw diagonal connections - only those that form proper triangles
	# Each triangle is formed by:
	# 1. A point in the current row
	# 2. The point directly below it in the next row
	# 3. The point to the right of that in the next row
	for row in range(rows - 1):
		var upper_row = grid_points[row]
		var lower_row = grid_points[row + 1]
		
		for i in range(upper_row.size()):
			# Only draw if we have a point to the right in the lower row
			if i + 1 < lower_row.size():
				var diagonal_start_point = upper_row[i]
				var diagonal_end_point = lower_row[i + 1]
				
				# Draw the diagonal line from top to bottom-right with antialiasing
				draw_smooth_line(diagonal_start_point, diagonal_end_point, grid_color, connection_width)
	
	# Calculate the standard distance between points in the bottom row
	# This will be used as the standard distance for horizontal sticks
	var bottom_row = grid_points[rows-1]
	var standard_distance = 0.0
	if bottom_row.size() > 1:
		standard_distance = bottom_row[1].x - bottom_row[0].x
	
	# Add horizontal sticks to the left side of the triangle
	for row in range(rows):  # Include all rows
		if row > 0:  # Skip the top level (row 0)
			var point = grid_points[row][0]  # Leftmost point in row
			var stick_end = draw_horizontal_stick(point, -1, standard_distance)  # Use standard distance
			
			# Store the stick endpoint for this row
			stick_ends[row].append({"position": stick_end, "side": "left"})
			
			# Store the outer intersection point
			all_intersections.append({"position": stick_end, "is_outer": true})
		else:
			# Add empty placeholder for the top row to maintain indexing
			stick_ends[row].append({"position": Vector2.ZERO, "side": "left"})
	
	# Add horizontal sticks to the right side of the triangle
	for row in range(rows):  # Include all rows
		if row > 0:  # Skip the top level (row 0)
			var point = grid_points[row][row]  # Rightmost point in row
			var stick_end = draw_horizontal_stick(point, 1, standard_distance)  # Use standard distance
			
			# Store the stick endpoint for this row
			stick_ends[row].append({"position": stick_end, "side": "right"})
			
			# Store the outer intersection point
			all_intersections.append({"position": stick_end, "is_outer": true})
		else:
			# Add empty placeholder for the top row to maintain indexing
			stick_ends[row].append({"position": Vector2.ZERO, "side": "right"})
	
	# Calculate diagonal directions from top point
	var _top_left_dir = (grid_points[1][0] - triangle_top).normalized()
	var _top_right_dir = (grid_points[1][1] - triangle_top).normalized()
	
	# Draw white circle at the top point (row 0)
	draw_intersection(triangle_top, false)  # Changed to false to make it white
	
	# Draw black circles for all points in row 1
	if grid_points.size() > 1:
		for point in grid_points[1]:
			draw_intersection(point, true)
			all_intersections.append({"position": point, "is_outer": true})
	
	# Add black circles horizontally to the left and right of the top point (row 0)
	if grid_points.size() > 1:
		# Calculate the horizontal distance based on the first row's spacing
		var horizontal_distance = 0.0
		if grid_points[1].size() > 1:
			horizontal_distance = grid_points[1][1].x - grid_points[1][0].x
		
		# Create left black circle
		var left_black_circle = Vector2(triangle_top.x - horizontal_distance, triangle_top.y)
		draw_intersection(left_black_circle, true)
		all_intersections.append({"position": left_black_circle, "is_outer": true})
		
		# Create right black circle
		var right_black_circle = Vector2(triangle_top.x + horizontal_distance, triangle_top.y)
		draw_intersection(right_black_circle, true)
		all_intersections.append({"position": right_black_circle, "is_outer": true})
		
		# Draw sticks from the top point to the black circles
		draw_line_with_gap(triangle_top, left_black_circle, gap_dist_global, grid_color, connection_width)
		draw_line_with_gap(triangle_top, right_black_circle, gap_dist_global, grid_color, connection_width)
		
		# Add diagonal connections from the black circles to row 1 points
		if grid_points[1].size() > 0:
			# Connect left black circle to leftmost point in row 1
			draw_line_with_gap(grid_points[1][0], left_black_circle, gap_dist_global, grid_color, connection_width)
			
			# Connect right black circle to rightmost point in row 1
			draw_line_with_gap(grid_points[1][grid_points[1].size()-1], right_black_circle, gap_dist_global, grid_color, connection_width)
	
	# Now draw diagonal connections from outer grid points to the top point
	for row in range(1, rows):  # Start from row 1 (second row) since row 0 has no layer above
		# Skip the bottom row (row 5)
		if row == rows - 1:
			continue
			
		if row == 1:  # For row 1, connect to the top point
			var _left_point = grid_points[row][0]  # Leftmost point in row 1
			var _right_point = grid_points[row][row]  # Rightmost point in row 1
			
			# Draw diagonal connections to the top point
			draw_line_with_gap(_left_point, triangle_top, gap_dist_global, grid_color, connection_width)
			draw_line_with_gap(_right_point, triangle_top, gap_dist_global, grid_color, connection_width)
			
			# Add direct connection from middle point in row 1 to the top point
			if grid_points[row].size() > 2:  # Make sure there's a middle point
				var middle_point = grid_points[row][1]  # Middle point in row 1
				draw_line_with_gap(middle_point, triangle_top, gap_dist_global, grid_color, connection_width)
			
			# Add diagonal connections from row 1 points to the stick endpoints at the same level
			if stick_ends[row][0]["position"] != Vector2.ZERO:  # Left stick endpoint
				draw_line_with_gap(_left_point, stick_ends[row][0]["position"], gap_dist_global, grid_color, connection_width)
			
			if stick_ends[row][1]["position"] != Vector2.ZERO:  # Right stick endpoint
				draw_line_with_gap(_right_point, stick_ends[row][1]["position"], gap_dist_global, grid_color, connection_width)
		elif row == 2:  # For row 2, connect to the points in row 1
			# Connect each point in row 2 to the corresponding points in row 1
			for i in range(grid_points[row].size()):
				# Connect to the point directly above (if exists)
				if i < grid_points[row-1].size():
					var above_point = grid_points[row-1][i]
					draw_line_with_gap(grid_points[row][i], above_point, gap_dist_global, grid_color, connection_width)
			
			# Connect left edge points to the left stick endpoint in the row above
			var left_point = grid_points[row][0]  # Leftmost point in row 2
			var above_left_stick = stick_ends[row-1][0]["position"]  # Left stick endpoint in row above
			
			# Draw diagonal connection
			draw_line_with_gap(left_point, above_left_stick, gap_dist_global, grid_color, connection_width)
			
			# Connect right edge points to the right stick endpoint in the row above
			var right_point = grid_points[row][row]  # Rightmost point in row 2
			var above_right_stick = stick_ends[row-1][1]["position"]  # Right stick endpoint in row above
			
			# Draw diagonal connection
			draw_line_with_gap(right_point, above_right_stick, gap_dist_global, grid_color, connection_width)
		else:
			# Skip the bottom row (row 5)
			if row == rows - 1:
				continue
				
			# For rows 3 and 4, connect to the stick endpoints in the row above
			# Connect left edge points to the left stick endpoint in the row above
			var left_point = grid_points[row][0]  # Leftmost point in current row
			var above_left_stick = stick_ends[row-1][0]["position"]  # Left stick endpoint in row above
			
			# Skip drawing diagonal sticks to external points for the bottom row
			if row != rows - 1:
				# Draw diagonal connection
				draw_line_with_gap(left_point, above_left_stick, gap_dist_global, grid_color, connection_width)
			
				# Connect right edge points to the right stick endpoint in the row above
				var right_point = grid_points[row][row]  # Rightmost point in current row
				var above_right_stick = stick_ends[row-1][1]["position"]  # Right stick endpoint in row above
				
				# Draw diagonal connection
				draw_line_with_gap(right_point, above_right_stick, gap_dist_global, grid_color, connection_width)
	
	# Draw all intersection points AFTER drawing all lines
	for intersection in all_intersections:
		draw_intersection(intersection["position"], intersection["is_outer"])

func _draw():
	# Get viewport dimensions to center the triangle
	var viewport_size = get_viewport_rect().size
	
	# Calculate center position with offsets
	var center_x = viewport_size.x / 2 + position_x_offset
	var center_y = viewport_size.y * vertical_position_ratio + position_y_offset
	
	# Draw cool background
	draw_cool_background(viewport_size)
	
	# Calculate the actual width using the scale factor
	var scaled_width = base_width * scale_factor
	
	# Draw the triangle in the middle of the screen
	draw_triangle(scaled_width, height_to_width_ratio, center_x, center_y)

# Function to get the position of a grid point by its coordinates
# This is used by other scripts to place objects at grid points
func get_grid_point_position(grid_x, grid_y):
	# Get viewport dimensions to calculate the center position
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2 + position_x_offset
	var center_y = viewport_size.y * vertical_position_ratio + position_y_offset
	
	# Calculate the actual width using the scale factor
	var scaled_width = base_width * scale_factor
	var y_size = scaled_width * height_to_width_ratio
	
	# Calculate the height of each row
	var rows = 6
	var row_height = y_size / (rows - 1)
	
	# Make sure grid_y is within bounds
	if grid_y < 0 or grid_y >= rows:
		return Vector2.ZERO
	
	# Calculate row width (proportional to row index)
	var row_width = scaled_width * grid_y / (rows - 1)
	
	# Calculate number of points in this row
	var points_in_row = grid_y + 1
	
	# Make sure grid_x is within bounds
	if grid_x < 0 or grid_x >= points_in_row:
		return Vector2.ZERO
	
	# Calculate horizontal spacing
	var col_width = 0
	if points_in_row > 1:
		col_width = row_width / (points_in_row - 1)
	
	# Calculate position
	var start_x = center_x - row_width / 2
	var current_y = center_y + grid_y * row_height
	var point_x = start_x + grid_x * col_width
	
	return Vector2(point_x, current_y)

# Function to get all intersection points (both inner and outer)
# This is used by other scripts to place objects at all intersection points
func get_all_intersection_points():
	# Get viewport dimensions to center the triangle
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2 + position_x_offset
	var center_y = viewport_size.y * vertical_position_ratio + position_y_offset
	
	# Calculate the actual width using the scale factor
	var scaled_width = base_width * scale_factor
	
	# Call draw_triangle but only to collect intersection points without drawing
	return _collect_intersection_points(scaled_width, height_to_width_ratio, center_x, center_y)

# Function to collect all intersection points without drawing
func _collect_intersection_points(x_size, height_ratio, x_pos, y_pos):
	# Calculate height based on the ratio
	var y_size = x_size * height_ratio
	
	# Calculate the three points of the triangle
	var _triangle_top = Vector2(x_pos, y_pos)
	
	# Create a triangular grid with 6 rows
	var rows = 6
	var grid_points = []
	var stick_ends = []  # To store all stick endpoints for diagonal connections
	var all_intersections = []  # To store all intersection points (both inner and outer)
	var inner_intersections = []  # To store only the inner points (21 total)
	
	# Calculate the height of each row
	var row_height = y_size / (rows - 1)
	
	# Generate points for each row
	for row in range(rows):
		var points_in_row = row + 1  # Row 0 has 1 point, row 5 has 6 points
		var row_points = []
		
		# Calculate row width (proportional to row index)
		var row_width = x_size * row / (rows - 1)
		
		# Calculate horizontal spacing
		var col_width = 0
		if points_in_row > 1:  # Avoid division by zero
			col_width = row_width / (points_in_row - 1)
		
		# Calculate row start position
		var start_x = x_pos - row_width / 2
		var current_y = y_pos + row * row_height
		
		# Create points for this row
		for col in range(points_in_row):
			var point_x = start_x + col * col_width
			var point = Vector2(point_x, current_y)
			
			# Add point to row
			row_points.append(point)
			
			# Store the intersection point
			all_intersections.append({"position": point, "is_outer": false, "grid_x": col, "grid_y": row})
			
			# Only add to inner_intersections if it's not already there
			var already_exists = false
			for existing_point in inner_intersections:
				if existing_point["position"].distance_to(point) < 1.0:  # Small threshold for floating point comparison
					already_exists = true
					break
			
			if not already_exists:
				inner_intersections.append({"position": point, "is_outer": false, "grid_x": col, "grid_y": row})
		
		# Add row to grid
		grid_points.append(row_points)
		
		# Initialize stick_ends for this row
		stick_ends.append([])
	
	# Calculate the standard distance between points in the bottom row
	# This will be used as the standard distance for horizontal sticks
	var bottom_row = grid_points[rows-1]
	var standard_distance = 0.0
	if bottom_row.size() > 1:
		standard_distance = bottom_row[1].x - bottom_row[0].x
	
	# Add horizontal sticks to the left side of the triangle
	for row in range(rows):  # Include all rows
		if row > 0:  # Skip the top level (row 0)
			var point = grid_points[row][0]  # Leftmost point in row
			var stick_end = Vector2(point.x - standard_distance, point.y)  # Calculate without drawing
			
			# Store the stick endpoint for this row
			stick_ends[row].append({"position": stick_end, "side": "left"})
			
			# Store the outer intersection point
			all_intersections.append({"position": stick_end, "is_outer": true, "grid_x": -1, "grid_y": row})
		else:
			# Add empty placeholder for the top row to maintain indexing
			stick_ends[row].append({"position": Vector2.ZERO, "side": "left"})
	
	# Add horizontal sticks to the right side of the triangle
	for row in range(rows):  # Include all rows
		if row > 0:  # Skip the top level (row 0)
			var point = grid_points[row][row]  # Rightmost point in row
			var stick_end = Vector2(point.x + standard_distance, point.y)  # Calculate without drawing
			
			# Store the stick endpoint for this row
			stick_ends[row].append({"position": stick_end, "side": "right"})
			
			# Store the outer intersection point
			all_intersections.append({"position": stick_end, "is_outer": true, "grid_x": -1, "grid_y": row})
		else:
			# Add empty placeholder for the top row to maintain indexing
			stick_ends[row].append({"position": Vector2.ZERO, "side": "right"})
	
	# Now draw diagonal connections from outer grid points to the top point
	for row in range(1, rows):  # Start from row 1 (second row) since row 0 has no layer above
		# Skip the bottom row (row 5)
		if row == rows - 1:
			continue
			
		if row == 1:  # For row 1, connect to the top point instead of black circles
			var _left_point = grid_points[row][0]  # Leftmost point in row 1
			var _right_point = grid_points[row][row]  # Rightmost point in row 1
			
			# We don't need to add these points again as they're already in inner_intersections
			# from the earlier loop that generated all grid points
	
	# Print the number of inner intersection points (should be 21)
	print("Number of inner intersection points: ", inner_intersections.size())
	
	# For debugging purposes, verify the count is correct
	if inner_intersections.size() != 21:
		print("WARNING: Expected 21 inner points, but found ", inner_intersections.size())
		
		# Count points per row for debugging
		var points_per_row = {}
		for point in inner_intersections:
			var row = point["grid_y"]
			if not points_per_row.has(row):
				points_per_row[row] = 0
			points_per_row[row] += 1
		
		# Print the distribution
		for row in points_per_row:
			print("Row ", row, " has ", points_per_row[row], " points")
	
	# Return inner_intersections instead of all_intersections to ensure only 21 pits
	return inner_intersections

# Initialize the pits based on the intersection points
func initialize_pits():
	# Clear any existing pits
	pits.clear()
	
	# Get all intersection points
	var all_intersections = get_all_intersection_points()
	
	# Create a temporary array to hold all pits
	var all_pits = []
	
	# Create Pit objects for each inner intersection
	for intersection in all_intersections:
		if not intersection["is_outer"]:
			# Create a new pit
			var grid_coords = find_grid_coordinates(intersection["position"])
			var new_pit = Pit.new(intersection["position"], grid_coords.x, grid_coords.y)
			all_pits.append(new_pit)
	
	# Organize pits by row (triangular row)
	# We expect 6 rows: row 0 has 1 pit, row 1 has 2 pits, etc.
	for row_index in range(6):
		var row_pits = []
		
		# Find all pits for this row
		for pit in all_pits:
			if pit.grid_y == row_index:
				row_pits.append(pit)
		
		# Sort the pits by column index within the row
		row_pits.sort_custom(func(a, b): return a.grid_x < b.grid_x)
		
		# Add the row to the pits array
		pits.append(row_pits)
	
	# Print the organized pits
	organize_and_print_pit_positions()

# Function to organize pit positions into 6 arrays (one per row) and print their coordinates
func organize_and_print_pit_positions():
	print("\n=== Triangular Grid Pit Positions ===")
	
	for row_index in range(pits.size()):
		var row = pits[row_index]
		print("Row ", row_index, " (", row.size(), " pits):")
		
		for pit in row:
			print("  " + pit.get_description())
	
	print("=== End of Pit Positions ===\n")
	
	# Return the organized pits for potential use elsewhere
	return pits

# Function to get a pit at specific grid coordinates
func get_pit(row: int, col: int) -> Pit:
	if row >= 0 and row < pits.size():
		var row_pits = pits[row]
		for pit in row_pits:
			if pit.grid_x == col:
				return pit
	return null

# Function to place a marble at a specific pit
func place_marble_at_pit(row: int, col: int, player_id: int, marble_node: Node2D) -> bool:
	var pit = get_pit(row, col)
	if pit and pit.is_empty():
		return pit.place_marble(player_id, marble_node)
	return false

# Function to check if a pit is empty
func is_pit_empty(row: int, col: int) -> bool:
	var pit = get_pit(row, col)
	return pit != null and pit.is_empty()

# Function to get all empty pits
func get_empty_pits() -> Array:
	var empty_pits = []
	for row in pits:
		for pit in row:
			if pit.is_empty():
				empty_pits.append(pit)
	return empty_pits

# Function to get all pits owned by a specific player
func get_player_pits(player_id: int) -> Array:
	var player_pits = []
	for row in pits:
		for pit in row:
			if pit.player == player_id:
				player_pits.append(pit)
	return player_pits

# Find grid coordinates for a world position
func find_grid_coordinates(world_pos: Vector2) -> Vector2i:
	# This is a simplified version - in a real game you'd have a more accurate conversion
	# based on your grid layout
	
	# Find the closest intersection point
	var _closest_point = Vector2.ZERO
	var closest_distance = INF
	var closest_index = -1
	
	var all_intersections = get_all_intersection_points()
	
	for i in range(all_intersections.size()):
		var intersection = all_intersections[i]
		var distance = intersection["position"].distance_to(world_pos)
		
		if distance < closest_distance:
			closest_distance = distance
			_closest_point = intersection["position"]
			closest_index = i
	
	# Calculate the grid coordinates based on the index
	# This is a simplified approach - you'd need to adjust based on your actual grid layout
	var row = 0
	var col = 0
	
	# Count inner points to find the row and column
	var inner_count = 0
	for i in range(all_intersections.size()):
		if not all_intersections[i]["is_outer"]:
			if i == closest_index:
				# Convert inner_count to row and column
				# For a triangular grid with 1 point in row 0, 2 in row 1, etc.
				var total = 0
				row = 0
				while total + row + 1 <= inner_count:
					total += row + 1
					row += 1
				
				col = inner_count - total
				break
			inner_count += 1
	
	return Vector2i(col, row)
