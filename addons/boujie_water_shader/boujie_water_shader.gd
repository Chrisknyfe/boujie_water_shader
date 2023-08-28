@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type(
		"CameraFollower3D",
		"Node3D",
		preload("res://addons/boujie_water_shader/types/camera_follower_3d.gd"),
		preload("res://addons/boujie_water_shader/icons/CameraFollower3D.svg")
	)
	add_custom_type(
		"Ocean",
		"Node3D",
		preload("res://addons/boujie_water_shader/types/ocean.gd"),
		preload("res://addons/boujie_water_shader/icons/Ocean.svg")
	)
	add_custom_type(
		"WaterMaterialDesigner",
		"Node",
		preload("res://addons/boujie_water_shader/types/water_material_designer.gd"),
		preload("res://addons/boujie_water_shader/icons/WaterMaterialDesigner.svg")
	)


func _exit_tree():
	remove_custom_type("CameraFollower3D")
	remove_custom_type("Ocean")
	remove_custom_type("WaterMaterialDesigner")
