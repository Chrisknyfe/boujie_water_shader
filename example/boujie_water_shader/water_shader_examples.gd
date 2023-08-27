extends Node3D

## An example of various water shaders

## You can update your custom nodes' LOD settings from a WaterMaterialDesigner
func _on_deep_ocean_designer_update_lod(far_distance, middle_distance, unit_size):
	$Ocean/OceanFloor.scale = Vector3(far_distance * 2.0, 1.0, far_distance * 2.0)
	$Ocean/OceanFloor.drop_far = far_distance * 0.75
