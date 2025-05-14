extends Node

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

var is_viewing : bool = true
signal viewing_changed

const scene_3d: PackedScene = preload("res://3D/main3D.tscn")
const scene_2d: PackedScene = preload("res://2D/main.tscn")

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
	
	if event.is_action_pressed("sim0"):
		_switch_to(scene_2d)
	elif event.is_action_pressed("sim1") or event.is_action_pressed("sim2") or event.is_action_pressed("sim3"):
		_switch_to(scene_3d)

var current_scene: Node = null

func _switch_to(scene: PackedScene) -> void:
	if current_scene:
		get_tree().root.remove_child(current_scene)
		current_scene.queue_free()
		var main3d = get_tree().root.get_node_or_null("Main3d")
		if main3d: main3d.queue_free()
	
	current_scene = scene.instantiate()
	get_tree().root.add_child(current_scene)
