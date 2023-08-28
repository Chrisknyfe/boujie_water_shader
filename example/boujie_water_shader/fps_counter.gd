extends Label


func _process(_delta):
	text = "FPS: " + str(Performance.get_monitor(Performance.TIME_FPS))
