@tool
extends VBoxContainer

const ProceduralMountainScript = preload("res://addons/parallax_generator/procedural_mountain.gd")
const ParallaxLayerResizerScript = preload("res://addons/parallax_generator/regenerating_parallax_resizer.gd")

# --- UI Callbacks ---

func _on_generate_button_pressed() -> void:
	var root = EditorInterface.get_edited_scene_root()
	if not root: return

	var bg = root.find_child("ProceduralParallax", true, false)
	if not bg:
		var undo_redo = EditorInterface.get_editor_undo_redo()
		undo_redo.create_action("Generate Tiling Parallax")
		bg = ParallaxBackground.new()
		bg.name = "ProceduralParallax"
		undo_redo.add_do_method(root, "add_child", bg)
		undo_redo.add_do_method(bg, "set_owner", root)
		undo_redo.add_undo_method(root, "remove_child", bg)
		undo_redo.commit_action()
		
		_regenerate_all_layers(bg, "Populate Parallax")
	else:
		_regenerate_all_layers(bg, "Regenerate Tiling Parallax")

func _on_mountain_layer_slider_value_changed(value: float) -> void:
	%MountainLayerLabel.text = "Mountain Layers: " + str(int(value))
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	var bg = root.find_child("ProceduralParallax", true, false)
	if not bg: return
	_update_mountain_layers(bg, int(value))

# --- State-Based Undo/Redo Engine ---

func _regenerate_all_layers(bg: ParallaxBackground, action_name: String):
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(action_name)
	var current_defs = _capture_definitions_from_children(bg.get_children())
	var new_defs = []
	new_defs.append({ "name": "Sun", "generator": "_gen_sun", "motion_scale": Vector2() })
	new_defs.append_array(_build_mountain_definitions(int(%MountainLayerSlider.value)))
	undo_redo.add_do_method(self, "_set_all_layers_from_defs", bg, new_defs)
	undo_redo.add_undo_method(self, "_set_all_layers_from_defs", bg, current_defs)
	undo_redo.commit_action()

func _update_mountain_layers(bg: ParallaxBackground, count: int):
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Change Mountain Layers")
	var current_mountain_nodes = []
	for child in bg.get_children():
		if child.name.begins_with("Mountain"):
			current_mountain_nodes.append(child)
	var current_mountain_defs = _capture_definitions_from_children(current_mountain_nodes)
	var new_mountain_defs = _build_mountain_definitions(count)
	undo_redo.add_do_method(self, "_set_mountain_layers_from_defs", bg, new_mountain_defs)
	undo_redo.add_undo_method(self, "_set_mountain_layers_from_defs", bg, current_mountain_defs)
	undo_redo.commit_action()

# --- Atomic State Setters (With Corrected Ownership) ---

func _set_all_layers_from_defs(parent: Node, definitions: Array):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	
	for d in definitions:
		var layer = _build_layer_node(d)
		parent.add_child(layer)
		layer.set_owner(root)
		for content_child in layer.get_children():
			content_child.set_owner(root)
		
		# --- THIS IS THE FIX ---
		# After the layer is in the tree, tell it to find its child.
		if layer.has_method("initialize_for_editor"):
			layer.initialize_for_editor()

func _set_mountain_layers_from_defs(parent: Node, definitions: Array):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	
	for i in range(parent.get_child_count() - 1, -1, -1):
		var child = parent.get_child(i)
		if child.name.begins_with("Mountain"):
			parent.remove_child(child)
			child.queue_free()
	
	for d in definitions:
		var layer = _build_layer_node(d)
		parent.add_child(layer)
		layer.set_owner(root)
		for content_child in layer.get_children():
			content_child.set_owner(root)
			
		# --- THIS IS THE FIX ---
		# After the layer is in the tree, tell it to find its child.
		if layer.has_method("initialize_for_editor"):
			layer.initialize_for_editor()

