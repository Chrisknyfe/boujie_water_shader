@tool
extends Node3D

@export var material: Material:
	set(value):
		material = value
		_apply_material()
		
@export_category("Geometry")
@export_range(4, 200) var outermost_resolution: int = 10
@export_range(1, 10) var levels_of_detail: int = 1
@export var unit_size: float = 1.0

var _region_width: float:
	get:
		return outermost_resolution * unit_size * 2 ** (levels_of_detail-1)

@export_category("Editor Tools")
@export var editor_rebuild: bool = false
@export var editor_clear: bool = false

func _process(delta):
	if Engine.is_editor_hint():
		if editor_rebuild:
			editor_rebuild = false
			build_meshes()
		if editor_clear:
			editor_clear = false
			_clear_generated_meshes()

class PlaneMeshGenerator extends RefCounted:
	var resolution: int
	var unit_size: float
	var seam_up: bool
	var seam_down: bool
	var seam_left: bool
	var seam_right: bool
	var _st: SurfaceTool
	func _init(resolution:int, unit_size:float = 1.0, 
		seam_up:bool = false, seam_down:bool=false, seam_left:bool = false, seam_right:bool = false):
		self.resolution = resolution
		self.unit_size = unit_size
		self.seam_up = seam_up
		self.seam_down = seam_down
		self.seam_left = seam_left
		self.seam_right = seam_right
		self._st = SurfaceTool.new()
		self._st.begin(Mesh.PRIMITIVE_TRIANGLES)
				
	func generate():
		var f_resolution = float(resolution)
		var midpoint = Vector3(f_resolution/2, 0, f_resolution/2)
		for z in range(resolution):
			for x in range(resolution):
				# +x is right, +z is down
				var coords = [Vector2i(x, z), Vector2i(x+1, z), Vector2i(x+1, z+1), Vector2i(x, z+1)]
				# seam edges by welding any odd vertices
				var on_seamable_edge = false
				var mark = [false, false, false, false]
				if seam_left and x == 0:
					on_seamable_edge = true
					mark[0] = true
					mark[3] = true
				if seam_right and x == resolution-1:
					on_seamable_edge = true
					mark[1] = true
					mark[2] = true
				if seam_up and z == 0:
					on_seamable_edge = true
					mark[0] = true
					mark[1] = true
				if seam_down and z == resolution-1:
					on_seamable_edge = true
					mark[2] = true
					mark[3] = true
					
				if on_seamable_edge:
					for i in range(len(coords)):
						if mark[i]:
							if coords[i].y % 2 == 1:
								coords[i].y -= 1
							if coords[i].x % 2 == 1:
								coords[i].x -= 1
				
				# uv should iterate from 0,0 to 1,1
				var uvs = []
				var verts = []
				for coord in coords:
					uvs.append(Vector2(coord) / f_resolution)
					verts.append((Vector3(coord.x, 0, coord.y) - midpoint) * self.unit_size)
				
				# add quad
				self._st.add_triangle_fan(PackedVector3Array(verts), PackedVector2Array(uvs))
				
	func commit():
		self._st.generate_normals()
		self._st.index()
		return self._st.commit()

func _apply_material():
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("_gen"):
			child.set_surface_override_material(0, material)
			
func _clear_generated_meshes():
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("_gen"):
			remove_child(child)
	

func build_meshes():
	_clear_generated_meshes()
	
	@warning_ignore("integer_division")
	var lower_limit = -levels_of_detail + 1
	var upper_limit = levels_of_detail
	for z in range(lower_limit, upper_limit):
		for x in range(lower_limit, upper_limit):
			var pos = Vector3(x,0,z) * _region_width
			var shell = max(abs(x), abs(z))
			var onion = levels_of_detail - shell - 1
			print("Generate mesh at: ", pos, " shell ", shell, " onion ", onion)
			var this_unit_size = unit_size * 2 ** shell
			var this_resolution = outermost_resolution * (2 ** (onion))
			var seam_up = -z >= shell
			var seam_down = z >= shell
			var seam_left = -x >= shell
			var seam_right = x >= shell
			var plane = PlaneMeshGenerator.new(this_resolution, this_unit_size,
				seam_up, seam_down, seam_left, seam_right)
			plane.generate()
			var mesh = plane.commit()
	
			var mi = MeshInstance3D.new()
			mi.name = "_gen_nearplane_%d_%d" % [x, z]
			mi.mesh = mesh
			add_child(mi)
			mi.position = pos
			
