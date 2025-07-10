@tool
extends VBoxContainer

const ProceduralMountainScript = preload("res://addons/parallax_generator/procedural_mountain.gd")
const ParallaxLayerResizerScript = preload("res://addons/parallax_generator/regenerating_parallax_resizer.gd")
const ParallaxLayerDefinition = preload("res://addons/parallax_generator/parallax_layer_definition.gd")
const ParallaxStyle = preload("res://addons/parallax_generator/parallax_style.gd")

var active_style: ParallaxStyle
var style_picker: EditorResourcePicker
@onready var style_picker_container: VBoxContainer = %StylePickerContainer

func _ready() -> void:
	# Create the UI elements via code
	var label = Label.new()
	label.text = "Active Style: "
	style_picker_container.add_child(label)
	
	style_picker = EditorResourcePicker.new()
	
	# CORRECT: The property is named 'base_type'.
	style_picker.base_type = "ParallaxStyle"
	
	style_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_picker_container.add_child(style_picker)

	# Connect to the signal so we know when the user picks a resource
	style_picker.resource_changed.connect(_on_style_selected)
	
func _on_style_selected(style: ParallaxStyle) -> void:
	self.active_style = style

func set_style_picker_resource(resource: Resource) -> void:
	# Wait until our dynamic picker is ready before trying to set its value
	await ready 
	if style_picker:
		style_picker.set_edited_resource(resource)
		# Manually call the handler to update the internal state
		_on_style_selected(resource)
	
# --- UI Callbacks ---

func _on_generate_button_pressed() -> void:
	if not active_style:
		printerr("No active style assigned to the parallax generator!")
		return
			
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
	
	# Build Sun definition (still a dictionary for simplicity, or make a resource for it too!)
	new_defs.append({"name": "Sun", "generator": "_gen_sun", "motion_scale": Vector2.ZERO}) 
	new_defs.append_array(_build_mountain_definitions(int(%MountainLayerSlider.value)))
	
	# The "do" method sets the new state
	undo_redo.add_do_method(self, "_set_all_layers_from_defs", bg, new_defs)
	# The "undo" method restores the captured state. We must DUPLICATE resources for this to work.
	undo_redo.add_undo_method(self, "_set_all_layers_from_defs", bg, _duplicate_definitions(current_defs))
	
	undo_redo.commit_action()

func _update_mountain_layers(bg: ParallaxBackground, count: int):
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Change Mountain Layers")

	var current_mountain_nodes = bg.get_children().filter(func(c): return c.name.begins_with("Mountain"))
	var current_mountain_defs = _capture_definitions_from_children(current_mountain_nodes)
	var new_mountain_defs = _build_mountain_definitions(count)
	
	# The "do" method applies the new mountain definitions
	undo_redo.add_do_method(self, "_set_mountain_layers_from_defs", bg, new_mountain_defs)
	# The "undo" method restores the old ones. DUPLICATE is essential!
	undo_redo.add_undo_method(self, "_set_mountain_layers_from_defs", bg, _duplicate_definitions(current_mountain_defs))
	
	undo_redo.commit_action()

# --- Atomic State Setters (With Corrected Ownership) ---

func _set_all_layers_from_defs(parent: Node, definitions: Array):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	
	# Clear all existing children
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	
	# Rebuild from definitions
	for d in definitions:
		var layer = _build_layer_node(d) # This function now handles both Resources and Dictionaries
		parent.add_child(layer)
		layer.set_owner(root)
		for content_child in layer.get_children():
			content_child.set_owner(root)

func _set_mountain_layers_from_defs(parent: Node, definitions: Array):
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	
	# Clear only mountain layers
	for i in range(parent.get_child_count() - 1, -1, -1):
		var child = parent.get_child(i)
		if child.name.begins_with("Mountain"):
			parent.remove_child(child)
			child.queue_free()
	
	# Add new mountain layers
	for d in definitions:
		var layer = _build_layer_node(d)
		parent.add_child(layer)
		layer.set_owner(root)
		for content_child in layer.get_children():
			content_child.set_owner(root)

# --- Data Capture & Definition Builders (No changes needed below this line) ---
func _capture_definitions_from_children(nodes: Array) -> Array:
	var definitions = []
	for layer in nodes:
		if not is_instance_valid(layer): continue
		
		if layer.name == "Sun":
			definitions.append({
				"name": "Sun", 
				"generator": "_gen_sun",
				"motion_scale": layer.motion_scale # <-- Add this line
			})
			continue			

		# Handle Mountain layers (now captured as a Resource)
		var content_node = layer.get_child(0) if layer.get_child_count() > 0 else null
		if content_node and content_node.is_class("ProceduralMountainScript"):
			var def = ParallaxLayerDefinition.new()
			def.layer_name = layer.name
			def.motion_scale = layer.motion_scale
			def.is_resizing = true
			def.base_width = layer.motion_mirroring.x
			def.base_height = content_node.base_height
			def.ground_y = content_node.ground_y			
			def.color = content_node.color
			def.amplitude = content_node.amplitude
			def.noise_frequency = content_node.noise_frequency
			def.noise_zoom = content_node.noise_zoom
			def.y_offset = content_node.y_offset
			def.seed = content_node.seed
			definitions.append(def)
			
	return definitions

