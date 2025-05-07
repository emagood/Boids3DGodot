extends CanvasLayer

@export var main: Node
@onready var fps_label: Label = %FPSLabel

@onready var boid_data_texture_rect: TextureRect = %BoidDataTexture
@onready var boid_quat_texture_rect: TextureRect = %BoidQuatTexture
@onready var debug_label: Label = %DebugLabel
@onready var slider_menu: PanelContainer = %SliderMenu


func _ready() -> void:
	var slider_list = [
		["friend_radius",     0, 5],
		["avoid_radius",      0, 5],
		["min_vel",           0, 100],
		["max_vel",           0, 100],
		["steer_factor",      0, 5],
		["alignment_factor",  0, 5],
		["cohesion_factor",   0, 5],
		["separation_factor", 0, 5],
		["flow_factor",       0, 5],
		["mouse_factor",      0, 5],
		["avoidance_factor",  0, 5],
		["time_scale",        0, 4],
	]
	
	slider_menu.add_sliders(slider_list)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	General.viewing_changed.connect(func(state): visible = !state)


func _process(delta: float) -> void:
	var fps_text = "Boids: " + str(main.NUM_BOIDS) + " / FPS: " + str(Engine.get_frames_per_second())
	fps_label.text = fps_text
	get_window().title = fps_text
	
	if main.get("boid_data_texture") != null:
		boid_data_texture_rect.texture = main.boid_data_texture
	if main.get("boid_quat_texture") != null:
		boid_quat_texture_rect.texture = main.boid_quat_texture
