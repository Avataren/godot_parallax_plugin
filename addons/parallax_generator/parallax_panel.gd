@tool
extends VBoxContainer

const ProceduralMountainScript = preload("res://addons/parallax_generator/procedural_mountain.gd")
const ParallaxLayerResizerScript = preload("res://addons/parallax_generator/regenerating_parallax_resizer.gd")

func _on_generate_button_pressed() -> void:
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return

	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Generate Tiling Parallax")

	# --- Find or Create Parallax Background ---
	var bg = root.find_child("ProceduralParallax", true, false)
	if not bg:
		# If it doesn't exist, create it.
		bg = ParallaxBackground.new()
		bg.name = "ProceduralParallax"
		undo_redo.add_do_method(root, "add_child", bg)
		undo_redo.add_undo_method(root, "remove_child", bg)
		undo_redo.add_do_method(bg, "set_owner", root)
		undo_redo.add_undo_method(bg, "set_owner", null)
	else:
		# If it exists, clear its existing children for a full regeneration
		_clear_all_layers(bg, undo_redo)

	# --- Generate Static Layers (Sun) ---
	var sun_def = {
		"name": "Sun", "generator": "_gen_sun",
		"motion_scale": Vector2(0.0, 0.0)
	}
	_create_layer(bg, sun_def, undo_redo, root)

	# --- Generate Mountain Layers based on Slider ---
	var num_mountain_layers = int(%MountainLayerSlider.value)
	_generate_mountain_layers(bg, num_mountain_layers, undo_redo, root)

	undo_redo.commit_action()

func _on_mountain_layer_slider_value_changed(value: float) -> void:	
	print ("Srtting mountain slider amount to " + str(value))
	%MountainLayerLabel.text = "Mountain Layers:" + str(value)
	
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return
	
	var bg = root.find_child("ProceduralParallax", true, false)
	if not bg:
		# If the parallax node doesn't exist, do nothing.
		# The user should click "Generate" first.
		return

	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Change Mountain Layers")

	# Clear only the mountain layers
	_clear_mountain_layers(bg, undo_redo)

	# Generate the new set of mountain layers
	_generate_mountain_layers(bg, int(value), undo_redo, root)
	
	undo_redo.commit_action()

func _generate_mountain_layers(bg: ParallaxBackground, count: int, undo_redo: EditorUndoRedoManager, root: Node) -> void:
	# Base definitions that will be interpolated for each layer
	var base_def = {
		"motion_scale": Vector2(0.3, 1.0), "width": 1600,
		"color": Color(0.5, 0.5, 0.55), "amplitude": 90, "frequency": 2.0,
		"noise_zoom": 30, "y_offset": 0
	}
	
	var final_def = {
		"motion_scale": Vector2(0.9, 1.0),
		"color": Color(0.2, 0.2, 0.25), "amplitude": 150, "frequency": 3.5,
		"noise_zoom": 60, "y_offset": 70
	}

	for i in range(count):
		# t is our interpolation factor, from 0 (farthest) to 1 (closest)
		var t = 0.0
		if count > 1:
			t = float(i) / (count - 1)

		var def = {
			"name": "Mountain" + str(i),
			"generator": "_gen_mountain",
			"width": base_def.width
		}
		
		# Interpolate properties to create distinct layers
		def.motion_scale = base_def.motion_scale.lerp(final_def.motion_scale, t)
		def.color = base_def.color.lerp(final_def.color, t)
		def.amplitude = lerp(base_def.amplitude, final_def.amplitude, t)
		def.frequency = lerp(base_def.frequency, final_def.frequency, t)
		def.noise_zoom = lerp(base_def.noise_zoom, final_def.noise_zoom, t)
		def.y_offset = lerp(base_def.y_offset, final_def.y_offset, t)

		_create_layer(bg, def, undo_redo, root)

func _create_layer(bg: ParallaxBackground, def: Dictionary, undo_redo: EditorUndoRedoManager, root: Node) -> void:
	var layer = ParallaxLayer.new()
	layer.name = def.name
	layer.motion_scale = def.motion_scale

	if def.has("width"):
		layer.motion_mirroring.x = def.width
		layer.set_script(ParallaxLayerResizerScript)

	undo_redo.add_do_method(bg, "add_child", layer)
	undo_redo.add_do_method(layer, "set_owner", root)
	undo_redo.add_undo_method(bg, "remove_child", layer)

	var generator_func = def.generator
	if has_method(generator_func):
		call(generator_func, layer, def, undo_redo, root)

func _clear_all_layers(bg: ParallaxBackground, undo_redo: EditorUndoRedoManager) -> void:
	# Important: Iterate backwards when removing children!
	for i in range(bg.get_child_count() - 1, -1, -1):
		var child = bg.get_child(i)
		undo_redo.add_do_method(bg, "remove_child", child)
		undo_redo.add_undo_method(bg, "add_child", child)
		# We don't need to manage owner here, as the nodes are not being deleted permanently

func _clear_mountain_layers(bg: ParallaxBackground, undo_redo: EditorUndoRedoManager) -> void:
	for i in range(bg.get_child_count() - 1, -1, -1):
		var child = bg.get_child(i)
		# Only remove layers that start with "Mountain"
		if child.name.begins_with("Mountain"):
			undo_redo.add_do_method(bg, "remove_child", child)
			undo_redo.add_undo_method(bg, "add_child", child)

func _gen_sun(layer: ParallaxLayer, def: Dictionary, undo_redo: EditorUndoRedoManager, root: Node) -> void:
	# This function remains unchanged.
	var gradient = Gradient.new()
	gradient.offsets = [0.0, 0.6, 1.0]
	gradient.colors = [Color(1,1,0,1), Color(1,0.9,0.2,1), Color(1,0.9,0.2,0)]
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.width = 256
	grad_tex.height = 256
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	var sun_sprite = Sprite2D.new()
	sun_sprite.texture = grad_tex
	sun_sprite.position = Vector2(400, 100)
	undo_redo.add_do_method(layer, "add_child", sun_sprite)
	undo_redo.add_undo_method(layer, "remove_child", sun_sprite)
	undo_redo.add_do_method(sun_sprite, "set_owner", root)
	undo_redo.add_undo_method(sun_sprite, "set_owner", null)

func _gen_mountain(layer: ParallaxLayer, def: Dictionary, undo_redo: EditorUndoRedoManager, root: Node) -> void:
	# This function remains unchanged.
	var mountain = ProceduralMountainScript.new()
	mountain.name = "ProceduralMountain" # Give it a consistent name
	mountain.color = def.get("color", Color.WHITE)
	mountain.seed = randi()
	mountain.amplitude = def.get("amplitude", 100)
	mountain.noise_frequency = def.get("frequency", 2.0)
	mountain.noise_zoom = def.get("noise_zoom", 30)
	mountain.y_offset = def.get("y_offset", 0)

	var initial_width = def.get("width", 1600)
	mountain.generate(initial_width)

	undo_redo.add_do_method(layer, "add_child", mountain)
	undo_redo.add_undo_method(layer, "remove_child", mountain)
	undo_redo.add_do_method(mountain, "set_owner", root)
	undo_redo.add_undo_method(mountain, "set_owner", null)



	
