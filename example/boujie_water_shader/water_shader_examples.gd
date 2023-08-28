@tool
extends Node3D

## An example of various water shaders

@onready var ocean_floor = $DeepOcean/OceanFloor

## You can update your custom nodes' LOD settings from a WaterMaterialDesigner
func _on_water_material_designer_update_lod(far_distance, middle_distance, unit_size):
	ocean_floor.scale = Vector3(far_distance * 2.0, 1.0, far_distance * 2.0)
	ocean_floor.drop_far = far_distance * 0.75
