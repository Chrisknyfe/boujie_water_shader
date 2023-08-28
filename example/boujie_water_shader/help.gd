extends Label


func _ready():
	var strbuf := "Controls\n--------\n"
	strbuf += "WASD movement controls. E unbinds the mouse.\n"
	strbuf += "F11 exits fullscreen. F5 to quit.\n\n"

	var actions: Array[StringName] = InputMap.get_actions()
	actions.sort()
	var mouse_regex = RegEx.new()
	mouse_regex.compile("button_index=(?<button>\\w+)")
	for _action_name in actions:
		var action := String(_action_name)
		if not action.begins_with("ui_"):
			strbuf += "%s: " % action
			var action_list := PackedStringArray()
			for bind in InputMap.action_get_events(action):
				var can_shorten = false
				var shortened := ""
				if bind is InputEventMouseButton:
					var bindstr = bind.as_text()
					var result = mouse_regex.search(bindstr)
					if result:
						shortened = "Mouse " + result.get_string("button")
						can_shorten = true

				if can_shorten:
					action_list.append(shortened)
				else:
					action_list.append(bind.as_text())
			strbuf += ", ".join(action_list)
			strbuf += "\n"
	text = strbuf
