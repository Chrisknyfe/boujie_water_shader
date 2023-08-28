@tool
extends Ocean

## Emitted when level-of-detail settings are updated.
## This signal may fire in the editor. Make sure any connected scripts are also tool scripts.
signal update_lod(far_distance: float, middle_distance: float, unit_size: float)


func _on_water_material_designer_update_lod(far_distance, middle_distance, unit_size):
	update_lod.emit(far_distance, middle_distance, unit_size)
