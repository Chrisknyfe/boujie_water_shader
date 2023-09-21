extends Control


func _input(event):
	if event.is_action_pressed("ui_focus_next"):
		visible = !visible
