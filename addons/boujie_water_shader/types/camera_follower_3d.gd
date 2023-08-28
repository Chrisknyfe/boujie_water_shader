@icon("res://addons/boujie_water_shader/icons/CameraFollower3D.svg")
class_name CameraFollower3D
extends Node3D

const X_AXIS = 1
const Y_AXIS = 2
const Z_AXIS = 4

## CameraFollower3D pushes the currently active camera's position onto a target path.
## It can independently sync the X, Y and Z coordinate of the camera and target.
## It can snap the target's position to multiples of a given unit size.

## Target which will be repositioned by this node
@export_node_path("Node3D") var target_path := NodePath("")
## Enable or disable this node
@export var enable := true

## Select which components of the target's position will be changed.
@export_flags("x", "y", "z") var follow_axes := 5

## Enable or disable snapping the target's position
@export var snap := false
## Snapping unit size. The target's position will be set to a multiple of this unit size.
@export var snap_unit := 10.0


func _process(_delta):
	if not Engine.is_editor_hint() and enable:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var t: Node3D = get_node(target_path)
			if follow_axes & X_AXIS:
				t.global_position.x = do_snap(camera.global_position.x)
			if follow_axes & Y_AXIS:
				t.global_position.y = do_snap(camera.global_position.y)
			if follow_axes & Z_AXIS:
				t.global_position.z = do_snap(camera.global_position.z)


func do_snap(x: float):
	if snap:
		return round(x / snap_unit) * snap_unit
	return x
