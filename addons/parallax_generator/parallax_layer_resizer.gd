# parallax_layer_resizer.gd
@tool
extends ParallaxLayer

var polygon: Polygon2D
var original_width: float

func _ready():
	# In the _ready function, we find our Polygon2D child node.
	for child in get_children():
		if child is Polygon2D:
			polygon = child
			break
	
	if not polygon:
		# If for some reason there's no polygon, we disable the script.
		print("ParallaxLayerResizer: No Polygon2D child found.")
		set_process(false)
		return

	# We store the original width, which your generator sets as the motion_mirroring value.
	original_width = motion_mirroring.x
	
	# We don't need this script to run in the editor, only in the game.
	if Engine.is_editor_hint():
		return

	# Connect to the viewport's "size_changed" signal to know when the window resizes.
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# We call the function once at the start to ensure the initial size is correct.
	_on_viewport_size_changed()


func _on_viewport_size_changed():
	# This function is the core of the solution.
	if not is_instance_valid(polygon) or original_width == 0:
		return

	var viewport_width = get_viewport().get_visible_rect().size.x
	
	var required_scale_x = 1.0
	# If the original polygon is narrower than the viewport, we calculate the scale factor.
	if original_width < viewport_width:
		required_scale_x = viewport_width / original_width
	
	# We apply the calculated horizontal scale to our polygon.
	# This will stretch it to fill the new viewport width.
	polygon.scale.x = required_scale_x
	
	# This is the crucial step: we must also scale the mirroring distance.
	# This ensures the seamless infinite scroll works correctly with the newly scaled polygon.
	motion_mirroring.x = original_width * required_scale_x
