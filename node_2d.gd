extends Node2D

# Triangle configuration
var base_width = 200.0  # Base width of the triangle in pixels
var scale_factor = 1.2  # Scale factor to adjust the overall size
var height_to_width_ratio = 1.8  # How much taller the triangle is compared to its width
var grid_color = Color(0.7, 0.7, 0.7, 1.0)  # Light gray color for the grid
var point_color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray color for the points
var triangle_color = Color(0.9, 0.9, 0.9, 0.3)  # Light gray with opacity for triangle fill
var intersection_fill_color = Color(1.0, 1.0, 1.0, 1.0)  # White color for intersection fill
var intersection_radius = 5.0  # Radius of the intersection points (increased from 3.0)
var connection_width = 1.5  # Width of the connection lines

func _ready():
	# Draw once at startup
	queue_redraw()

func _process(_delta):
	# No continuous redraw
	pass

# Function to draw an intersection point
# position: Vector2 position of the intersection
func draw_intersection(position):
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

# Function to draw a triangle with a grid
# x_size: width of the triangle
# height_ratio: how much taller the triangle is compared to its width
# x_pos, y_pos: coordinates of the top point of the triangle
func draw_triangle(x_size, height_ratio, x_pos, y_pos):
	# Calculate height based on the ratio
	var y_size = x_size * height_ratio
	
	# Calculate the three points of the triangle
	var top_point = Vector2(x_pos, y_pos)
	var bottom_left = Vector2(x_pos - x_size/2, y_pos + y_size)
	var bottom_right = Vector2(x_pos + x_size/2, y_pos + y_size)
	
	# Draw the filled triangle
	var triangle = PackedVector2Array([top_point, bottom_left, bottom_right])
	draw_colored_polygon(triangle, triangle_color)
	
	# Draw the triangle outline
	draw_line(top_point, bottom_left, grid_color, connection_width)
	draw_line(bottom_left, bottom_right, grid_color, connection_width)
	draw_line(bottom_right, top_point, grid_color, connection_width)
	
	# Draw the corner points
	draw_intersection(top_point)
	draw_intersection(bottom_left)
	draw_intersection(bottom_right)
	
	# Create a triangular grid with 6 rows
	var rows = 6
	var grid_points = []
	
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
	
	# Draw diagonal connections
	for row in range(rows - 1):
		var upper_row = grid_points[row]
		var lower_row = grid_points[row + 1]
		
		for i in range(upper_row.size()):
			if i + 1 < lower_row.size():
				var start = upper_row[i]
				var end = lower_row[i + 1]
				
				# Draw the line
				draw_line(start, end, grid_color, connection_width)

func _draw():
	# Get viewport dimensions to center the triangle
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2
	var center_y = viewport_size.y / 5  # Position it higher on the screen (1/5 instead of 1/4)
	
	# Calculate the actual width using the scale factor
	var scaled_width = base_width * scale_factor
	
	# Draw the triangle in the middle of the screen
	draw_triangle(scaled_width, height_to_width_ratio, center_x, center_y)
