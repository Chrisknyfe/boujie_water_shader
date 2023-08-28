@tool
extends Node3D

## An example of various water shaders

@onready var ocean_floor := $DeepOcean/OceanFloor
@onready var vis_group := $VisibilityRangeLodGroup


## You can update your custom nodes' LOD settings from a WaterMaterialDesigner
func _on_water_material_designer_updated_lod(far_distance, middle_distance, _unit_size):
	ocean_floor.scale = Vector3(far_distance * 2.0, 1.0, far_distance * 2.0)
	ocean_floor.visibility_range_end = middle_distance
	ocean_floor.drop_far = far_distance * 0.75
	vis_group.visibility_range_end = (far_distance + middle_distance) / 2.0
	vis_group.visibility_range_end_margin = 200.0
	vis_group.update()
