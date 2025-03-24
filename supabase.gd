extends Node

var supabase

func _ready():
	# Initialize Supabase connection
	supabase = load("res://addons/supabase/Supabase/supabase.gd").new()
	supabase.load_config()

	
	# Add as a child to keep it in the scene tree
	add_child(supabase)
	print("Supabase initialized")
