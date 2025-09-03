extends MeshInstance3D

@export var water_material_designer: WaterMaterialDesigner
@export var deep_ocean: Ocean

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var pos = global_position.x
	var h = water_material_designer.height(global_position.x, global_position.z, deep_ocean.shader_time)
	global_position.y = h
