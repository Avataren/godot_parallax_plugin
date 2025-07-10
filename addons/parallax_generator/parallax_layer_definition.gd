@tool
class_name ParallaxLayerDefinition
extends Resource

# --- Identity & Type ---
@export var layer_name: String = "Layer"
@export var generator_type: StringName = &"_gen_mountain" # Using StringName is good practice for function names

# --- ParallaxLayer Properties ---
@export_group("Parallax")
@export var motion_scale: Vector2 = Vector2(0.5, 1.0)
@export var is_resizing: bool = true # An explicit flag is clearer than checking for a "width" property
@export var base_width: int = 1600

# --- Generator-Specific Properties ---
@export_group("Mountain Generation")
@export var color: Color = Color(0.5, 0.5, 0.5)
@export var seed: int = 0
@export var amplitude: float = 100.0
@export var noise_frequency: float = 2.0
@export var noise_zoom: float = 30.0
@export var y_offset: float = 0.0
@export var ground_y: float = 600.0
@export var base_height: float = 300.0 
