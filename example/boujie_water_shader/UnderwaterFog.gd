extends FogVolume

@export var visible_height_offset := 0.0


func _process(_delta):
	var camera = get_viewport().get_camera_3d()
	if camera:
		visible = camera.position.y < (position.y + visible_height_offset)
