# regenerating_parallax_resizer.gd
@tool
extends ParallaxLayer

var _mountain_node: Polygon2D
var _is_initialized: bool = false

# --- ENTRY POINT 1: For the Editor Plugin ---
# Your generator will call this function manually.
func initialize_for_editor():
	# We just need to find the node. No signals needed in the editor.
	_find_child_node()

# --- ENTRY POINT 2: For Runtime ---
# Godot calls this automatically when the game starts.
func _ready():
	# At runtime, we must defer to ensure the scene tree is fully ready.
	call_deferred("setup_runtime_connections")

# --- SHARED LOGIC ---

# Finds the child node and stores a reference to it.
func _find_child_node():
	if _is_initialized: return

	# Use find_child() for a clear, direct search.
	_mountain_node = find_child("ProceduralMountain", false) # `false` means don't check grandchildren.

	if is_instance_valid(_mountain_node):
		_is_initialized = true
	else:
		printerr("Resizer Error: Could not find a child node named 'ProceduralMountain'.")

# Sets up the runtime signals for resizing.
func setup_runtime_connections():
	_find_child_node() # Make sure we have the reference.
	
	if not _is_initialized: return

	if Engine.is_editor_hint(): return # Don't connect signals in the editor.

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed() # Call once at startup.

func _on_viewport_size_changed():
	if not is_instance_valid(_mountain_node): return

	var viewport_width = get_viewport().get_visible_rect().size.x
	var base_width = motion_mirroring.x
	var new_width = max(base_width, viewport_width)

	_mountain_node.generate(new_width)
	motion_mirroring.x = new_width
