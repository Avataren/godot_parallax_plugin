# procedural_mountain.gd
@tool
extends Polygon2D

# --- Generation Parameters ---
@export var seed: int = 0
@export var base_height: float = 300.0
@export var amplitude: float = 130.0
@export var y_offset: float = 50.0
@export var ground_y: float = 600.0 
# --- Noise Settings ---
@export var noise_frequency: float = 3.0
@export var noise_zoom: float = 50.0
@export_group("Noise Fractal Settings")
@export var fractal_octaves: int = 6
@export var fractal_lacunarity: float = 2.0
@export var fractal_gain: float = 0.5

var _noise: FastNoiseLite

# --- Detail ---
@export var step_size: int = 2 # The distance between points on the X-axis

# Called when the node is added to the scene.
func _ready():
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM

# The main generation function. It can be called anytime to redraw the polygon.
func generate(width: float, ground_y: float):
	if not _noise:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_noise.fractal_type = FastNoiseLite.FRACTAL_FBM

	# Configure noise with the latest properties from the inspector
	_noise.seed = seed
	_noise.fractal_octaves = fractal_octaves
	_noise.fractal_lacunarity = fractal_lacunarity
	_noise.fractal_gain = fractal_gain

	var points = PackedVector2Array() # Use PackedVector2Array for performance
	
	# Generate the top edge of the mountain range
	if step_size <= 0: step_size = 1 # Prevent division by zero
	
	for x in range(0, int(width) + step_size, step_size):
		var angle = (float(x) / width) * TAU

		var noise_x = cos(angle) * noise_zoom
		var noise_y = sin(angle) * noise_zoom
		
		var y_noise = _noise.get_noise_2d(noise_x * noise_frequency, noise_y * noise_frequency)
		var y = base_height + y_noise * amplitude + y_offset
		points.append(Vector2(x, y))
			
	# Add bottom points to create a solid shape that extends well below the baseline
	#points.append(Vector2(width, base_height + amplitude * 2))
	#points.append(Vector2(0, base_height + amplitude * 2))
	points.append(Vector2(width, ground_y))
	points.append(Vector2(0, ground_y))

	# Update the actual polygon with the newly generated points
	self.polygon = points
