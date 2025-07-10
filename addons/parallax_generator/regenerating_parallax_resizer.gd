@tool
extends ParallaxLayer

var _mountain_node: Polygon2D

# Godot calls this when the node enters the SceneTree (in editor and runtime).
func _enter_tree():
	# We must defer finding the child, as it may not be ready at the exact same time.
	call_deferred("_find_and_setup_child")

	# At runtime, connect to viewport resizing.
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_on_viewport_size_changed)

func _find_and_setup_child():
	# Find a child that has the "generate" method. This is more robust than a fixed name.
	for child in get_children():
		if child.has_method("generate"):
			_mountain_node = child
			break
	
	if not is_instance_valid(_mountain_node):
		printerr("Resizer Error: Could not find a child with a 'generate' method.")
		return
	
	# Perform initial resize/generation when first added.
	_on_viewport_size_changed()

func _on_viewport_size_changed():
	if not is_instance_valid(_mountain_node): return

	var viewport_width = get_viewport().get_visible_rect().size.x
	# Use motion_mirroring.x as the base, but fall back to viewport if it's 0.
	var base_width = motion_mirroring.x if motion_mirroring.x > 0 else viewport_width
	var new_width = max(base_width, viewport_width)

	# We can't assume the node is a Polygon2D, only that it can generate.
	if _mountain_node.has_method("generate"):
		_mountain_node.generate(new_width, _mountain_node.ground_y)
	print ("_mountain_node.ground_y:" + str(_mountain_node.ground_y))
	motion_mirroring.x = new_width
