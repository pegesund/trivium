extends Node2D

# Radius of the circle
var radius: float = 50.0
# Initial position of the circle
var circle_position: Vector2 = Vector2(100, 100)
# Speed of the circle
var speed: float = 100.0  # pixels per second
# Direction of movement (1 for right, -1 for left)
var direction: int = 1

func _ready():
	print("Ready function called")
	# Schedule the _draw method to be called
	queue_redraw()

func _process(delta):
	print("Process function called")
	# Move the circle
	circle_position.x += speed * delta * direction
	
	# Get the viewport width
	var viewport_width = get_viewport_rect().size.x
	
	# Check for boundary collision and reverse direction if needed
	if circle_position.x - radius < 0:
		circle_position.x = radius  # Correct position
		direction = 1  # Move right
	elif circle_position.x + radius > viewport_width:
		circle_position.x = viewport_width - radius  # Correct position
		direction = -1  # Move left
	
	# Continuously force a redraw
	queue_redraw()

func _draw():
	print("Draw function called")
	# Use the correct method to set the drawing color
	var color = Color(1, 0, 0, 1)  # Ensure the alpha is set to 1
	
	# Draw the circle at the updated position
	draw_circle(circle_position, radius, color)
