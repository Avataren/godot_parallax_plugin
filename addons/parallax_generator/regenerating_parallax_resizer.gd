# regenerating_parallax_resizer.gd
@tool
extends ParallaxLayer

# This will hold a reference to our mountain node.
var _mountain_node: Node 

func _ready():
	# Defer setup to ensure child nodes are available.
	call_deferred("setup_resizer")

func setup_resizer():
	# Find our procedural mountain child node by checking if it has our 'generate' method.
	for child in get_children():
		if child.has_method("generate"):
			_mountain_node = child
			break
	
	if not _mountain_node:
		print("Resizer Error: No child node with a 'generate' method found.")
		set_process(false)
		return

	# We only need this logic to run in the game, not the editor.
	if Engine.is_editor_hint():
		return

	# Connect to the viewport's "size_changed" signal.
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Call once at startup to ensure the size is correct from the beginning.
	_on_viewport_size_changed()


func _on_viewport_size_changed():
	if not is_instance_valid(_mountain_node):
		return

	var viewport_width = get_viewport().get_visible_rect().size.x
	
	# This 'base_width' was set by your generator plugin. We use it as a minimum.
	var base_width = motion_mirroring.x 
	
	# The new width is the larger of the two: the original width or the current viewport width.
	var new_width = max(base_width, viewport_width)

	# 1. CRITICAL: Tell the mountain to regenerate itself to the new width.
	_mountain_node.generate(new_width)
	
	# 2. CRITICAL: Update the layer's mirroring property to match the new polygon width.
	# This ensures the infinite scroll effect remains seamless.
	motion_mirroring.x = new_width
