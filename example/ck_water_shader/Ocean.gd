@tool
extends Node3D

@export var update_when_camera_far_changes: bool = false
var _previous_far: float = 0.0

@export_category("Editor Tools")
@export var editor_update_all: bool = false

func _ready():
	update()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if editor_update_all:
		editor_update_all = false
		update()
	if update_when_camera_far_changes and not Engine.is_editor_hint():
		var camera = get_viewport().get_camera_3d()
		if camera and camera.far != _previous_far:
			_previous_far = camera.far
			update()

func update():
	var camera = get_viewport().get_camera_3d()
	if camera:
		$WaterMaterialDesigner.distance_fade_far = camera.far
		$LodPlaneMeshGen.far_edge = camera.far
		$LodPlaneMeshGen.build_farplane()
	$WaterMaterialDesigner.wave_fade_far = $LodPlaneMeshGen.total_width / 2.0
	$WaterMaterialDesigner.update()
	$CameraFollower3D.snap_unit = $LodPlaneMeshGen.max_unit_size
