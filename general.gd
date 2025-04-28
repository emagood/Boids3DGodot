extends Node

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

var is_viewing : bool = true
signal viewing_changed

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event.is_action_pressed("DEBUG"): ## DEBUG
		is_viewing = !is_viewing
		viewing_changed.emit(is_viewing)
		if is_viewing:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			Engine.time_scale = 1.0
		else:
			Engine.time_scale = 1.0
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
