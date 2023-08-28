extends Node3D

## Set visibility range parameters to all children

@export var visibility_range_end := 500.0
@export var visibility_range_end_margin := 100


func _ready():
	update()


func update():
	_update_children(self)


func _update_node(node: Node):
	node.set("visibility_range_end", visibility_range_end)
	node.set("visibility_range_end_margin", visibility_range_end_margin)
	node.set(
		"visibility_range_fade_mode",
		GeometryInstance3D.VisibilityRangeFadeMode.VISIBILITY_RANGE_FADE_SELF
	)


func _update_children(parent: Node):
	for child in parent.get_children():
		_update_node(child)
		if child.get_child_count() > 0:
			_update_children(child)