# --- Data Capture & Definition Builders (No changes needed below this line) ---
# ... (The rest of your script: _capture_definitions_from_children, _build_mountain_definitions, etc. remains the same)
func _capture_definitions_from_children(nodes: Array) -> Array:
	var definitions = []
	for layer in nodes:
		if not is_instance_valid(layer): continue
		var def = {"name": layer.name, "motion_scale": layer.motion_scale}
		if layer.motion_mirroring.x > 0: def["width"] = layer.motion_mirroring.x
		
		var content_node = null
		if layer.get_child_count() > 0:
			content_node = layer.get_child(0)

		if content_node and content_node.name == "ProceduralMountain":
			def["generator"] = "_gen_mountain"
			def["color"] = content_node.color
			def["amplitude"] = content_node.amplitude
			def["frequency"] = content_node.noise_frequency
			def["noise_zoom"] = content_node.noise_zoom
			def["y_offset"] = content_node.y_offset
			def["seed"] = content_node.seed
		elif layer.name == "Sun":
			def["generator"] = "_gen_sun"
		
		definitions.append(def)
	return definitions

func _build_mountain_definitions(count: int) -> Array:
	var definitions = []
	var base_def = { "motion_scale": Vector2(0.3, 1.0), "width": 1600, "color": Color(0.5, 0.5, 0.55), "amplitude": 90, "frequency": 2.0, "noise_zoom": 30, "y_offset": 0 }
	var final_def = { "motion_scale": Vector2(0.9, 1.0), "color": Color(0.2, 0.2, 0.25), "amplitude": 150, "frequency": 3.5, "noise_zoom": 60, "y_offset": 70 }
	for i in range(count):
		var t = 0.0 if count <= 1 else float(i) / (count - 1)
		definitions.append({
			"name": "Mountain" + str(i), "generator": "_gen_mountain", "width": base_def.width,
			"seed": randi(),
			"motion_scale": base_def.motion_scale.lerp(final_def.motion_scale, t),
			"color": base_def.color.lerp(final_def.color, t),
			"amplitude": lerp(base_def.amplitude, final_def.amplitude, t),
			"frequency": lerp(base_def.frequency, final_def.frequency, t),
			"noise_zoom": lerp(base_def.noise_zoom, final_def.noise_zoom, t),
			"y_offset": lerp(base_def.y_offset, final_def.y_offset, t),
		})
	return definitions

func _build_layer_node(def: Dictionary) -> ParallaxLayer:
	var layer: ParallaxLayer # Declare the variable type

	# Conditionally decide which class to instantiate based on the definition.
	# Mountain layers have a "width", the Sun layer does not.
	if def.has("width"):
		# This layer needs resizing, so instantiate our custom class.
		layer = ParallaxLayerResizerScript.new()
		layer.motion_mirroring.x = def.width
	else:
		# This is a simple layer (like the Sun), so use the base Godot class.
		layer = ParallaxLayer.new()

	# --- The rest of the setup is the same for both types ---
	
	layer.name = def.name
	layer.motion_scale = def.get("motion_scale", Vector2.ONE)

	# Generate the child node (the mountain or sun)
	var generator_func = def.get("generator")
	if generator_func and has_method(generator_func):
		var child_node = call(generator_func, def)
		if child_node:
			# Add the child to the layer
			layer.add_child(child_node)
	
	# NOTE: We do not call set_script(). We created the correct object type from the start.

	return layer

func _gen_sun(_def: Dictionary) -> Node:
	var gradient = Gradient.new()
	gradient.offsets = [0.0, 0.6, 1.0]
	gradient.colors = [Color(1,1,0,1), Color(1,0.9,0.2,1), Color(1,0.9,0.2,0)]
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.width = 256; grad_tex.height = 256
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5); grad_tex.fill_to = Vector2(0.5, 0.0)
	var sun_sprite = Sprite2D.new()
	sun_sprite.name = "SunSprite"
	sun_sprite.texture = grad_tex
	sun_sprite.position = Vector2(400, 100)
	return sun_sprite

func _gen_mountain(def: Dictionary) -> Node:
	var mountain = ProceduralMountainScript.new()
	mountain.name = "ProceduralMountain"
	mountain.color = def.get("color", Color.WHITE)
	mountain.seed = def.get("seed", randi())
	mountain.amplitude = def.get("amplitude", 100)
	mountain.noise_frequency = def.get("frequency", 2.0)
	mountain.noise_zoom = def.get("noise_zoom", 30)
	mountain.y_offset = def.get("y_offset", 0)
	mountain.generate(def.get("width", 1600))
	return mountain