func _build_mountain_definitions(count: int) -> Array:
	var definitions = []

	if not active_style or not active_style.base_definition or not active_style.final_definition:
		printerr("Parallax Generator Error: The active style is missing its Base or Final definition.")
		return definitions # Return an empty array to prevent a crash

	var base_def = active_style.base_definition
	var final_def = active_style.final_definition
	
	var ground_level: float
	
	# --- THIS IS THE HYBRID FIX ---
	# Check if the user has set a manual ground level in the final definition.
	if final_def.ground_y > 0:
		# The user has set a specific value, so we will use it.
		ground_level = final_def.ground_y
	else:
		# Use the base_height from the style definitions, not a default value.
		var highest_base_height = max(base_def.base_height, final_def.base_height)
		var max_y_offset_base = base_def.y_offset + base_def.amplitude
		var max_y_offset_final = final_def.y_offset + final_def.amplitude
		var highest_peak_offset = max(max_y_offset_base, max_y_offset_final)
		ground_level = highest_base_height + highest_peak_offset + 50.0
	
	for i in range(count):
		var t = 0.0 if count <= 1 else float(i) / (count - 1)
		
		var def = ParallaxLayerDefinition.new()
		def.layer_name = "Mountain" + str(i)
		def.generator_type = &"_gen_mountain"
		def.is_resizing = true
		def.base_height = lerp(base_def.base_height, final_def.base_height, t)
		def.base_width = base_def.base_width # Assuming width is constant for now
		def.seed = base_def.seed + i
		def.ground_y = ground_level
		def.motion_scale = base_def.motion_scale.lerp(final_def.motion_scale, t)
		def.color = base_def.color.lerp(final_def.color, t)
		def.amplitude = lerp(base_def.amplitude, final_def.amplitude, t)
		def.noise_frequency = lerp(base_def.noise_frequency, final_def.noise_frequency, t)
		def.noise_zoom = lerp(base_def.noise_zoom, final_def.noise_zoom, t)
		def.y_offset = lerp(base_def.y_offset, final_def.y_offset, t)
		
		definitions.append(def)
		
	return definitions

func _build_layer_node(definition) -> ParallaxLayer:
	if definition is ParallaxLayerDefinition:
		return _build_layer_from_resource(definition)
	elif definition is Dictionary:
		return _build_layer_from_dict(definition)
	return null

func _build_layer_from_resource(def: ParallaxLayerDefinition) -> ParallaxLayer:
	var layer: ParallaxLayer
	if def.is_resizing:
		layer = ParallaxLayerResizerScript.new()
		layer.motion_mirroring.x = def.base_width
	else:
		layer = ParallaxLayer.new()

	layer.name = def.layer_name
	layer.motion_scale = def.motion_scale

	if has_method(def.generator_type):
		var child_node = call(def.generator_type, def) # Pass the whole resource
		if child_node:
			layer.add_child(child_node)
	return layer

func _build_layer_from_dict(def: Dictionary) -> ParallaxLayer:
	# This handles the simple "Sun" case
	var layer = ParallaxLayer.new()
	layer.name = def.name
	layer.motion_scale = def.get("motion_scale", Vector2.ONE)	
	var generator_func = def.get("generator")
	if generator_func and has_method(generator_func):
		var child_node = call(generator_func, def)
		if child_node:
			layer.add_child(child_node)
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

func _gen_mountain(def: ParallaxLayerDefinition) -> Node:
	var mountain = ProceduralMountainScript.new()
	mountain.name = "ProceduralMountain"
	mountain.color = def.color
	mountain.seed = def.seed
	mountain.amplitude = def.amplitude
	mountain.noise_frequency = def.noise_frequency
	mountain.noise_zoom = def.noise_zoom
	mountain.y_offset = def.y_offset
	mountain.base_height = def.base_height
	mountain.ground_y = def.ground_y
	print ("def.ground_y:"+str(def.ground_y))
	mountain.generate(def.base_width, def.ground_y)
	return mountain
	
func _duplicate_definitions(definitions: Array) -> Array:
	var new_array = []
	for d in definitions:
		if d is Resource:
			new_array.append(d.duplicate())
		else:
			new_array.append(d.duplicate(true)) # Duplicate dictionary
	return new_array	
