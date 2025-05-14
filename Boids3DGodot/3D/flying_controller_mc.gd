extends CharacterBody3D

var mouse_sensitivity := 0.002   # Adjust for faster/slower rotation responsiveness
var move_speed := 20.0           # Units per second

@onready var pitch := rotation.x
@onready var yaw := rotation.y

@onready var camera_3d: Camera3D = $Camera3D

func _unhandled_input(event):
	if event is InputEventMouseMotion and General.is_viewing:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -PI/2, PI/2)
		
		var quat_pitch = Quaternion(Vector3(1, 0, 0), pitch)
		var quat_yaw = Quaternion(Vector3(0, 1, 0), yaw)
		
		var final_quat = quat_yaw * quat_pitch
		
		rotation = final_quat.get_euler()

@onready var main_3d: Node3D = $".."

func _physics_process(_delta: float) -> void:
	var fwd = -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right = global_transform.basis.x
	right.y = 0
	right = right.normalized()

	var dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir += fwd
	if Input.is_action_pressed("move_back"):
		dir -= fwd
	if Input.is_action_pressed("move_left"):
		dir -= right
	if Input.is_action_pressed("move_right"):
		dir += right
	
	var vert_speed := 0.0
	if Input.is_action_pressed("move_up") and General.is_viewing:
		vert_speed += move_speed
	if Input.is_action_pressed("move_down") and General.is_viewing:
		vert_speed -= move_speed
	
	var horizontal = dir.normalized() * move_speed
	
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = vert_speed
	
	move_and_slide()
