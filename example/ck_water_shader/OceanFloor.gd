@tool
extends MeshInstance3D

## A "distance fade" for the ocean floor that prevents the material from becoming a transparent material.

@export var drop_far: float = 2000:
	set(value):
		drop_far = value
		_update_drop_params()


func _update_drop_params():
	var material = get_surface_override_material(0)
	material.set_shader_parameter("drop_far", drop_far)

func _ready():
	_update_drop_params()
