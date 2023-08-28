@tool
@icon("res://addons/boujie_water_shader/icons/WaterMaterialDesigner.svg")
class_name WaterMaterialDesigner
extends Node

## A water material designer tool which allows easy editing of shader
## parameters using GerstnerWaves. Synchronizes level-of-detail settings between
## a water shader, the active camera, an ocean, and a camera follower.

## Emitted when level-of-detail settings are updated.
## This signal may fire in the editor. Make sure any connected scripts are also
## tool scripts.
signal updated_lod(far_distance: float, middle_distance: float, unit_size: float)

## Water shader material designed to work with this Designer node
@export var material: ShaderMaterial
## Update material, ocean, and camera follower when this Designer is ready.
@export var update_on_ready := false
## Update material, ocean, and camera follower when the active camera's far changes.
@export var update_when_camera_far_changes := false

@export_category("Optional Nodes to Update")
## Optionally specify an ocean node, this Designer will update its farplane to
## match the active camera's far
@export_node_path("Ocean") var ocean_path := NodePath("")
## Optionally specify a CameraFollower3D, this Designer will update its
## snap unit to the ocean's max unit size.
@export_node_path("CameraFollower3D") var camera_follower_path := NodePath("")

@export_category("Distance Fade")
## Fade transparency at this distance from the camera
@export var distance_fade_far := 1000
## Fade transparency with increased distance from the camera, smoothed by this
## amount.
@export_range(0.0, 1.0) var distance_fade_softness := 0.2
## Fade-out water shader features such as wave height and foam at this distance
## from the camera.
@export var wave_fade_far := 500
## Fade-out water shader features such as wave height and foam with increased
## distance from the camera, smoothed by this amount.
@export_range(0.0, 1.0) var wave_fade_softness := 0.2

@export_category("Waves")
## Waves that raise and lower the water height relative to the mesh surface
@export var height_waves: Array[GerstnerWave] = []
## Waves that make foam appear and disappear on the water's surface
@export var foam_waves: Array[GerstnerWave] = []
## Waves that introduce waviness in the water's texture
@export var uv_waves: Array[GerstnerWave] = []

@export_category("Editor Tools")
## Update all parameters controlled by this Designer node.
@export var editor_update_all_params := false

var _previous_far := 0.0


func _ready():
	if not Engine.is_editor_hint() and update_on_ready:
		# because I can connect to any node in the scene tree from here,
		# I want to be safe and wait for the whole tree to be ready.
		get_tree().root.ready.connect(self.update)


func _process(_delta):
	if editor_update_all_params:
		editor_update_all_params = false
		update()
	if update_when_camera_far_changes and not Engine.is_editor_hint():
		var camera = get_viewport().get_camera_3d()
		if camera and camera.far != _previous_far:
			_previous_far = camera.far
			update()


## Update all level of detail settings to the water shader, the active camera,
## and optionally to an ocean and a camera follower.
func update():
	_update_lod()
	_update_distance_fade()
	_update_wave_params()


func _update_lod():
	var camera = get_viewport().get_camera_3d()
	var ocean = get_node_or_null(ocean_path)
	var follower = get_node_or_null(camera_follower_path)
	if camera:
		var middle = camera.far / 2.0  # TODO: paramaterize heuristic
		var unit_size = 1.0
		if ocean:
			middle = ocean.total_width / 2.0
			ocean.far_edge = camera.far
			ocean.build_farplane()
			unit_size = ocean.max_unit_size
			if follower:
				follower.snap_unit = ocean.max_unit_size
		distance_fade_far = camera.far
		wave_fade_far = middle
		updated_lod.emit(camera.far, middle, unit_size)


func _update_distance_fade():
	var max = distance_fade_far
	var min = max * (1.0 - distance_fade_softness)
	material.set_shader_parameter("distance_fade_max", max)
	material.set_shader_parameter("distance_fade_min", min)

	max = wave_fade_far
	min = max * (1.0 - wave_fade_softness)
	material.set_shader_parameter("foam_fade_max", max)
	material.set_shader_parameter("foam_fade_min", min)
	material.set_shader_parameter("shore_fade_max", max)
	material.set_shader_parameter("shore_fade_min", min)
	material.set_shader_parameter("vertex_wave_fade_max", max)
	material.set_shader_parameter("vertex_wave_fade_min", min)
	material.set_shader_parameter("depth_fog_fade_max", max)
	material.set_shader_parameter("depth_fog_fade_min", min)


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
