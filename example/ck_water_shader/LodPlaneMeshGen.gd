@tool
extends Node3D

@export_range(4, 100) var outermost_resolution: int = 10
@export_range(2, 6) var levels_of_detail: int = 2
@export_range(0.1, 5) var unit_size: float = 1.0
@export var material: Material:
	set(value):
		material = value
		_apply_material()

@export_category("Editor Tools")
@export var editor_rebuild: bool = false
@export var editor_clear: bool = false

func _process(delta):
	if Engine.is_editor_hint():
		if editor_rebuild:
			editor_rebuild = false
			build_mesh()
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
	

func build_mesh():
	_clear_generated_meshes()
	
	var plane = PlaneMeshGenerator.new(outermost_resolution, unit_size,
		true, true, true, true)
	plane.generate()
	var mesh = plane.commit()
	
	var meshinstance = MeshInstance3D.new()
	meshinstance.name = "_gen_nearplane"
	meshinstance.mesh = mesh
	add_child(meshinstance)
