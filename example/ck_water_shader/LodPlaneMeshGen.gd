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
	var ul_seam: bool
	var ur_seam: bool
	var ll_seam: bool
	var lr_seam: bool
	var _st: SurfaceTool
	func _init(resolution:int, unit_size:float = 1.0, 
		ul_seam:bool = false, ur_seam:bool=false, ll_seam:bool = false, lr_seam:bool = false):
		self.resolution = resolution
		self.unit_size = unit_size
		self.ul_seam = ul_seam
		self.ur_seam = ur_seam
		self.ll_seam = ll_seam
		self.lr_seam = lr_seam
		self._st = SurfaceTool.new()
		self._st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
	func generate():
		var f_resolution = float(resolution)
		var midpoint = Vector3(f_resolution/2, 0, f_resolution/2)
		for z in range(resolution):
			for x in range(resolution):
				# +x is right, +z is down
				var coord_ul = Vector2(x, z)
				var coord_ur = Vector2(x+1, z)
				var coord_lr = Vector2(x+1, z+1)
				var coord_ll = Vector2(x, z+1)
				
				# uv should iterate from 0,0 to 1,1
				var uv_ul = (coord_ul / f_resolution)
				var uv_ur = (coord_ur / f_resolution)
				var uv_lr = (coord_lr / f_resolution)
				var uv_ll = (coord_ll / f_resolution)
				var vert_ul = (Vector3(coord_ul.x, 0, coord_ul.y) - midpoint) * self.unit_size
				var vert_ur = (Vector3(coord_ur.x, 0, coord_ur.y) - midpoint) * self.unit_size
				var vert_lr = (Vector3(coord_lr.x, 0, coord_lr.y) - midpoint) * self.unit_size
				var vert_ll = (Vector3(coord_ll.x, 0, coord_ll.y) - midpoint) * self.unit_size
				
				# add quad
				self._st.add_triangle_fan(PackedVector3Array([vert_ul, vert_ur, vert_lr, vert_ll]),
					PackedVector2Array([uv_ul, uv_ur, uv_lr, uv_ll]))
				
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
	
	var plane = PlaneMeshGenerator.new(outermost_resolution, unit_size)
	plane.generate()
	var mesh = plane.commit()
	
	var meshinstance = MeshInstance3D.new()
	meshinstance.name = "_gen_nearplane"
	meshinstance.mesh = mesh
	add_child(meshinstance)
