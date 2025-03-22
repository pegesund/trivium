extends Node2D

# Triangle configuration
var base_width = 200.0  # Base width of the triangle in pixels
var scale_factor = 1.2  # Scale factor to adjust the overall size
var height_to_width_ratio = 1.0  # How much taller the triangle is compared to its width (set to 1.8 as required)
var grid_color = Color(0.7, 0.7, 0.7, 1.0)  # Light gray color for the grid
var point_color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray color for the points
var triangle_color = Color(0.9, 0.9, 0.9, 0.3)  # Light gray with opacity for triangle fill
var intersection_fill_color = Color(1.0, 1.0, 1.0, 1.0)  # White color for intersection fill
var intersection_radius = 5.0  # Radius of the intersection points (increased from 3.0)
var connection_width = 1.5  # Width of the connection lines
var stick_extension_ratio = 1.0  # How far the sticks extend beyond the triangle (set to 1.0 as required)
var outer_point_color = Color(0.0, 0.0, 0.0, 1.0)  # Black color for outer intersection points
var visible_line_ratio = 0.7  # How much of the horizontal line is visible (70%)
var gap_distance = 0.0  # Distance from visible endpoint to black circle (will be calculated)

func _ready():
	# Draw once at startup
	queue_redraw()

func _process(_delta):
	# No continuous redraw
	pass

# Function to draw an intersection point
# position: Vector2 position of the intersection
# is_outer: whether this is an outer point (at the end of a stick)
func draw_intersection(position, is_outer = false):
	if is_outer:
		# Draw filled black circle for outer points
		draw_circle(position, intersection_radius, outer_point_color)
	else:
		# Draw filled white circle
		draw_circle(position, intersection_radius, intersection_fill_color)
		# Draw circle outline
		draw_circle_arc(position, intersection_radius, 0, 360, point_color)

# Helper function to draw circle outline
func draw_circle_arc(center, radius, angle_from, angle_to, color):
	var nb_points = 32
	var points_arc = PackedVector2Array()
	
	for i in range(nb_points + 1):
		var angle_point = deg_to_rad(angle_from + i * (angle_to - angle_from) / nb_points)
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)
	
	for index_point in range(nb_points):
		draw_line(points_arc[index_point], points_arc[index_point + 1], color, 1)

# Function to draw a horizontal stick
func draw_horizontal_stick(start_point, direction, stick_length):
	# Calculate the end point of the stick (horizontal)
	var stick_end = Vector2(start_point.x + direction * stick_length, start_point.y)
	
	# Draw the horizontal line (only 70% visible)
	var visible_end = Vector2(start_point.x + direction * stick_length * visible_line_ratio, start_point.y)
	draw_line(start_point, visible_end, grid_color, connection_width)
	
	# Calculate the gap distance (distance from visible endpoint to black circle)
	# This will be used for diagonal connections to ensure consistent gaps
	gap_distance = stick_length * (1.0 - visible_line_ratio)
	
	# Draw the black point at the end
	draw_intersection(stick_end, true)
	
	return stick_end

# Function to draw a diagonal stick
func draw_diagonal_stick(start_point, direction, stick_length):
	# Calculate the end point of the stick
	var stick_end = start_point + direction * stick_length
	
	# Draw the diagonal line (only 70% visible)
	var visible_end = start_point + direction * stick_length * visible_line_ratio
	draw_line(start_point, visible_end, grid_color, connection_width)
	
	# Draw the black point at the end
	draw_intersection(stick_end, true)
	
	return stick_end

