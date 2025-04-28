extends CharacterBody3D

var mouse_sensitivity := 0.002   # Adjust for faster/slower rotation responsiveness
var move_speed := 20.0           # Units per second

@onready var pitch := rotation.x
@onready var yaw := rotation.y

@onready var camera_3d: Camera3D = $Camera3D


func _unhandled_input(event):
	if event is InputEventMouseMotion and main_3d.is_viewing:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -PI/2, PI/2)
		
		var quat_pitch = Quaternion(Vector3(1, 0, 0), pitch)
		var quat_yaw = Quaternion(Vector3(0, 1, 0), yaw)
		
		var final_quat = quat_yaw * quat_pitch
		
		rotation = final_quat.get_euler()

@onready var main_3d: Node3D = $".."


func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		direction -= global_transform.basis.z
	if Input.is_action_pressed("move_back"):
		direction += global_transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= global_transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += global_transform.basis.x
	if Input.is_action_pressed("move_up"):
		direction += global_transform.basis.y
	if Input.is_action_pressed("move_down"):
		direction -= global_transform.basis.y
	
	
	if direction != Vector3.ZERO:
		direction = direction.normalized()
	
	velocity = direction * move_speed
	move_and_slide()
