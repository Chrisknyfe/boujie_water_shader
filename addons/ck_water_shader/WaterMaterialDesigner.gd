@tool
extends Node

## Ocean shader material designed to work with this OceanMeshGen
@export var material: ShaderMaterial

@export_category("Distance Fade")
@export var distance_fade_far: float = 1000
@export_range(0.0, 1.0) var distance_fade_softness: float = 0.2
@export var wave_fade_far: float = 500
@export_range(0.0, 1.0) var wave_fade_softness: float = 0.2

@export_category("Waves")
@export var height_waves: Array[GerstnerWave] = []
@export var foam_waves: Array[GerstnerWave] = []
@export var uv_waves: Array[GerstnerWave] = []

@export_category("Editor Tools")
@export var editor_update: bool = false

func _ready():
	update()

func _process(delta):
	if editor_update:
		editor_update = false
		update()
	
func _update_distance_fade():
	var max = distance_fade_far
	var min = max * (1.0 - distance_fade_softness)
	material.set_shader_parameter("distance_fade_max", max)
	material.set_shader_parameter("distance_fade_min", min)
	
	max = wave_fade_far
	min = max * (1.0 - wave_fade_softness)
	material.set_shader_parameter("foam_fade_max", max)
	material.set_shader_parameter("foam_fade_min", min)
	material.set_shader_parameter("shore_fade_max",max)
	material.set_shader_parameter("shore_fade_min", min)
	material.set_shader_parameter("vertex_wave_fade_max", max)
	material.set_shader_parameter("vertex_wave_fade_min", min)

func _update_wave_params():
	# height waves
	_update_wave_group_params("Wave", height_waves)
	_update_wave_group_params("UVWave", uv_waves)
	_update_wave_group_params("FoamWave", foam_waves)
	
func _update_wave_group_params(prefix: String, waves: Array):
	var num_waves = min(8, len(waves))
	material.set_shader_parameter(prefix + "Count", num_waves)
	var steepnesses = []
	var amplitudes = []
	var directions = []
	var frequencies = []
	var speeds = []
	var phases = []
	for i in range(num_waves):
		var res = waves[i]
		steepnesses.append(res.steepness)
		amplitudes.append(res.amplitude)
		directions.append(res.direction_degrees)
		frequencies.append(res.frequency)
		speeds.append(res.speed)
		phases.append(res.phase_degrees)
	material.set_shader_parameter(prefix + "Steepnesses", PackedFloat32Array(steepnesses))
	material.set_shader_parameter(prefix + "Amplitudes", PackedFloat32Array(amplitudes))
	material.set_shader_parameter(prefix + "DirectionsDegrees", PackedFloat32Array(directions))
	material.set_shader_parameter(prefix + "Frequencies", PackedFloat32Array(frequencies))
	material.set_shader_parameter(prefix + "Speeds", PackedFloat32Array(speeds))
	material.set_shader_parameter(prefix + "Phases", PackedFloat32Array(phases))
	
func update():
	_update_distance_fade()
	_update_wave_params()
