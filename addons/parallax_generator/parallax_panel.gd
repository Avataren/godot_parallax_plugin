@tool
extends VBoxContainer

const ProceduralMountainScript = preload("res://addons/parallax_generator/procedural_mountain.gd")
const ParallaxLayerResizerScript = preload("res://addons/parallax_generator/regenerating_parallax_resizer.gd")
# preload("res://addons/parallax_generator/parallax_layer_resizer.gd")

func _ready():
	pass

func _on_generate_button_pressed() -> void:
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return
	var undo_redo = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Generate Tiling Parallax")

	# 1) Add the ParallaxBackground
	var bg = ParallaxBackground.new()
	bg.name = "ProceduralParallax"
	undo_redo.add_do_method(root, "add_child", bg)
	undo_redo.add_undo_method(root, "remove_child", bg)
	undo_redo.add_do_method(bg, "set_owner", root)
	
	undo_redo.add_undo_method(bg, "set_owner", null)

	# 2) Layer definitions with a new 'width' property for tiling.
	var layer_defs = [
		{
			"name": "Sun", "generator": "_gen_sun",
			"motion_scale": Vector2(0.0, 0.0)
		},
		{
			"name": "MountainFar", "generator": "_gen_mountain",
			"motion_scale": Vector2(0.3, 1.0), "width": 1600,
			"color": Color(0.5, 0.5, 0.55), "amplitude": 90, "frequency": 2.0, "noise_zoom": 30, "y_offset": 0
		},
		{
			"name": "MountainMid", "generator": "_gen_mountain",
			"motion_scale": Vector2(0.5, 1.0), "width": 1600,
			"color": Color(0.4, 0.4, 0.45), "amplitude": 110, "frequency": 2.5, "noise_zoom": 40, "y_offset": 20
		},
		{
			"name": "MountainClose", "generator": "_gen_mountain",
			"motion_scale": Vector2(0.7, 1.0), "width": 1600,
			"color": Color(0.3, 0.3, 0.35), "amplitude": 130, "frequency": 3.0, "noise_zoom": 50, "y_offset": 50
		}
	]

	# Create each layer and configure it
	for def in layer_defs:
		var layer = ParallaxLayer.new()
		layer.name = def.name
		layer.motion_scale = def.motion_scale

		# NEW: Attach the resizer script to layers that have a width
		if def.has("width"):
			layer.motion_mirroring.x = def.width
			layer.set_script(ParallaxLayerResizerScript)

		# Schedule layer creation...
		undo_redo.add_do_method(bg, "add_child", layer)
		
		# --- FIX: Add this line to set the layer's owner ---
		undo_redo.add_do_method(layer, "set_owner", root)
		# ----------------------------------------------------
		
		undo_redo.add_undo_method(bg, "remove_child", layer)

		# Call its generator
		var generator_func = def.generator
		if has_method(generator_func):
			call(generator_func, layer, def, undo_redo, root)

	undo_redo.commit_action()

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
	# 1. Create an instance of our new ProceduralMountain node
	var mountain = ProceduralMountainScript.new()

	# 2. Configure its properties from the layer definition dictionary
	mountain.color = def.get("color", Color.WHITE)
	mountain.seed = randi() # Give each mountain range a unique seed
	mountain.amplitude = def.get("amplitude", 100)
	mountain.noise_frequency = def.get("frequency", 2.0)
	mountain.noise_zoom = def.get("noise_zoom", 30)
	mountain.y_offset = def.get("y_offset", 0)
	# You can also set other exported properties like fractal_octaves here if needed

	# 3. Perform the initial generation using the width from the definition
	var initial_width = def.get("width", 1600)
	mountain.generate(initial_width)

	# 4. Schedule its addition to the scene tree
	undo_redo.add_do_method(layer, "add_child", mountain)
	undo_redo.add_undo_method(layer, "remove_child", mountain)
	undo_redo.add_do_method(mountain, "set_owner", root)
	undo_redo.add_undo_method(mountain, "set_owner", null)
