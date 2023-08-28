@tool
@icon("res://addons/boujie_water_shader/icons/Ocean.svg")
class_name Ocean
extends Node3D

## An ocean plane, with configurable levels of detail.

# Based on the famous tutorial by StayAtHomeDev: https://www.youtube.com/watch?v=WfRb50J7hD8

@export var material: Material:
	set(value):
		material = value
		_apply_material()

@export_category("Geometry")
## Resolution of the outermost LOD. Multiplies by a power of 2 for inner LODs.
@export_range(2, 200) var outermost_resolution := 10
## How many levels of detail to generate.
## Creates rings of meshes surrounding the center of this object.
@export_range(1, 20) var levels_of_detail := 1
## Size of quads in the innermost LOD.
@export var unit_size := 1.0
## The farthest visible distance. Set this from camera.far.
@export var far_edge := 1000

@export_category("Editor Tools")
## Rebuild all meshes
@export var editor_rebuild := false
## Clear all meshes
@export var editor_clear := false
## Rebuild the farplane
@export var editor_farplane := false

var region_width: float:
	get:
		return outermost_resolution * unit_size * 2 ** (levels_of_detail - 1)
var total_width: float:
	get:
		return region_width * ((2 * levels_of_detail) - 1)
var max_unit_size: float:
	get:
		return unit_size * 2 ** (levels_of_detail - 1)


func _ready():
	build_meshes.call_deferred()


func _process(_delta):
	if editor_rebuild:
		editor_rebuild = false
		build_meshes()
	if editor_clear:
		editor_clear = false
		_clear_generated_meshes()
	if editor_farplane:
		editor_farplane = false
		build_farplane()
		_apply_material()


func build_farplane():
	_clear_generated_meshes("_gen_farplane")

	var near = total_width / 2
	var middle = (near + far_edge) / 2
	middle = min(near * 3, middle)
	if far_edge < near:
		push_error("Cannot generate farplane, Far Edge is closer than inner planes!")
		return

	# midplane prevents texture jitter errors being noticeable.
	var midplane = FarPlaneMeshGenerator.new(near, region_width, middle)
	midplane.generate()
	var mesh = midplane.commit()
	_add_mesh_as_node(mesh, "_gen_farplane_mid")

	var farplane = FarPlaneMeshGenerator.new(middle, region_width, far_edge)
	farplane.generate()
	mesh = farplane.commit()
	_add_mesh_as_node(mesh, "_gen_farplane_far")

	_apply_material("_gen_farplane")


func build_meshes():
	_clear_generated_meshes()

	var lower_limit = -levels_of_detail + 1
	var upper_limit = levels_of_detail
	for z in range(lower_limit, upper_limit):
		for x in range(lower_limit, upper_limit):
			var shell = max(abs(x), abs(z))
			var onion = levels_of_detail - shell - 1
			var pos = Vector3(x, 0, z) * region_width
			#print("Generate mesh at: ", pos, " shell ", shell, " onion ", onion)
			var this_unit_size = unit_size * 2 ** shell
			var this_resolution = outermost_resolution * (2 ** (onion))
			var seam_up = -z >= shell
			var seam_down = z >= shell
			var seam_left = -x >= shell
			var seam_right = x >= shell
			var plane = PlaneMeshGenerator.new(
				this_resolution, this_unit_size, seam_up, seam_down, seam_left, seam_right
			)
			plane.generate()
			var mesh = plane.commit()
			_add_mesh_as_node(mesh, "_gen_nearplane_%d_%d" % [x, z], pos)
	build_farplane()
	_apply_material()


func _apply_material(filter: String = "_gen"):
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with(filter):
			child.set_surface_override_material(0, material)


func _clear_generated_meshes(filter: String = "_gen"):
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with(filter):
			remove_child(child)
			child.queue_free()


func _add_mesh_as_node(mesh: Mesh, new_name: String, pos: Vector3 = Vector3.ZERO):
	if has_node(new_name):
		remove_child(get_node(new_name))
	var mi = MeshInstance3D.new()
	mi.name = new_name
	mi.mesh = mesh
	mi.position = pos
	mi.set_surface_override_material(0, material)
	add_child(mi)


class PlaneMeshGenerator:
	extends RefCounted
	var resolution: int
	var unit_size: float
	var seam_up: bool
	var seam_down: bool
	var seam_left: bool
	var seam_right: bool
	var _st: SurfaceTool

	func _init(
		resolution: int,
		unit_size: float = 1.0,
		seam_up: bool = false,
		seam_down: bool = false,
		seam_left: bool = false,
		seam_right: bool = false
	):
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
		var midpoint = Vector3(f_resolution / 2, 0, f_resolution / 2)
		for z in range(resolution):
			for x in range(resolution):
				# +x is right, +z is down
				# coords in units of quad index from (0,0) to (resolution-1, resolution-1)
				var coords = [
					Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x + 1, z + 1), Vector2i(x, z + 1)
				]
				# seam edges by welding any odd vertices
				var on_seamable_edge = false
				var mark = [false, false, false, false]
				if seam_left and x == 0:
					on_seamable_edge = true
					mark[0] = true
					mark[3] = true
				if seam_right and x == resolution - 1:
					on_seamable_edge = true
					mark[1] = true
					mark[2] = true
				if seam_up and z == 0:
					on_seamable_edge = true
					mark[0] = true
					mark[1] = true
				if seam_down and z == resolution - 1:
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
					uvs.append(Vector2(coord) / f_resolution)  # TODO: validate. might need a shift.
					verts.append((Vector3(coord.x, 0, coord.y) - midpoint) * self.unit_size)

				# add quad
				self._st.add_triangle_fan(PackedVector3Array(verts), PackedVector2Array(uvs))

	func commit():
		self._st.generate_normals()
		self._st.index()
		return self._st.commit()


class FarPlaneMeshGenerator:
	extends RefCounted
	# Don't get sent to the farplane!
	var near: float
	var uv_scale: float
	var far: float
	var _st: SurfaceTool

	func _init(near, uv_scale, far: float = 1000):
		self.near = near
		self.uv_scale = uv_scale
		self.far = far
		self._st = SurfaceTool.new()
		self._st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func generate():
		# +x is right, +z is down
		var r = self.near
		var f = self.far
		# coords in units of meters. These translate directly to vertices.
		var inners = [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]
		var outers = [Vector2(-f, -f), Vector2(f, -f), Vector2(f, f), Vector2(-f, f)]
		self._add_quad([outers[0], outers[1], inners[1], inners[0]])
		self._add_quad([outers[1], outers[2], inners[2], inners[1]])
		self._add_quad([outers[2], outers[3], inners[3], inners[2]])
		self._add_quad([outers[3], outers[0], inners[0], inners[3]])

	func commit():
		self._st.generate_normals()
		self._st.index()
		return self._st.commit()

	func _add_quad(coords):
		# coords in units of meters
		var uvs = []
		var verts = []
		for coord in coords:
			uvs.append(Vector2(coord) / self.uv_scale - Vector2(0.5, 0.5))  # TODO: validate
			verts.append(Vector3(coord.x, 0, coord.y))
		self._st.add_triangle_fan(PackedVector3Array(verts), PackedVector2Array(uvs))
