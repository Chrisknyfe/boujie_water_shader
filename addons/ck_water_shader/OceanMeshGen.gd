@tool
extends Node3D

## Ocean shader material designed to work with this OceanMeshGen
@export var material: ShaderMaterial
## Number of rows & columns in the mesh grid
@export_range(2, 300) var resolution: int = 100:
	set(value):
		resolution = value
		build_mesh()
		_update_width()
## Width of the mesh (distance)
@export 	var width: float = 200.0:
	set(value):
		width = value
		_update_width()
## How clustered the mesh is closer to the center (camera)
@export_range(0.0, 1.0) var density_factor: float = 0.09:
	set(value):
		density_factor = value
		build_mesh()
		_update_width()
## How quickly the mesh density increases closer to the center (camera)
@export_range(0, 10) var density_exponent: float = 2.0:
	set(value):
		density_exponent = value
		build_mesh()
		_update_width()
## Update distance fade in the shader when width of the ocean changes
@export		var adapt_distance_fade_to_width: bool = false:
	set(value):
		adapt_distance_fade_to_width = value
		_update_distance_fade()
## Distance fade softness to set with adaptive distance fade.
@export_range(0.0, 1.0) var adaptive_distance_fade_softness: float = 0.1:
	set(value):
		adaptive_distance_fade_softness = value
		_update_distance_fade()
## Update width of ocean when camera far changes
@export var adapt_width_to_camera: bool = false
## Set to true to forcibly rebuild the mesh
@export var force_rebuild_mesh: bool = false

@export var height_waves: Array[GerstnerWave] = []
@export var foam_waves: Array[GerstnerWave] = []
@export var uv_waves: Array[GerstnerWave] = []

func quadratic_increase(x: float):
	var y = density_factor * abs(pow(x, density_exponent)) + (1.0 - density_factor)*abs(x)
	if x < 0:
		y = -y
	return y
	
func quadratic_increase_by_shell(c: Vector3):
	var shell = max(abs(c.x), abs(c.y), abs(c.z))
	var q_factor = 0
	if shell != 0:
		q_factor = quadratic_increase(shell)/shell
	return Vector3(c.x * q_factor, c.y * q_factor, c.z * q_factor)
	
	
	

# Due to the "tool" keyword at the top of this file
# this function already executes in the editor
func _ready():
	build_mesh()
	_update_width()
	_update_wave_params()

func build_mesh():
	var surfTool = SurfaceTool.new()

	surfTool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var f_resolution = float(resolution)
	@warning_ignore("integer_division")
	var range_limit = resolution/2
	for z in range(-range_limit, range_limit):
		for x in range(-range_limit, range_limit):
			# +x is right, +z is down
			
			# Transform3D vertex coords to get more sparse farther from the player					
			var coord_ul = Vector2(x, z)
			var coord_ur = Vector2(x+1, z)
			var coord_lr = Vector2(x+1, z+1)
			var coord_ll = Vector2(x, z+1)

			# uv should iterate from 0,0 to 1,1
			var uv_ul = (coord_ul / f_resolution + Vector2(0.5, 0.5))
			var vert_ul = Vector3(coord_ul.x, 0, coord_ul.y)

			var uv_ur = (coord_ur / f_resolution + Vector2(0.5, 0.5))
			var vert_ur = Vector3(coord_ur.x, 0, coord_ur.y)

			var uv_lr = (coord_lr / f_resolution + Vector2(0.5, 0.5))
			var vert_lr = Vector3(coord_lr.x, 0, coord_lr.y)

			var uv_ll = (coord_ll / f_resolution + Vector2(0.5, 0.5))
			var vert_ll = Vector3(coord_ll.x, 0, coord_ll.y)
			
			vert_ul = quadratic_increase_by_shell(vert_ul) / f_resolution
			vert_ur = quadratic_increase_by_shell(vert_ur) / f_resolution
			vert_lr = quadratic_increase_by_shell(vert_lr) / f_resolution
			vert_ll = quadratic_increase_by_shell(vert_ll) / f_resolution

#			print("meshp %d,%d: " % [x,z], vert_ul, uv_ul)

			# ul +-----+ ur
			#    |\    |
			#    | \   |
			#    |  \  |
			#    |   \ |
			#    |    \|
			# ll +-----+ lr

			surfTool.set_smooth_group(0)
			surfTool.set_uv(uv_ul)
			surfTool.add_vertex(vert_ul)
			surfTool.set_smooth_group(0)
			surfTool.set_uv(uv_ur)
			surfTool.add_vertex(vert_ur)
			surfTool.set_smooth_group(0)
			surfTool.set_uv(uv_lr)
			surfTool.add_vertex(vert_lr)

			surfTool.set_smooth_group(0)
			surfTool.set_uv(uv_lr)
			surfTool.add_vertex(vert_lr)
			surfTool.set_smooth_group(0)
			surfTool.set_uv(uv_ll)
			surfTool.add_vertex(vert_ll)
			surfTool.set_smooth_group(0)
			surfTool.set_uv(uv_ul)
			surfTool.add_vertex(vert_ul)

	surfTool.generate_normals()
	surfTool.index()
	var mesh = surfTool.commit()
	
	var old_mi = get_node_or_null("GeneratedMeshInstance")
	if old_mi:
		remove_child(old_mi)
	
	var meshinstance = MeshInstance3D.new()
	meshinstance.name = "GeneratedMeshInstance"
	meshinstance.mesh = mesh
	meshinstance.set_surface_override_material(0, material)
	add_child(meshinstance)
	
	
func _update_width():
	var f_resolution = float(resolution)
	var width_quadratic_growth = 2.0 * quadratic_increase(f_resolution / 2) / f_resolution
	var true_scale_factor = width / width_quadratic_growth
	var mi = get_node_or_null("GeneratedMeshInstance")
	if mi:
		mi.scale.x = true_scale_factor
		mi.scale.z = true_scale_factor	
	_update_distance_fade()
	
func _update_distance_fade():
	if adapt_distance_fade_to_width:
		material.set_shader_parameter("distance_fade_max", 0.5 + width / 2)
		material.set_shader_parameter("distance_fade_min", width * (1.0 - adaptive_distance_fade_softness) / 2 )
		material.set_shader_parameter("foam_fade_max", 0.5 + width / 5)
		material.set_shader_parameter("foam_fade_min", width / 10 )


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
	for i in range(num_waves):
		var res = waves[i]
		steepnesses.append(res.steepness)
		amplitudes.append(res.amplitude)
		directions.append(res.direction_degrees)
		frequencies.append(res.frequency)
		speeds.append(res.speed)
	material.set_shader_parameter(prefix + "Steepnesses", PackedFloat32Array(steepnesses))
	material.set_shader_parameter(prefix + "Amplitudes", PackedFloat32Array(amplitudes))
	material.set_shader_parameter(prefix + "DirectionsDegrees", PackedFloat32Array(directions))
	material.set_shader_parameter(prefix + "Frequencies", PackedFloat32Array(frequencies))
	material.set_shader_parameter(prefix + "Speeds", PackedFloat32Array(speeds))
	


func _process(_delta):
	if force_rebuild_mesh:
		print("force_rebuild_mesh")
		force_rebuild_mesh = false
		build_mesh()
		_update_width()
		_update_wave_params()
	if not Engine.is_editor_hint() and adapt_width_to_camera:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var new_width = camera.far * 2
			if width != new_width:
				width = new_width
