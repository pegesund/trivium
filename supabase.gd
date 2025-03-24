extends Node

var supabase

func _ready():
	# Initialize Supabase connection
	supabase = load("res://addons/supabase/Supabase/supabase.gd").new()
	supabase.load_config()

	
	# Add as a child to keep it in the scene tree
	add_child(supabase)
	print("Supabase initialized")
	test_connection()
	
func test_connection(table_name: String = "scores"):
	# Create a query to select data from the specified table
	var query = SupabaseQuery.new()
	
	# Create a query to select all data from the table
	var task = supabase.database.query(
		query.from(table_name).select()
	)
	
	# Connect to the task completion signal
	task.completed.connect(_on_test_completed)
	
	# Connect to database signals for additional feedback
	supabase.database.selected.connect(_on_database_selected)
	supabase.database.error.connect(_on_database_error)
	
	print("Testing connection to Supabase table: " + table_name)
	return task

# Callback for when the test task completes
func _on_test_completed(task):
	print("Connection test task completed!")
	if task.data:
		print("Data received: ", task.data)
	if task.error:
		print("Error: ", task.error)

# Callback for the database selected signal
func _on_database_selected(data):
	print("Selected data: ", data)

# Callback for the database error signal
func _on_database_error(error):
	print("Database error: ", error)
