extends Node3D

@export_node_path("Node3D") var victim_path
@export var enable: bool = true

const X_AXIS = 1
const Y_AXIS = 2
const Z_AXIS = 4
@export_flags("x", "y", "z") var follow_axes = 5

@export var snap: bool = false
@export var snap_unit: float = 10.0

func do_snap(x: float):
	if snap:
		return round(x / snap_unit) * snap_unit
	return x

func _process(delta):
	if not Engine.is_editor_hint() and enable:
		var camera = get_viewport().get_camera_3d()
		var v: Node3D = get_node(victim_path)
		if follow_axes & X_AXIS:
			v.global_position.x = do_snap(camera.global_position.x)
		if follow_axes & Y_AXIS:
			v.global_position.y = do_snap(camera.global_position.y)
		if follow_axes & Z_AXIS:
			v.global_position.z = do_snap(camera.global_position.z)

