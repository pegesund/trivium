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
		# Draw filled white circle
		draw_circle(pos, intersection_radius, intersection_fill_color)
		# Draw circle outline
		draw_circle_arc(pos, intersection_radius, 0, 360, point_color)

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
		var point = grid_points[row][0]  # Leftmost point in row
		var stick_end = draw_horizontal_stick(point, -1, standard_distance)  # Use standard distance
		
		# Store the stick endpoint for this row
		stick_ends[row].append({"position": stick_end, "side": "left"})
		
		# Store the outer intersection point
		all_intersections.append({"position": stick_end, "is_outer": true})
	
	# Add horizontal sticks to the right side of the triangle
	for row in range(rows):  # Include all rows
		var point = grid_points[row][row]  # Rightmost point in row
		var stick_end = draw_horizontal_stick(point, 1, standard_distance)  # Use standard distance
		
		# Store the stick endpoint for this row
		stick_ends[row].append({"position": stick_end, "side": "right"})
		
		# Store the outer intersection point
		all_intersections.append({"position": stick_end, "is_outer": true})
	
	# Calculate diagonal directions from top point
	var top_left_dir = (grid_points[1][0] - triangle_top).normalized()
	var top_right_dir = (grid_points[1][1] - triangle_top).normalized()
	
	# Calculate the positions for the two black circles above the top point
	# Use the same standard distance for consistency
	var top_left_black = triangle_top - top_left_dir * standard_distance
	var top_right_black = triangle_top - top_right_dir * standard_distance
	
	# Store the black circles for later drawing
	all_intersections.append({"position": top_left_black, "is_outer": true})
	all_intersections.append({"position": top_right_black, "is_outer": true})
	
	# Draw diagonal connections from the top point to the black circles
	# Use the same gap_distance principle as for other connections
	draw_line_with_gap(triangle_top, top_left_black, gap_dist_global, grid_color, connection_width)
	draw_line_with_gap(triangle_top, top_right_black, gap_dist_global, grid_color, connection_width)
	
	# Now draw diagonal connections from outer grid points to black points in the layer above
	for row in range(1, rows):  # Start from row 1 (second row) since row 0 has no layer above
		# Connect left edge points to the left stick endpoint in the row above
		if row < rows - 1:  # Skip the bottom row for left edge
			var left_point = grid_points[row][0]  # Leftmost point in current row
			var above_left_stick = stick_ends[row-1][0]["position"]  # Left stick endpoint in row above
			
			# Draw diagonal connection
			draw_line_with_gap(left_point, above_left_stick, gap_dist_global, grid_color, connection_width)
		
		# Connect right edge points to the right stick endpoint in the row above
		if row < rows - 1:  # Skip the bottom row for right edge
			var right_point = grid_points[row][row]  # Rightmost point in current row
			var above_right_stick = stick_ends[row-1][1]["position"]  # Right stick endpoint in row above
			
			# Draw diagonal connection
			draw_line_with_gap(right_point, above_right_stick, gap_dist_global, grid_color, connection_width)
	
	# Add diagonal connections from the bottom row's outer white points
	var bottom_left_point = bottom_row[0]
	var bottom_left_above_stick = stick_ends[rows-2][0]["position"]  
	draw_line_with_gap(bottom_left_point, bottom_left_above_stick, gap_dist_global, grid_color, connection_width)
	
	# Connect rightmost point in bottom row to the right stick endpoint in the row above
	var bottom_right_point = bottom_row[bottom_row.size()-1]
	var bottom_right_above_stick = stick_ends[rows-2][1]["position"]
	draw_line_with_gap(bottom_right_point, bottom_right_above_stick, gap_dist_global, grid_color, connection_width)
	
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