# Function to draw a diagonal line from a point to a target black point
# The visible endpoint will be at the same distance from the black circle as horizontal lines
func draw_diagonal_connection(start_point, end_point):
	var direction = (end_point - start_point).normalized()
	var total_distance = start_point.distance_to(end_point)
	
	# Calculate the visible endpoint so that the distance from it to the black circle
	# is the same as the gap_distance calculated for horizontal sticks
	# Also account for the radius of the black circle
	var visible_distance = total_distance - gap_distance - intersection_radius
	
	# Ensure we don't try to draw a negative length line
	if visible_distance <= 0:
		visible_distance = total_distance * 0.1  # Show at least a small portion
	
	var visible_end = start_point + direction * visible_distance
	
	# Draw the line
	draw_line(start_point, visible_end, grid_color, connection_width)

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
	
	# Draw the filled triangle
	var triangle = PackedVector2Array([triangle_top, triangle_bottom_left, triangle_bottom_right])
	draw_colored_polygon(triangle, triangle_color)
	
	# Draw the triangle outline
	draw_line(triangle_top, triangle_bottom_left, grid_color, connection_width)
	draw_line(triangle_bottom_left, triangle_bottom_right, grid_color, connection_width)
	draw_line(triangle_bottom_right, triangle_top, grid_color, connection_width)
	
	# Create a triangular grid with 6 rows
	var rows = 6
	var grid_points = []
	var stick_ends = []  # To store all stick endpoints for diagonal connections
	
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
			
			# Draw the intersection point
			draw_intersection(point)
		
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
			
			# Draw the line
			draw_line(start, end, grid_color, connection_width)
	
	# Draw vertical connections
	for row in range(rows - 1):
		var upper_row = grid_points[row]
		var lower_row = grid_points[row + 1]
		
		for i in range(upper_row.size()):
			var start = upper_row[i]
			var end = lower_row[i]
			
			# Draw the line
			draw_line(start, end, grid_color, connection_width)
	
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
				
				# Draw the diagonal line from top to bottom-right
				draw_line(diagonal_start_point, diagonal_end_point, grid_color, connection_width)
	
	# Add horizontal sticks to the left side of the triangle
	for row in range(rows):  # Include all rows
		var points_in_row = row + 1  # Row 0 has 1 point, row 5 has 6 points
		var row_width = x_size * row / (rows - 1)
		var col_width = row_width / (points_in_row - 1) if points_in_row > 1 else 0
		var stick_length = col_width * 1.5
		
		var point = grid_points[row][0]  # Leftmost point in row
		var stick_end = draw_horizontal_stick(point, -1, stick_length)  # -1 for left direction
		
		# Store the stick endpoint for this row
		stick_ends[row].append({"position": stick_end, "side": "left"})
	
	# Add horizontal sticks to the right side of the triangle
	for row in range(rows):  # Include all rows
		var points_in_row = row + 1  # Row 0 has 1 point, row 5 has 6 points
		var row_width = x_size * row / (rows - 1)
		var col_width = row_width / (points_in_row - 1) if points_in_row > 1 else 0
		var stick_length = col_width * 1.5
		
		var point = grid_points[row][row]  # Rightmost point in row
		var stick_end = draw_horizontal_stick(point, 1, stick_length)  # 1 for right direction
		
		# Store the stick endpoint for this row
		stick_ends[row].append({"position": stick_end, "side": "right"})
	
	# Calculate diagonal directions from top point
	var top_left_dir = (grid_points[1][0] - triangle_top).normalized()
	var top_right_dir = (grid_points[1][1] - triangle_top).normalized()
	
	# Calculate the positions for the two black circles above the top point
	var top_row_height = row_height * 0.8  # Slightly shorter than regular row height
	
	# Calculate positions for the black circles
	var top_left_black = triangle_top - top_left_dir * top_row_height
	var top_right_black = triangle_top - top_right_dir * top_row_height
	
	# Draw the black circles
	draw_intersection(top_left_black, true)
	draw_intersection(top_right_black, true)
	
	# Draw diagonal connections from the top point to the black circles
	# Use the same gap_distance principle as for other connections
	draw_diagonal_connection(triangle_top, top_left_black)
	draw_diagonal_connection(triangle_top, top_right_black)
	
	# Now draw diagonal connections from outer grid points to black points in the layer above
	for row in range(1, rows):  # Start from row 1 (second row) since row 0 has no layer above
		# Connect left edge points to the left stick endpoint in the row above
		if row < rows - 1:  # Skip the bottom row for left edge
			var left_point = grid_points[row][0]  # Leftmost point in current row
			var above_left_stick = stick_ends[row-1][0]["position"]  # Left stick endpoint in row above
			
			# Draw diagonal connection
			draw_diagonal_connection(left_point, above_left_stick)
		
		# Connect right edge points to the right stick endpoint in the row above
		if row < rows - 1:  # Skip the bottom row for right edge
			var right_point = grid_points[row][row]  # Rightmost point in current row
			var above_right_stick = stick_ends[row-1][1]["position"]  # Right stick endpoint in row above
			
			# Draw diagonal connection
			draw_diagonal_connection(right_point, above_right_stick)
	
	# Add diagonal connections from the bottom row's outer white points
	var bottom_row = grid_points[rows-1]  # Get the bottom row
	
	# Connect leftmost point in bottom row to the left stick endpoint in the row above
	var bottom_left_point = bottom_row[0]
	var above_left_stick = stick_ends[rows-2][0]["position"]
	draw_diagonal_connection(bottom_left_point, above_left_stick)
	
	# Connect rightmost point in bottom row to the right stick endpoint in the row above
	var bottom_right_point = bottom_row[bottom_row.size()-1]
	var above_right_stick = stick_ends[rows-2][1]["position"]
	draw_diagonal_connection(bottom_right_point, above_right_stick)

func _draw():
	# Get viewport dimensions to center the triangle
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2
	var center_y = viewport_size.y / 5  # Position it higher on the screen (1/5 instead of 1/4)
	
	# Calculate the actual width using the scale factor
	var scaled_width = base_width * scale_factor
	
	# Draw the triangle in the middle of the screen
	draw_triangle(scaled_width, height_to_width_ratio, center_x, center_y)
